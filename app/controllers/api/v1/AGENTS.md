<!-- Parent: ../../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# v1

## Purpose
API v1 엔드포인트 컨트롤러. 모든 컨트롤러는 `ApiController`를 상속하며, `CrudActions` concern의 CRUD 로직을 기본으로 사용한다. 라우팅은 `config/routes.rb`의 `namespace :api > namespace :v1` 블록에서 정의된다.

## Key Files

| File | Description |
|------|-------------|
| `profiles_controller.rb` | 프로필 CRUD |
| `profile_attachments_controller.rb` | 프로필 첨부파일 |
| `profile_educations_controller.rb` | 프로필 학력 |
| `profile_experiences_controller.rb` | 프로필 경력 |
| `profile_freelance_experiences_controller.rb` | 프로필 프리랜서 경력 |
| `profile_highlights_controller.rb` | 프로필 하이라이트 |
| `profile_jobs_controller.rb` | 프로필-직무 매핑 |
| `profile_languages_controller.rb` | 프로필 언어 |
| `profile_links_controller.rb` | 프로필 링크 |
| `profile_projects_controller.rb` | 프로필 프로젝트 |
| `featured_profiles_controller.rb` | 추천 프로필 (read-only) |
| `job_posts_controller.rb` | 채용 공고 CRUD |
| `job_post_categories_controller.rb` | 채용 공고-직군 매핑 |
| `job_post_jobs_controller.rb` | 채용 공고-직무 매핑 |
| `job_post_languages_controller.rb` | 채용 공고 언어 요건 |
| `job_post_status_logs_controller.rb` | 채용 공고 상태 변경 로그 |
| `jobs_controller.rb` | 직무 (read-only) |
| `job_categories_controller.rb` | 직군 카테고리 (read-only) |
| `job_applications_controller.rb` | 채용 지원서 |
| `blog_posts_controller.rb` | 블로그 게시글 |
| `blog_author_permissions_controller.rb` | 블로그 작성 권한 |
| `blog_categories_controller.rb` | 블로그 카테고리 |
| `blog_post_categories_controller.rb` | 블로그-카테고리 매핑 |
| `blog_views_controller.rb` | 블로그 조회 기록 |
| `career_hub_categories_controller.rb` | 커리어허브 카테고리 (read-only) |
| `career_hub_communities_controller.rb` | 커리어허브 커뮤니티 |
| `career_hub_community_events_controller.rb` | 커뮤니티 이벤트 |
| `career_hub_community_event_participants_controller.rb` | 이벤트 참가자 |
| `career_hub_community_feeds_controller.rb` | 커뮤니티 피드 |
| `career_hub_community_feed_likes_controller.rb` | 피드 좋아요 |
| `career_hub_community_leaders_controller.rb` | 커뮤니티 리더 |
| `career_hub_community_members_controller.rb` | 커뮤니티 멤버 |
| `career_hub_event_reviews_controller.rb` | 이벤트 리뷰 |
| `countries_controller.rb` | 국가 (read-only) |
| `direct_uploads_controller.rb` | Active Storage 다이렉트 업로드 |
| `email_templates_controller.rb` | 이메일 템플릿 관리 |
| `event_notification_schedules_controller.rb` | 이벤트 알림 스케줄 관리 |
| `highlight_references_controller.rb` | 하이라이트 참조 데이터 |
| `practical_strength_references_controller.rb` | 실무 강점 참조 데이터 |
| `application_context_references_controller.rb` | 적용 맥락 참조 데이터 |
| `recommendation_notification_histories_controller.rb` | 추천 알림 이력 |
| `recruitment_requests_controller.rb` | 채용 의뢰 (create-only) |

## For AI Agents

### Working In This Directory
- `Api::V1::` 네임스페이스 사용: `class Api::V1::ExamplesController < ApiController`
- `CrudActions` include 불필요 — `ApiController`에 이미 포함됨
- 새 컨트롤러 추가 시 `config/routes.rb`에 라우트 등록 필수

### Guard Clause 패턴 (필수)
```ruby
# Good - guard clause
def create_after_init
  raise JsonApiError.new("Forbidden", "권한이 없습니다.", 403) unless authorized?
  @model.user_id = user_info.id
end

# Bad - if/else
def create_after_init
  if authorized?
    @model.user_id = user_info.id
  else
    raise JsonApiError.new("Forbidden", "권한이 없습니다.", 403)
  end
end
```

### Controller Template
```ruby
class Api::V1::ExamplesController < ApiController
  before_action :user_check!

  def filter_attributes
    [:name_cont, :status_eq]
  end

  def allowed_includes
    [:parent_model, :child_models]
  end

  def model_params_options
    { only: [:name, :status, :parent_model_id] }
  end

  def index_scope
    klass.where(user_id: user_info.id)
  end

  def create_after_init
    @model.user_id = user_info.id
  end
end
```

### Common Hook Overrides
- `index_scope` → 사용자별 필터링, 기본 정렬
- `create_after_init` → 현재 사용자 ID 설정, 권한 체크
- `update_after_init` → 소유자 검증
- `destroy_after_init` → 삭제 권한 검증
- `show_after_init` → 접근 권한 검증
- `filter_attributes` → Ransack 필터 허용 목록
- `allowed_includes` → JSON:API include 허용 관계
- `model_params_options` → 허용할 파라미터 (`:only` / `:except`)

<!-- MANUAL: -->
