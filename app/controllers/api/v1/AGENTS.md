<!-- Parent: ../../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# API v1 Controllers (app/controllers/api/v1/)

## Purpose
JSON:API v1 엔드포인트 컨트롤러 모음. 프리랜서 프로필, 채용 공고, 블로그, 커리어 허브 커뮤니티 등 플랫폼의 모든 리소스에 대한 CRUD API를 제공합니다. 총 42개의 리소스 컨트롤러가 포함되어 있습니다.

## Key Files
| File | Description |
|------|-------------|
| `profiles_controller.rb` | 프리랜서 프로필 관리 |
| `job_posts_controller.rb` | 채용 공고 관리 |
| `job_applications_controller.rb` | 지원 관리 |
| `blog_posts_controller.rb` | 블로그 게시글 관리 |
| `blog_categories_controller.rb` | 블로그 카테고리 관리 |
| `career_hub_communities_controller.rb` | 커리어 허브 커뮤니티 관리 |
| `career_hub_community_feeds_controller.rb` | 커뮤니티 피드 관리 |
| `career_hub_community_events_controller.rb` | 커뮤니티 이벤트 관리 |
| `direct_uploads_controller.rb` | 파일 직접 업로드 (Active Storage) |
| `countries_controller.rb` | 국가 정보 조회 |
| `job_categories_controller.rb` | 직무 카테고리 조회 |
| `jobs_controller.rb` | 직무 정보 조회 |
| `featured_profiles_controller.rb` | 추천 프로필 관리 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| (없음) | 모든 컨트롤러가 flat 구조로 배치됨 |

## For AI Agents

### Working In This Directory
API v1 컨트롤러 작업 시:

1. **Flat 구조 유지**: 모든 컨트롤러는 이 디렉토리에 flat하게 배치 (하위 폴더 생성 금지)
2. **네이밍 규칙**: `{리소스명(복수형)}_controller.rb` (예: `profiles_controller.rb`)
3. **네임스페이스**: `module Api::V1` 필수
4. **CrudActions 활용**: 표준 CRUD는 concern으로 자동화
5. **인증 체크**: 필요 시 `before_action :user_check!` 추가
6. **라우팅**: `config/routes.rb`의 `namespace :api do namespace :v1` 블록 내에 등록

### Common Patterns

#### 리소스별 컨트롤러 분류

**프로필 관련 (8개)**
- `profiles_controller.rb` - 프리랜서 프로필
- `profile_experiences_controller.rb` - 경력
- `profile_educations_controller.rb` - 학력
- `profile_freelance_experiences_controller.rb` - 프리랜서 경험
- `profile_projects_controller.rb` - 프로젝트
- `profile_languages_controller.rb` - 언어 능력
- `profile_links_controller.rb` - 링크
- `profile_highlights_controller.rb` - 하이라이트
- `profile_attachments_controller.rb` - 첨부파일
- `profile_jobs_controller.rb` - 직무 연결

**채용 공고 관련 (6개)**
- `job_posts_controller.rb` - 채용 공고
- `job_applications_controller.rb` - 지원
- `job_post_categories_controller.rb` - 공고 카테고리 연결
- `job_post_languages_controller.rb` - 공고 언어 요구사항
- `job_post_jobs_controller.rb` - 공고 직무 연결
- `job_post_status_logs_controller.rb` - 공고 상태 로그

**블로그 관련 (5개)**
- `blog_posts_controller.rb` - 블로그 게시글
- `blog_categories_controller.rb` - 블로그 카테고리
- `blog_post_categories_controller.rb` - 게시글 카테고리 연결
- `blog_author_permissions_controller.rb` - 작성 권한
- `blog_views_controller.rb` - 조회수

**커리어 허브 커뮤니티 (10개)**
- `career_hub_communities_controller.rb` - 커뮤니티
- `career_hub_community_feeds_controller.rb` - 커뮤니티 피드
- `career_hub_community_events_controller.rb` - 커뮤니티 이벤트
- `career_hub_community_members_controller.rb` - 커뮤니티 멤버
- `career_hub_community_leaders_controller.rb` - 커뮤니티 리더
- `career_hub_community_event_participants_controller.rb` - 이벤트 참가자
- `career_hub_community_feed_likes_controller.rb` - 피드 좋아요
- `career_hub_event_reviews_controller.rb` - 이벤트 리뷰
- `career_hub_categories_controller.rb` - 커리어 허브 카테고리

**참조 데이터 (4개)**
- `countries_controller.rb` - 국가
- `job_categories_controller.rb` - 직무 카테고리
- `jobs_controller.rb` - 직무

**기타 (9개)**
- `direct_uploads_controller.rb` - 파일 직접 업로드
- `featured_profiles_controller.rb` - 추천 프로필
- `recruitment_requests_controller.rb` - 채용 요청
- `recommendation_notification_histories_controller.rb` - 추천 알림 이력
- `email_templates_controller.rb` - 이메일 템플릿
- `event_notification_schedules_controller.rb` - 이벤트 알림 스케줄
- `application_context_references_controller.rb` - 애플리케이션 컨텍스트 참조
- `highlight_references_controller.rb` - 하이라이트 참조
- `practical_strength_references_controller.rb` - 실무 강점 참조

#### Guard Clause 패턴 (필수)
- **if/elsif/else 패턴 금지** — guard clause (early return/raise) 사용
- 조건 불일치 시 `raise` 또는 `return`으로 먼저 빠져나가고, 정상 흐름을 아래에 배치
- 반복문 내에서는 `next` 사용
- `case/when/else`는 허용 (switch-case 패턴)

#### 기본 컨트롤러 구조
```ruby
module Api
  module V1
    class ResourcesController < ApiController
      # CrudActions는 ApiController에서 이미 include됨

      before_action :user_check!

      def filter_attributes
        [:name, :status, :created_at]
      end

      def model_params_options
        { only: [:title, :content] }
      end
    end
  end
end
```

#### 프로필 컨트롤러 패턴 (소유권 검증 — Guard Clause)
```ruby
module Api
  module V1
    class ProfilesController < ApiController
      before_action :user_check!
      before_action :personal_check!, only: [:create, :update, :destroy]
      before_action :verify_ownership!, only: [:update, :destroy]

      private

      def create_after_init
        @model.user_id = user_info.id
      end

      def verify_ownership!
        return if @model.user_id == user_info.id

        raise JsonApiError.new("Forbidden", "자신의 프로필만 수정할 수 있습니다.", 403)
      end
    end
  end
end
```

#### 파일 업로드 컨트롤러 (direct_uploads_controller.rb)
```ruby
module Api
  module V1
    class DirectUploadsController < ApiController
      # Active Storage 직접 업로드 엔드포인트
      # 클라이언트가 S3에 직접 업로드할 수 있도록 presigned URL 제공
      def create
        blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
        render json: direct_upload_json(blob)
      end
    end
  end
end
```

#### 참조 데이터 컨트롤러 (읽기 전용)
```ruby
module Api
  module V1
    class CountriesController < ApiController
      # CrudActions는 ApiController에서 이미 include됨
      # 인증 불필요 (공개 데이터)
      # routes.rb에서 only: [:index, :show]로 읽기 전용 제한
    end
  end
end
```

#### JSON:API 요청 예시
```bash
# 프로필 목록 조회 (관계 포함)
GET /api/v1/profiles?include=job_category,profile_experiences,profile_educations

# 채용 공고 필터링
GET /api/v1/job_posts?filter[status]=active&filter[job_category_id]=1

# 커뮤니티 피드 정렬 및 페이지네이션
GET /api/v1/career_hub_community_feeds?sort=-created_at&page[number]=2&page[size]=20
```

#### 라우팅 등록
```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :profiles
    resources :job_posts
    resources :blog_posts
    # ...
  end
end
```

## Dependencies

### Internal
- `ApiController` - 베이스 컨트롤러
- `CrudActions` concern - CRUD 자동화
- `app/models/` - 각 컨트롤러에 대응하는 모델
- `app/serializers/` - JSON:API 직렬화

### External
- `jsonapi.rb` - JSON:API 렌더링
- `kaminari` - 페이지네이션
- `ransack` - 필터링

<!-- MANUAL: -->
