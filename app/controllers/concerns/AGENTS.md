<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# concerns

## Purpose
컨트롤러 공통 로직 모듈. CRUD 액션, JSON:API 에러 처리, 필터링, 페이지네이션을 제공한다.

## Key Files

| File | Description |
|------|-------------|
| `crud_actions.rb` | CRUD 공통 로직 — index/show/create/update/destroy + JSON:API 통합 |

## For AI Agents

### Working In This Directory
- `CrudActions`는 `ApiController`에 이미 include 되어 있음
- `JsonApiError` 커스텀 예외: `JsonApiError.new(title, message, status_code)`
- `NotFound` 예외: `CrudActions::NotFound`
- JSONAPI 모듈 자동 포함: `Deserialization`, `Fetching`, `Filtering`, `Pagination`, `Errors`

### Key Hook Methods (Override in Controllers)
- `index_scope` → index 기본 쿼리 스코프
- `filter_attributes` → Ransack 필터 허용 속성
- `allowed_includes` → JSON:API include 허용 관계
- `model_params_options` → jsonapi_deserialize 옵션
- `*_after_init`, `*_after_save(success)` → 라이프사이클 훅

<!-- MANUAL: -->
