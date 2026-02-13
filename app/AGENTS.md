<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Rails Application Directory (app/)

## Purpose
Rails 애플리케이션의 핵심 코드가 위치하는 디렉토리. MVC 패턴에 따라 컨트롤러, 모델, 뷰가 구성되며, JSON:API 시리얼라이저, 서비스 객체, 백그라운드 작업, 메일러 등을 포함합니다.

## Key Files
| File | Description |
|------|-------------|
| (없음) | 모든 코드는 하위 디렉토리에 구조화됨 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `controllers/` | API 컨트롤러 (ApiController, CrudActions concern, api/v1 엔드포인트) (see `controllers/AGENTS.md`) |
| `models/` | ActiveRecord 모델 (35개 모델, auth 네임스페이스 포함) (see `models/AGENTS.md`) |
| `serializers/` | JSON:API 시리얼라이저 (jsonapi-serializer 사용) (see `serializers/AGENTS.md`) |
| `services/` | 서비스 객체 (AuthServiceClient 등) |
| `jobs/` | Sidekiq 백그라운드 작업 |
| `mailers/` | 이메일 발송 클래스 |
| `channels/` | ActionCable 웹소켓 채널 |
| `helpers/` | 뷰 헬퍼 (API 전용 프로젝트이므로 최소) |
| `views/` | 뷰 템플릿 (주로 메일러용) |
| `assets/` | 에셋 파일 (config, images, stylesheets) |

## For AI Agents

### Working In This Directory
Rails app 디렉토리에서 작업할 때:

1. **MVC 패턴 준수**: 비즈니스 로직은 모델/서비스에, HTTP 처리는 컨트롤러에
2. **JSON:API 스펙**: 모든 API 응답은 jsonapi-serializer를 통해 JSON:API 형식으로 직렬화
3. **CrudActions 활용**: 표준 CRUD는 concern으로 자동화, 커스텀 로직만 오버라이드
4. **N+1 방지**: 시리얼라이저에 관계 정의 시 컨트롤러에서 eager loading 자동 적용
5. **외부 서비스 연동**: AuthServiceClient를 통한 인증 토큰 검증

### Common Patterns

#### 새 API 엔드포인트 추가
```ruby
# 1. 컨트롤러 생성: app/controllers/api/v1/resources_controller.rb
module Api
  module V1
    class ResourcesController < ApiController
      include CrudActions
      before_action :user_check!

      def filter_attributes
        [:name, :status]
      end

      def model_params_options
        { only: [:name, :description, :user_id] }
      end
    end
  end
end

# 2. 시리얼라이저 생성: app/serializers/resource_serializer.rb
class ResourceSerializer < ApplicationSerializer
  attributes :id, :name, :description, :status, :created_at
  belongs_to :user
end

# 3. 모델 생성: app/models/resource.rb
class Resource < ApplicationRecord
  belongs_to :user
  validates :name, presence: true
end
```

#### 인증이 필요한 엔드포인트
```ruby
class ProfilesController < ApiController
  include CrudActions

  # 인증 필수
  before_action :user_check!

  # 개인회원만 접근
  before_action :personal_check!, only: [:create, :update, :destroy]

  # 현재 사용자 ID 자동 설정
  def create_after_init
    @model.user_id = user_info.id
  end
end
```

#### 서비스 객체 호출
```ruby
# app/services/auth_service_client.rb 사용
class ApiController < ApplicationController
  def user_info
    return @user_info if defined?(@user_info)

    session_token = cookies[:session_web]
    return nil unless session_token

    @user_info = AuthServiceClient.verify_session(session_token)
  end
end
```

#### 백그라운드 작업
```ruby
# app/jobs/notification_job.rb
class NotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, message)
    # 비동기 처리 로직
  end
end

# 컨트롤러에서 호출
NotificationJob.perform_later(user.id, "알림 메시지")
```

#### 메일 발송
```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: '회원가입을 환영합니다')
  end
end

# 사용
UserMailer.welcome_email(user).deliver_later
```

## Dependencies

### Internal
- `controllers/` → `models/`, `serializers/`
- `serializers/` → `models/`
- `services/` → 외부 API
- `jobs/` → `models/`, `mailers/`

### External
- Rails 프레임워크 (ActionController, ActiveRecord, ActionMailer 등)
- jsonapi-serializer gem
- Sidekiq (백그라운드 작업)

<!-- MANUAL: -->
