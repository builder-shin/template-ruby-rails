<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# app

## Purpose
Rails 애플리케이션 소스 코드 루트. 컨트롤러, 모델, 시리얼라이저, 서비스, 백그라운드 잡으로 구성된다.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `controllers/` | API 컨트롤러 (see `controllers/AGENTS.md`) |
| `models/` | ActiveRecord 모델 (see `models/AGENTS.md`) |
| `serializers/` | JSON:API 시리얼라이저 (see `serializers/AGENTS.md`) |
| `services/` | 비즈니스 로직 서비스 객체 (see `services/AGENTS.md`) |
| `jobs/` | Sidekiq 백그라운드 잡 (see `jobs/AGENTS.md`) |
| `helpers/` | 헬퍼 모듈 (기본 설정만 존재) |
| `mailers/` | 메일러 (기본 설정만 존재) |

## For AI Agents

### Working In This Directory
- 새 리소스 추가 시 controller + model + serializer 세트로 생성
- 컨트롤러는 `app/controllers/api/v1/` 네임스페이스 아래에 생성
- 모델 association 이름 = 시리얼라이저 relationship 이름 = 테이블명 기준

### Common Patterns
- Controller → `ApiController` 상속 (CrudActions 자동 포함)
- Model → `ApplicationRecord` 상속
- Serializer → `ApplicationSerializer` 상속

<!-- MANUAL: -->
