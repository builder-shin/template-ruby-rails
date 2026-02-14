<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# services

## Purpose
비즈니스 로직 서비스 객체. 외부 API 연동, 알림 발송, 추천 시스템 등 컨트롤러/모델에 속하지 않는 로직을 캡슐화한다.

## Key Files

| File | Description |
|------|-------------|
| `auth_service_client.rb` | 외부 Auth 서비스 연동 (세션 검증, Circuit Breaker 패턴) |
| `notification_service.rb` | 알림 발송 서비스 |
| `sendgrid_email_service.rb` | SendGrid 이메일 발송 서비스 |
| `job_recommendation_service.rb` | 채용 추천 서비스 |
| `job_notification_service.rb` | 채용 알림 서비스 |
| `job_category_matching_service.rb` | 직군 매칭 서비스 |

## For AI Agents

### Working In This Directory
- 서비스 객체는 단일 책임 원칙 준수
- 외부 API 호출은 Faraday 사용 (retry, timeout 설정)
- `AuthServiceClient`는 Circuit Breaker 패턴 구현 (실패 5회 → 30초 차단)
- 테스트 시 외부 API는 WebMock으로 스텁

<!-- MANUAL: -->
