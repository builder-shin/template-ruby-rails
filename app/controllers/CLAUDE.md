# Controllers

## 구조

```
controllers/
├── application_controller.rb  # Rails 기본 컨트롤러
├── api_controller.rb          # API 베이스 (ApiController)
├── concerns/
│   └── crud_actions.rb        # CRUD 자동화 concern
└── api/v1/                    # API v1 엔드포인트
    # 엔드포인트는 필요에 따라 추가하세요
```

## 새 컨트롤러 생성 패턴

```ruby
module Api
  module V1
    class ResourcesController < ApiController
      # CrudActions는 ApiController에서 이미 include되어 있음
      # 개별 컨트롤러에서 include 불필요

      before_action :user_check!  # 인증 필수 시

      # 필터링 가능 속성 정의
      def filter_attributes
        [:name, :status, :created_at]
      end

      # Strong parameters
      def model_params_options
        { only: [:title, :content, :user_id] }
      end

      # N+1 방지를 위한 scope 오버라이드 (필요 시)
      # def index_scope
      #   klass.includes(:user)
      # end
    end
  end
end
```

**중요**: `ApiController`가 이미 `CrudActions`를 include하므로, `Api::V1` 네임스페이스의 개별 컨트롤러에서 `include CrudActions`를 작성할 필요가 없습니다.

## CrudActions Concern

### 자동 제공 액션
- `index` - 목록 조회 (페이지네이션, 필터링, include 지원)
- `show` - 단일 조회
- `new` - 빈 모델 반환
- `create` - 생성
- `update` - 수정
- `destroy` - 삭제

### 라이프사이클 훅
훅에서 `render` 또는 `redirect`를 호출하면 이후 로직이 중단됨 (`performed?` 체크).

```ruby
def create_after_init
  # @model 생성 직후, 저장 전
  @model.user = user_info
end

def create_after_save(success)
  # 저장 후. success: true/false
  notify_admin if success
end
```

| 액션 | 훅 |
|------|-----|
| show | `show_after_init` |
| new | `new_after_init` |
| create | `create_after_init`, `create_after_save(success)` |
| update | `update_after_init`, `update_after_assign`, `update_after_save(success)` |
| destroy | `destroy_after_init`, `destroy_after_save(success)` |

### 핵심 메서드

```ruby
# 모델 클래스 반환 (컨트롤러명에서 자동 추론)
def klass
  controller_name.classify.constantize  # UsersController -> User
end

# 단일 조회용 모델 세팅 (show, update, destroy에서 사용)
def _set_model
  @model = klass.find_by(id: params[:id])
  raise NotFound.new(...) if @model.nil?
end

# 오버라이드하여 커스텀 scope 적용
def _set_model
  super
  raise NotFound.new("권한이 없습니다", "403") unless @model.user == user_info
end
```

### 커스텀 에러

```ruby
# JsonApiError 사용
raise JsonApiError.new("BadRequest", "이메일이 유효하지 않습니다", 400)
raise JsonApiError.new("Forbidden", "권한이 없습니다", 403)

# NotFound (JsonApiError 상속)
raise NotFound.new("리소스를 찾을 수 없습니다", "404")
```

### 오버라이드 가능 메서드

```ruby
# 필터링 허용 속성
def filter_attributes
  [:status, :created_at]
end

# Strong parameters 옵션
def model_params_options
  { only: [:title, :content] }
end

# 페이지네이션 메타 정보
def jsonapi_meta(resources)
  { "total-count" => jsonapi_pagination_meta(resources)[:records] }
end
```

## 코드 스타일: Guard Clause 패턴 (필수)

**if/elsif/else 패턴을 사용하지 않습니다.** 대신 guard clause (early return/raise) 패턴을 사용합니다.

```ruby
# ✅ Good: Guard clause 패턴
def verify_ownership!
  return if @model.user_id == user_info.id

  raise JsonApiError.new("Forbidden", "자신의 리소스만 수정할 수 있습니다.", 403)
end

# ✅ Good: 조건 불일치 시 먼저 처리하고 리턴
def index_scope
  return klass.where(workspace_id: user_info.workspace_id) if user_info.workspace_kind == "enterprise"

  klass.where(user_id: user_info.id)
end

# ✅ Good: unless + return으로 실패 케이스 먼저 처리
unless @model.save
  return render jsonapi_errors: @model.errors, status: :unprocessable_entity
end

render jsonapi: @model

# ✅ Good: 반복문 내에서는 next 사용
items.each do |item|
  next item if item.nil?

  process(item)
end

# ❌ Bad: if/else 분기
def verify_ownership!
  if @model.user_id == user_info.id
    # pass
  else
    raise JsonApiError.new("Forbidden", "자신의 리소스만 수정할 수 있습니다.", 403)
  end
end

# ❌ Bad: if/elsif/else 체인
def index_scope
  if user_info.workspace_kind == "enterprise"
    klass.where(workspace_id: user_info.workspace_id)
  else
    klass.where(user_id: user_info.id)
  end
end
```

**예외**: `case/when/else`는 허용합니다 (switch-case 패턴).

## 인증 및 인가

### 인증 메서드

```ruby
# 현재 로그인 사용자 (Bearer 토큰에서 추출)
user_info  # => AuthUser 또는 nil

# 인증 필수 체크 (미인증 시 401 에러)
before_action :user_check!
```

### 회원 유형별 인가

```ruby
# 개인회원만 접근 (403 Forbidden)
before_action :personal_check!, only: [:create, :update, :destroy]

# 기업회원만 접근 (403 Forbidden)
before_action :enterprise_check!, only: [:create, :update, :destroy]
```

### 소유권 검증 패턴

리소스 수정/삭제 시 소유자만 허용하는 패턴:

```ruby
module Api
  module V1
    class ProfilesController < ApiController
      # CrudActions는 ApiController에서 이미 include되어 있음

      # 인증 체크 먼저, 그 다음 인가
      before_action :user_check!
      before_action :personal_check!, only: [:create, :update, :destroy]
      before_action :verify_ownership!, only: [:update, :destroy]

      private

      # create 시 현재 사용자 ID 자동 설정
      def create_after_init
        @model.user_id = user_info.id
      end

      # update/destroy 시 소유권 검증
      def verify_ownership!
        return if @model.user_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 리소스만 수정할 수 있습니다.", 403)
      end
    end
  end
end
```

### before_action 순서 중요

`verify_ownership!`은 `_set_model` 이후에 실행되어야 `@model`에 접근 가능:

```ruby
# ✅ Good: _set_model이 먼저 실행된 후 verify_ownership! 실행
before_action :personal_check!, only: [:create, :update, :destroy]
before_action :verify_ownership!, only: [:update, :destroy]
# CrudActions의 before_action :_set_model이 show, update, destroy에 적용됨

# ❌ Bad: @model이 아직 없을 수 있음
before_action :verify_ownership!  # _set_model보다 먼저 실행되면 에러
```

## JSON:API 기능

```ruby
# 자동 지원 (CrudActions에서 처리)
# GET /resources?include=user,comments
# GET /resources?filter[status]=active
# GET /resources?page[number]=2&page[size]=20
```
