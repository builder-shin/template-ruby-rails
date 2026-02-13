<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Serializers (app/serializers/)

## Purpose
JSON:API 스펙 준수 시리얼라이저 레이어. jsonapi-serializer gem을 사용하여 ActiveRecord 모델을 JSON:API 형식으로 직렬화합니다. 총 43개의 시리얼라이저가 포함되어 있으며, 모델과 1:1 대응됩니다.

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | 시리얼라이저 패턴, 관계명 규칙, id_method_name 가이드 |
| `application_serializer.rb` | 모든 시리얼라이저의 베이스 클래스 |
| `profile_serializer.rb` | 프리랜서 프로필 시리얼라이저 |
| `job_post_serializer.rb` | 채용 공고 시리얼라이저 |
| `blog_post_serializer.rb` | 블로그 게시글 시리얼라이저 |
| `career_hub_community_serializer.rb` | 커리어 허브 커뮤니티 시리얼라이저 |
| `country_serializer.rb` | 국가 시리얼라이저 |
| `job_category_serializer.rb` | 직무 카테고리 시리얼라이저 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `auth/` | 외부 인증 서비스 모델 시리얼라이저 (UserSerializer, WorkspaceSerializer 등) |

## For AI Agents

### Working In This Directory
시리얼라이저 작업 시:

1. **ApplicationSerializer 상속**: 모든 시리얼라이저는 `ApplicationSerializer`를 상속
2. **관계명 = 파일명(테이블명) 규칙**: 시리얼라이저 관계명은 모델 association 이름과 반드시 일치
3. **id_method_name**: DB FK 컬럼명이 `#{관계명}_id`와 다를 때 `belongs_to`에 명시
4. **JSON:API 형식**: `data`, `attributes`, `relationships`, `included` 구조
5. **N+1 방지**: 관계 정의 시 컨트롤러에서 자동 eager loading (CrudActions)

### Common Patterns

#### 시리얼라이저 분류

**프로필 관련 (10개)**
- `profile_serializer.rb`
- `profile_experience_serializer.rb`
- `profile_education_serializer.rb`
- `profile_freelance_experience_serializer.rb`
- `profile_project_serializer.rb`
- `profile_language_serializer.rb`
- `profile_link_serializer.rb`
- `profile_highlight_serializer.rb`
- `profile_attachment_serializer.rb`
- `profile_job_serializer.rb`

**채용 공고 관련 (7개)**
- `job_post_serializer.rb`
- `job_application_serializer.rb`
- `job_post_category_serializer.rb`
- `job_post_language_serializer.rb`
- `job_post_job_serializer.rb`
- `job_post_status_log_serializer.rb`
- `recruitment_request_serializer.rb`

**블로그 관련 (5개)**
- `blog_post_serializer.rb`
- `blog_category_serializer.rb`
- `blog_post_category_serializer.rb`
- `blog_author_permission_serializer.rb`
- `blog_view_serializer.rb`

**커리어 허브 커뮤니티 (10개)**
- `career_hub_community_serializer.rb`
- `career_hub_community_feed_serializer.rb`
- `career_hub_community_event_serializer.rb`
- `career_hub_community_member_serializer.rb`
- `career_hub_community_leader_serializer.rb`
- `career_hub_community_event_participant_serializer.rb`
- `career_hub_community_feed_like_serializer.rb`
- `career_hub_event_review_serializer.rb`
- `career_hub_category_serializer.rb`

**참조 데이터 (3개)**
- `country_serializer.rb`
- `job_category_serializer.rb`
- `job_serializer.rb`

**기타 (5개)**
- `featured_profile_serializer.rb`
- `recommendation_notification_history_serializer.rb`
- `email_template_serializer.rb`
- `event_notification_schedule_serializer.rb`
- `application_context_reference_serializer.rb`
- `highlight_reference_serializer.rb`
- `practical_strength_reference_serializer.rb`

**인증 서비스 (auth/, 3개)**
- `auth/user_serializer.rb`
- `auth/workspace_serializer.rb`
- `auth/user_consent_serializer.rb`

#### 기본 시리얼라이저 구조
```ruby
class ResourceSerializer < ApplicationSerializer
  # 노출할 속성
  attributes :id, :name, :status, :created_at

  # 관계 (include 파라미터로 포함)
  belongs_to :user
  has_many :items
end
```

#### 관계명 = 파일명 규칙 (필수)
```ruby
# Good - 파일명 기준, 모델과 일치
class CareerHubCommunityEventSerializer < ApplicationSerializer
  belongs_to :career_hub_community, id_method_name: :community_id
  has_many :career_hub_community_event_participants
end

# Bad - 축약 이름 (모델과 불일치)
class CareerHubCommunityEventSerializer < ApplicationSerializer
  belongs_to :community  # 모델에 :community association이 없으면 에러
  has_many :event_participants  # event_participant_ids 메서드가 없으면 에러
end
```

#### id_method_name 규칙
```ruby
# DB 컬럼: community_id, 관계명: career_hub_community
# Rails 기본: career_hub_community_id (존재하지 않음)
# → id_method_name 필수
belongs_to :career_hub_community, id_method_name: :community_id

# DB 컬럼: category_id, 관계명: blog_category
belongs_to :blog_category, id_method_name: :category_id

# DB 컬럼: job_category_id, 관계명: job_category
# → #{관계명}_id == job_category_id == DB 컬럼 → id_method_name 불필요
belongs_to :job_category
```

#### 자기 참조 관계 (예외)
```ruby
# 자기 참조는 의미 기반 이름 유지
class CareerHubCommunityFeedSerializer < ApplicationSerializer
  belongs_to :parent, serializer: :career_hub_community_feed
  has_many :replies  # 모델에서도 has_many :replies
end
```

#### 다른 시리얼라이저 지정
```ruby
# nationality 관계에 CountrySerializer 사용
belongs_to :nationality, serializer: :country
```

#### 커스텀 속성
```ruby
class ProfileSerializer < ApplicationSerializer
  attributes :id, :name, :created_at

  # 커스텀 속성 (블록)
  attribute :formatted_date do |object|
    object.created_at.strftime('%Y-%m-%d')
  end

  # 조건부 속성
  attribute :secret, if: proc { |record, params|
    params[:current_user]&.admin?
  }
end
```

#### JSONB/Array 필드
```ruby
# JSONB와 Array 필드는 그대로 직렬화됨
class ProfileSerializer < ApplicationSerializer
  attributes :skills, :employment_type, :work_type

  # JSON 응답:
  # "skills": ["TypeScript", "React"],
  # "employment_type": { "regular": { "fullTime": { "value": true } } },
  # "work_type": ["remote", "hybrid"]
end
```

#### Enum 직렬화
```ruby
# Rails enum은 자동으로 문자열로 직렬화
# 모델: enum :job_seeking_status, { actively_seeking: 0, open_to_offers: 1 }

class ProfileSerializer < ApplicationSerializer
  attributes :job_seeking_status

  # JSON 응답:
  # "job_seeking_status": "actively_seeking"
end
```

#### 외부 서비스 관계 처리
```ruby
class ProfileSerializer < ApplicationSerializer
  attributes :id, :user_id, :name

  # belongs_to :user - User는 외부 인증 서비스에서 관리
  # user_id만 attributes로 노출
  belongs_to :job_category
  has_many :profile_experiences
end
```

#### JSON:API 응답 예시
```json
{
  "data": {
    "id": "1",
    "type": "profile",
    "attributes": {
      "user_id": "uuid-123",
      "name": "홍길동",
      "skills": ["TypeScript", "React"],
      "job_seeking_status": "actively_seeking"
    },
    "relationships": {
      "job_category": {
        "data": { "id": "1", "type": "job_category" }
      },
      "profile_experiences": {
        "data": [
          { "id": "1", "type": "profile_experience" },
          { "id": "2", "type": "profile_experience" }
        ]
      }
    }
  },
  "included": [
    {
      "id": "1",
      "type": "job_category",
      "attributes": { "name": "프론트엔드 개발" }
    },
    {
      "id": "1",
      "type": "profile_experience",
      "attributes": { "company_name": "회사명", "position": "시니어 개발자" }
    }
  ]
}
```

#### 컨트롤러에서 기본 include 설정
```ruby
# 컨트롤러
class ProfilesController < ApiController
  include CrudActions

  def jsonapi_include
    [:profile_experiences, :job_category]
  end
end

# ?include 파라미터 없이도 자동 포함됨
# GET /api/v1/profiles → profile_experiences, job_category 자동 로드
```

#### N+1 방지
```ruby
# 시리얼라이저에서 관계 정의
class PostSerializer < ApplicationSerializer
  belongs_to :user
  has_many :comments
end

# 컨트롤러에서 자동 처리
# GET /posts?include=user,comments
# CrudActions에서 자동으로 includes(:user, :comments) 적용
```

## Dependencies

### Internal
- `ApplicationSerializer` - 베이스 시리얼라이저
- `app/models/` - 시리얼라이저가 직렬화하는 모델

### External
- `jsonapi-serializer` gem - JSON:API 직렬화
- `jsonapi.rb` gem - JSON:API 렌더링 (컨트롤러에서 사용)

<!-- MANUAL: -->
