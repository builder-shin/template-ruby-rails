<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Controllers (app/controllers/)

## Purpose
API 요청을 처리하는 컨트롤러 레이어. JSON:API 스펙을 준수하며, CrudActions concern을 통해 표준 CRUD 로직을 자동화합니다. 외부 인증 서비스와 연동하여 쿠키 기반 세션 인증을 처리합니다.

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | 컨트롤러 패턴, CrudActions 사용법, 인증/인가 가이드 |
| `application_controller.rb` | Rails 기본 컨트롤러 베이스 |
| `api_controller.rb` | API 베이스 컨트롤러 (인증, JSON:API 설정, 에러 핸들링) |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `concerns/` | 컨트롤러 공통 로직 (CrudActions - CRUD 자동화 concern) |
| `api/v1/` | API v1 엔드포인트 (42개 리소스 컨트롤러) |

## For AI Agents

### Working In This Directory
컨트롤러 작업 시:

1. **ApiController 상속**: 모든 API 컨트롤러는 `ApiController`를 상속
2. **CrudActions 활용**: `include CrudActions`로 표준 CRUD 자동화
3. **인증 체크**: `before_action :user_check!`로 인증 필수 설정
4. **회원 유형 인가**: `personal_check!`, `enterprise_check!`로 권한 제어
5. **라이프사이클 훅**: `create_after_init`, `update_after_save` 등으로 커스텀 로직 추가
6. **관계 로딩**: `?include=` 파라미터로 요청된 관계는 CrudActions가 자동 eager loading

### Common Patterns

#### Guard Clause 패턴 (필수)
- **if/elsif/else 패턴 금지** — guard clause (early return/raise) 사용
- 조건 불일치 시 `raise` 또는 `return`으로 먼저 빠져나가고, 정상 흐름을 아래에 배치
- 반복문 내에서는 `next` 사용
- `case/when/else`는 허용 (switch-case 패턴)

#### 기본 CRUD 컨트롤러
```ruby
module Api
  module V1
    class ResourcesController < ApiController
      # CrudActions는 ApiController에서 이미 include됨

      before_action :user_check!

      def filter_attributes
        [:name, :status, :created_at]
      end

      def model_params_options
        { only: [:title, :content] }
      end
    end
  end
end
```

#### 현재 사용자 ID 자동 설정
```ruby
class ProfilesController < ApiController
  before_action :user_check!
  before_action :personal_check!, only: [:create, :update, :destroy]

  private

  def create_after_init
    @model.user_id = user_info.id
  end
end
```

#### 소유권 검증 (Guard Clause 패턴)
```ruby
class PostsController < ApiController
  before_action :user_check!
  before_action :verify_ownership!, only: [:update, :destroy]

  private

  def verify_ownership!
    return if @model.user_id == user_info.id

    raise JsonApiError.new("Forbidden", "자신의 게시글만 수정할 수 있습니다.", 403)
  end
end
```

#### N+1 방지 (includes 오버라이드)
```ruby
class JobPostsController < ApiController
  include CrudActions

  # index 액션에서 관계 자동 로드
  def index_scope
    klass.includes(:job_category, :job_post_languages)
  end
end
```

#### 커스텀 액션 추가
```ruby
class ProfilesController < ApiController
  include CrudActions

  # 커스텀 액션
  def complete
    @model = klass.find(params[:id])
    @model.update(status: :completed)
    render jsonapi: @model
  end
end
```

#### 에러 핸들링
```ruby
# JsonApiError 사용
raise JsonApiError.new("BadRequest", "이메일이 유효하지 않습니다", 400)
raise JsonApiError.new("Forbidden", "권한이 없습니다", 403)
raise NotFound.new("리소스를 찾을 수 없습니다", "404")
```

#### 필터링 및 정렬
```ruby
# 클라이언트 요청
# GET /api/v1/profiles?filter[job_seeking_status]=actively_seeking&sort=-created_at

def filter_attributes
  [:job_seeking_status, :name, :created_at]
end
```

#### 페이지네이션
```ruby
# 클라이언트 요청
# GET /api/v1/profiles?page[number]=2&page[size]=20

# CrudActions가 자동 처리 (Kaminari 사용)
# 응답 meta에 페이지네이션 정보 포함
```

#### 인증 메서드 사용
```ruby
# ApiController에서 제공
user_info          # 현재 사용자 (AuthUser 객체 또는 nil)
user_check!        # 인증 체크 (미인증 시 401)
personal_check!    # 개인회원 체크 (비개인회원 시 403)
enterprise_check!  # 기업회원 체크 (비기업회원 시 403)
```

#### CrudActions 라이프사이클 훅
| 액션 | 훅 | 실행 시점 |
|------|-----|----------|
| show | `show_after_init` | @model 세팅 후 |
| new | `new_after_init` | 빈 모델 생성 후 |
| create | `create_after_init` | @model 생성 후, 저장 전 |
| create | `create_after_save(success)` | 저장 후 |
| update | `update_after_init` | @model 세팅 후 |
| update | `update_after_assign` | 파라미터 할당 후, 저장 전 |
| update | `update_after_save(success)` | 저장 후 |
| destroy | `destroy_after_init` | @model 세팅 후 |
| destroy | `destroy_after_save(success)` | 삭제 후 |

#### before_action 순서 주의
```ruby
# ✅ Good: _set_model 이후 verify_ownership!
before_action :user_check!
before_action :personal_check!, only: [:create, :update, :destroy]
before_action :verify_ownership!, only: [:update, :destroy]
# CrudActions의 _set_model이 show, update, destroy에 자동 적용됨

# ❌ Bad: @model이 없는 상태에서 접근
before_action :verify_ownership!  # _set_model보다 먼저 실행되면 에러
```

## Dependencies

### Internal
- `ApiController` - 모든 API 컨트롤러의 베이스
- `CrudActions` concern - CRUD 자동화
- `app/models/` - 컨트롤러명에서 모델 클래스 추론
- `app/serializers/` - JSON:API 직렬화

### External
- `jsonapi.rb` gem - JSON:API 스펙 구현
- `ransack` gem - 필터링 및 정렬
- `kaminari` gem - 페이지네이션
- `faraday` gem - 외부 인증 서비스 호출 (AuthServiceClient)

<!-- MANUAL: -->
