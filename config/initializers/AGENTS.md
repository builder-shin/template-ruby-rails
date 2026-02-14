<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# initializers

## Purpose
Rails 부트 시 실행되는 초기화 파일들. 외부 서비스 연결, 미들웨어, 보안 설정을 구성한다.

## Key Files

| File | Description |
|------|-------------|
| `auth_service.rb` | AuthServiceClient 설정 (URL, timeout, cache TTL) |
| `cors.rb` | CORS 설정 (Rack::Cors) |
| `rack_attack.rb` | Rate Limiting 설정 (Rack::Attack) |
| `jsonapi.rb` | JSON:API 설정 |
| `sidekiq.rb` | Sidekiq Redis 연결 설정 |
| `sentry.rb` | Sentry 에러 트래킹 설정 |
| `sendgrid.rb` | SendGrid 이메일 서비스 설정 |
| `aws.rb` | AWS S3 설정 |
| `active_storage.rb` | Active Storage 설정 |
| `lograge.rb` | 로그 포맷 설정 |
| `content_security_policy.rb` | CSP 보안 헤더 설정 |
| `permissions_policy.rb` | 권한 정책 설정 |
| `inflections.rb` | Rails 단수/복수 변환 규칙 |

## For AI Agents

### Working In This Directory
- 환경 변수는 `ENV[]` 또는 `Rails.application.config.x.*`로 접근
- 새 외부 서비스 연동 시 이 디렉토리에 초기화 파일 추가

<!-- MANUAL: -->
