<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Auth Serializers (app/serializers/auth/)

## Purpose
외부 인증 서비스 모델을 위한 JSON:API 시리얼라이저. Auth::User, Auth::Workspace, Auth::UserConsent 등을 JSON:API 형식으로 직렬화합니다. 외부 API에서 가져온 데이터를 프론트엔드에 전달할 때 사용됩니다.

## Key Files
| File | Description |
|------|-------------|
| `user_serializer.rb` | 사용자 정보 시리얼라이저 (id, email, name, user_type 등) |
| `workspace_serializer.rb` | 워크스페이스 시리얼라이저 |
| `user_consent_serializer.rb` | 사용자 동의 정보 시리얼라이저 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| (없음) | 모든 시리얼라이저가 flat 구조로 배치됨 |

## For AI Agents

### Working In This Directory
Auth 시리얼라이저 작업 시:

1. **ApplicationSerializer 상속**: 모든 시리얼라이저는 `ApplicationSerializer`를 상속
2. **외부 데이터**: Auth 모델은 로컬 DB가 아닌 외부 인증 서비스 데이터
3. **네임스페이스**: `Auth::UserSerializer` 형식으로 네임스페이스 유지
4. **관계 없음**: 외부 서비스 모델이므로 대부분 belongs_to/has_many 없음
5. **읽기 전용**: 외부 서비스에서 조회만 가능 (생성/수정은 인증 서비스)

### Common Patterns

#### Auth::UserSerializer (사용자)
```ruby
module Auth
  class UserSerializer < ApplicationSerializer
    attributes :id, :email, :name, :user_type, :created_at, :updated_at

    # user_type: "personal" (개인회원) 또는 "enterprise" (기업회원)
    # 관계 없음 (외부 서비스 데이터)
  end
end
```

#### Auth::WorkspaceSerializer (워크스페이스)
```ruby
module Auth
  class WorkspaceSerializer < ApplicationSerializer
    attributes :id, :name, :owner_id, :created_at, :updated_at

    # 기업 계정의 워크스페이스 정보
  end
end
```

#### Auth::UserConsentSerializer (사용자 동의)
```ruby
module Auth
  class UserConsentSerializer < ApplicationSerializer
    attributes :id, :user_id, :consent_type, :consented_at, :created_at, :updated_at

    # 서비스 이용 약관, 개인정보 처리 방침 등 동의 정보
  end
end
```

#### 컨트롤러에서 사용
```ruby
class ApiController < ApplicationController
  # 현재 사용자 정보 조회 엔드포인트 (예시)
  def current_user
    render jsonapi: user_info, serializer: Auth::UserSerializer
  end
end

# JSON 응답:
# {
#   "data": {
#     "id": "uuid-123",
#     "type": "auth_user",
#     "attributes": {
#       "email": "user@example.com",
#       "name": "홍길동",
#       "user_type": "personal",
#       "created_at": "2024-01-01T00:00:00.000Z"
#     }
#   }
# }
```

#### 다른 시리얼라이저에서 참조하지 않음
```ruby
# ProfileSerializer에서
class ProfileSerializer < ApplicationSerializer
  attributes :id, :user_id, :name

  # belongs_to :user, serializer: Auth::UserSerializer  ← 사용하지 않음
  # user_id만 attributes로 노출 (외부 서비스 ID)
  belongs_to :job_category
end
```

#### JSON:API 응답 예시
```json
{
  "data": {
    "id": "uuid-123",
    "type": "auth_user",
    "attributes": {
      "id": "uuid-123",
      "email": "user@example.com",
      "name": "홍길동",
      "user_type": "personal",
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    }
  }
}
```

## Dependencies

### Internal
- `ApplicationSerializer` - 베이스 시리얼라이저
- `app/models/auth/` - Auth 모델 (외부 서비스 데이터 매핑)

### External
- `jsonapi-serializer` gem - JSON:API 직렬화

<!-- MANUAL: -->
