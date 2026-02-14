<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# jobs

## Purpose
Sidekiq 백그라운드 잡. 스케줄 작업(채용 공고 활성화/마감), 알림 발송, 이미지 처리 등을 비동기로 처리한다.

## Key Files

| File | Description |
|------|-------------|
| `application_job.rb` | 베이스 잡 클래스 |
| `activate_scheduled_job_posts_job.rb` | 예약된 채용 공고 활성화 |
| `close_expired_job_posts_job.rb` | 만료된 채용 공고 마감 |
| `cleanup_incomplete_profiles_job.rb` | 미완성 프로필 정리 |
| `process_event_notifications_job.rb` | 이벤트 알림 처리 |
| `process_image_variants_job.rb` | 이미지 변환 처리 (Active Storage) |
| `send_job_recommendations_job.rb` | 채용 추천 발송 |
| `send_notification_job.rb` | 일반 알림 발송 |

## For AI Agents

### Working In This Directory
- `ApplicationJob` 상속 필수
- 크론 스케줄은 `config/sidekiq_cron.yml`에서 관리
- Sidekiq 7.3+ 사용

<!-- MANUAL: -->
