<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# serializers

## Purpose
JSON:API 시리얼라이저. `jsonapi-serializer` gem을 사용하여 모델을 JSON:API 스펙에 맞게 직렬화한다.

## Key Files

| File | Description |
|------|-------------|
| `application_serializer.rb` | 베이스 시리얼라이저 (`JSONAPI::Serializer` 포함) |
| `profile_serializer.rb` | 프로필 시리얼라이저 (다수 관계 포함) |
| `job_post_serializer.rb` | 채용 공고 시리얼라이저 |
| `blog_post_serializer.rb` | 블로그 게시글 시리얼라이저 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `auth/` | Auth 모델 시리얼라이저 (see `auth/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- `ApplicationSerializer` 상속 필수
- `belongs_to` / `has_many` relationship 정의 시 컨트롤러에서 `allowed_includes`와 `includes` 적용 필수
- Relationship 이름 = 모델 association 이름 = 테이블명 기준
- FK 컬럼명이 `#{관계명}_id`와 다르면 `id_method_name:` 명시

### Common Patterns
```ruby
class ExampleSerializer < ApplicationSerializer
  attributes :name, :status, :created_at

  belongs_to :parent_model
  has_many :child_models
end
```

<!-- MANUAL: -->
