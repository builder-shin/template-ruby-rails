<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Auth Models (app/models/auth/)

## Purpose
외부 인증 서비스의 데이터 모델. 실제 데이터베이스 테이블이 아니라, AuthServiceClient를 통해 외부 인증 서비스에서 가져온 데이터를 Ruby 객체로 매핑합니다. 사용자, 워크스페이스, 동의 정보 등을 포함합니다.

## Key Files
| File | Description |
|------|-------------|
| `base.rb` | 인증 모델 베이스 클래스 (외부 API 응답 매핑 로직) |
| `user.rb` | 사용자 정보 (id, email, name, user_type 등) |
| `workspace.rb` | 워크스페이스 정보 |
| `user_consent.rb` | 사용자 동의 정보 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| (없음) | 모든 모델이 flat 구조로 배치됨 |

## For AI Agents

### Working In This Directory
Auth 모델 작업 시:

1. **외부 서비스 데이터**: 이 모델들은 로컬 DB 테이블이 아님
2. **Auth::Base 상속**: 모든 Auth 모델은 `Auth::Base`를 상속
3. **읽기 전용**: 외부 인증 서비스에서 조회만 가능 (생성/수정은 인증 서비스에서)
4. **AuthServiceClient 연동**: `AuthServiceClient.verify_session(token)`으로 사용자 정보 조회
5. **user_id 참조**: 다른 모델에서 `user_id`로 Auth::User의 id를 참조

### Common Patterns

#### Auth::Base 구조
```ruby
module Auth
  class Base
    include ActiveModel::Model
    include ActiveModel::Serialization

    # 외부 API 응답을 Ruby 객체로 변환
    def self.from_api_response(data)
      new(data)
    end

    def initialize(attributes = {})
      attributes.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end
  end
end
```

#### Auth::User (사용자)
```ruby
module Auth
  class User < Base
    attr_accessor :id, :email, :name, :user_type, :created_at, :updated_at

    # user_type: "personal" (개인회원) 또는 "enterprise" (기업회원)
    def personal?
      user_type == "personal"
    end

    def enterprise?
      user_type == "enterprise"
    end
  end
end
```

#### AuthServiceClient 사용 (컨트롤러에서)
```ruby
class ApiController < ApplicationController
  def user_info
    return @user_info if defined?(@user_info)

    session_token = cookies[:session_web]
    return nil unless session_token

    # 외부 인증 서비스에 토큰 검증 요청
    @user_info = AuthServiceClient.verify_session(session_token)
    # @user_info는 Auth::User 객체 또는 nil
  end

  def user_check!
    raise JsonApiError.new("Unauthorized", "인증이 필요합니다", 401) unless user_info
  end

  def personal_check!
    return if user_info&.personal?
    raise JsonApiError.new("Forbidden", "개인회원만 접근할 수 있습니다", 403)
  end

  def enterprise_check!
    return if user_info&.enterprise?
    raise JsonApiError.new("Forbidden", "기업회원만 접근할 수 있습니다", 403)
  end
end
```

#### 다른 모델에서 user_id 참조
```ruby
class Profile < ApplicationRecord
  # user_id는 외부 인증 서비스의 UUID (Auth::User#id)
  # belongs_to :user 대신 validates만 사용
  validates :user_id, presence: true, uniqueness: true

  # 컨트롤러에서 user_id 설정
  # def create_after_init
  #   @model.user_id = user_info.id  # user_info는 Auth::User 객체
  # end
end
```

#### Auth::Workspace (워크스페이스)
```ruby
module Auth
  class Workspace < Base
    attr_accessor :id, :name, :owner_id, :created_at, :updated_at

    # 기업 계정의 워크스페이스 정보
  end
end
```

#### Auth::UserConsent (사용자 동의)
```ruby
module Auth
  class UserConsent < Base
    attr_accessor :id, :user_id, :consent_type, :consented_at, :created_at, :updated_at

    # 서비스 이용 약관, 개인정보 처리 방침 등 동의 정보
  end
end
```

#### 시리얼라이저에서 참조
```ruby
# ProfileSerializer에서
class ProfileSerializer < ApplicationSerializer
  attributes :id, :user_id, :name, :email_public

  # belongs_to :user - User는 외부 인증 서비스에서 관리
  # user_id만 attributes로 노출
  belongs_to :job_category
  has_many :profile_experiences
end
```

#### 데이터 흐름
```
1. 클라이언트 → 쿠키(session_web) 포함하여 API 요청
2. ApiController#user_info → 쿠키에서 session_token 추출
3. AuthServiceClient.verify_session(token) → 외부 인증 서비스 호출
4. 외부 서비스 응답 → Auth::User 객체로 변환
5. user_info.id → 컨트롤러에서 user_id로 사용
```

## Dependencies

### Internal
- `Auth::Base` - 모든 Auth 모델의 베이스
- `app/services/auth_service_client.rb` - 외부 인증 서비스 HTTP 클라이언트

### External
- ActiveModel (Model, Serialization)
- Faraday (HTTP 클라이언트, AuthServiceClient에서 사용)

<!-- MANUAL: -->
