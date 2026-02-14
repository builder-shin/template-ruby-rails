<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# config

## Purpose
Rails 애플리케이션 설정. 라우팅, 환경별 설정, 초기화 파일, 데이터베이스/캐시/스토리지 설정을 관리한다.

## Key Files

| File | Description |
|------|-------------|
| `routes.rb` | API 라우팅 정의 (`api/v1/` 네임스페이스) |
| `application.rb` | Rails 애플리케이션 설정 |
| `application.yml` | 앱 설정 (환경 변수) |
| `database.yml` | PostgreSQL 데이터베이스 연결 설정 |
| `puma.rb` | Puma 웹 서버 설정 |
| `storage.yml` | Active Storage (S3) 설정 |
| `sidekiq_cron.yml` | Sidekiq 크론 작업 스케줄 |
| `secrets.yml` | 시크릿 키 설정 |
| `cable.yml` | Action Cable 설정 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `environments/` | 환경별 설정 (development, test, production) |
| `initializers/` | 초기화 파일들 (see `initializers/AGENTS.md`) |
| `locales/` | i18n 번역 파일 |

## For AI Agents

### Working In This Directory
- 새 API 리소스 추가 시 `routes.rb`에 라우트 등록 필수
- 라우트는 `namespace :api > namespace :v1` 블록 안에 추가
- 환경 변수는 `application.yml` 또는 `.env`에서 관리

<!-- MANUAL: -->
