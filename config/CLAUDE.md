# Config

Rails 및 gem 설정 파일들.

## 주요 파일

| 파일 | 용도 |
|------|------|
| `routes.rb` | 라우팅 정의 |
| `database.yml` | DB 연결 설정 (환경변수 사용) |
| `application.yml` | 앱 설정 |
| `application.rb` | Rails 앱 설정 |

## Initializers

| 파일 | 용도 |
|------|------|
| `active_storage.rb` | Active Storage 설정 |
| `assets.rb` | Asset Pipeline 설정 |
| `auth_service.rb` | AuthServiceClient 설정 |
| `aws.rb` | AWS S3 연동 설정 |
| `content_security_policy.rb` | CSP 설정 |
| `cookies_serializer.rb` | 쿠키 직렬화 설정 |
| `cors.rb` | CORS 설정 |
| `filter_parameter_logging.rb` | 로그 파라미터 필터링 |
| `inflections.rb` | 복수형/단수형 규칙 |
| `jsonapi.rb` | JSON:API 설정 |
| `lograge.rb` | 로그 포맷 설정 |
| `mime_types.rb` | MIME 타입 설정 |
| `permissions_policy.rb` | 권한 정책 설정 |
| `rswag_api.rb` | rswag API 설정 |
| `rswag_ui.rb` | rswag UI 설정 |
| `wrap_parameters.rb` | 파라미터 래핑 설정 |

## 환경별 설정

- `environments/development.rb` - 개발 환경
- `environments/test.rb` - 테스트 환경
- `environments/production.rb` - 프로덕션 환경

## 환경 변수

`.env` 파일에서 정의 (gitignore됨):

```env
# 인증 서비스
AUTH_SERVICE_URL=http://localhost:4000  # 외부 인증 서비스 URL

# 데이터베이스
DATABASE_URL=postgres://user:pass@localhost:5432/template_development
DEV_DATABASE_HOST=localhost
DEV_DATABASE_USERNAME=postgres
DEV_DATABASE_PASSWORD=password

# Rails
SECRET_KEY_BASE=...
RAILS_ENV=development
```

### 필수 환경 변수

| 변수 | 설명 | 예시 |
|------|------|------|
| `AUTH_SERVICE_URL` | 인증 서비스 URL | `http://localhost:4000` |
| `DATABASE_URL` | PostgreSQL 연결 | `postgres://...` |
| `SECRET_KEY_BASE` | Rails secret | 64자 이상 |

## 라우팅 패턴

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :resources  # CRUD 전체
    resources :items, only: [:index, :show]  # 읽기만
  end
end
```

## 새 initializer 추가 시

`config/initializers/` 디렉토리에 파일 생성. 알파벳 순으로 로드됨.
