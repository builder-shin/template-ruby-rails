<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# controllers

## Purpose
API 컨트롤러 계층. `ApplicationController` → `ApiController` → 개별 컨트롤러 상속 구조. JSON:API 스펙을 따르며, CRUD 공통 로직은 `CrudActions` concern에 집중되어 있다.

## Key Files

| File | Description |
|------|-------------|
| `application_controller.rb` | Rails 기본 컨트롤러 |
| `api_controller.rb` | API 베이스 컨트롤러 — 인증, 권한 체크, CrudActions 포함 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `concerns/` | 공통 concern 모듈 (see `concerns/AGENTS.md`) |
| `api/v1/` | API v1 엔드포인트 컨트롤러들 (see `api/v1/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- 새 컨트롤러는 `api/v1/` 네임스페이스 아래 생성
- `ApiController` 상속 — `CrudActions`가 이미 포함되어 있으므로 개별 include 불필요
- `before_action :user_check!` 로 인증 필수 설정
- `before_action :personal_check!` / `:enterprise_check!` 로 회원 유형 체크

### Guard Clause 패턴 (필수)
- **if/elsif/else 패턴 금지** — guard clause (early return/raise) 사용
- 조건 불일치 시 `raise` 또는 `return`으로 먼저 빠져나가고, 정상 흐름을 아래에 배치
- `case/when/else`는 허용

### Common Patterns
- CRUD 커스터마이징: `create_after_init`, `update_after_assign`, `show_after_init` 등의 훅 메서드 오버라이드
- `model_params_options`: jsonapi_deserialize 옵션 정의
- `filter_attributes`: Ransack 필터 허용 속성 배열
- `allowed_includes`: JSON:API include 허용 관계 배열
- `index_scope`: index 액션의 기본 스코프 오버라이드

<!-- MANUAL: -->
