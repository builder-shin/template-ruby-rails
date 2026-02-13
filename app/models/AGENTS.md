<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Models (app/models/)

## Purpose
ActiveRecord 모델 레이어. 플랫폼의 모든 데이터 엔티티를 정의하며, 데이터베이스 스키마와 1:1 매핑됩니다. 총 46개의 모델이 포함되어 있으며, 프리랜서 프로필, 채용 공고, 블로그, 커리어 허브 커뮤니티 등의 도메인을 다룹니다.

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | 모델 패턴, Association 네이밍 규칙, Ransack 설정 가이드 |
| `application_record.rb` | 모든 모델의 베이스 클래스 (Ransack 전역 설정 포함) |
| `current.rb` | 현재 요청 컨텍스트 정보 저장 (Current.user 등) |
| `auth_user.rb` | 외부 인증 서비스의 사용자 정보 (AuthServiceClient 응답 매핑) |
| `profile.rb` | 프리랜서 프로필 (핵심 모델) |
| `job_post.rb` | 채용 공고 (핵심 모델) |
| `blog_post.rb` | 블로그 게시글 |
| `career_hub_community.rb` | 커리어 허브 커뮤니티 |
| `country.rb` | 국가 참조 데이터 |
| `job_category.rb` | 직무 카테고리 참조 데이터 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `auth/` | 외부 인증 서비스 모델 (Auth::User, Auth::Workspace, Auth::UserConsent) |
| `concerns/` | 모델 공통 로직 (현재 비어있음) |

## For AI Agents

### Working In This Directory
모델 작업 시:

1. **ApplicationRecord 상속**: 모든 모델은 `ApplicationRecord`를 상속
2. **Association 네이밍 규칙**: 관계명 = 파일명(테이블명) 기준 (시리얼라이저와 일치 필수)
3. **Rails 8 Enum 문법**: `enum :status, { draft: 0, published: 1 }` 형식 사용
4. **Ransack**: ApplicationRecord에서 전역 허용, 컨트롤러에서 필터 제어
5. **JSONB/Array 필드**: PostgreSQL의 JSONB, Array 타입 활용
6. **외부 서비스 연동**: user_id는 외부 인증 서비스 UUID (belongs_to 대신 validates만)

### Common Patterns

#### 모델 분류

**프로필 관련 (10개)**
- `profile.rb` - 프리랜서 프로필 (user_id, job_category_id, nationality_id 등)
- `profile_experience.rb` - 경력
- `profile_education.rb` - 학력
- `profile_freelance_experience.rb` - 프리랜서 경험
- `profile_project.rb` - 프로젝트
- `profile_language.rb` - 언어 능력
- `profile_link.rb` - 링크
- `profile_highlight.rb` - 하이라이트
- `profile_attachment.rb` - 첨부파일
- `profile_job.rb` - 직무 연결

**채용 공고 관련 (7개)**
- `job_post.rb` - 채용 공고
- `job_application.rb` - 지원
- `job_post_category.rb` - 공고 카테고리 연결
- `job_post_language.rb` - 공고 언어 요구사항
- `job_post_job.rb` - 공고 직무 연결
- `job_post_status_log.rb` - 공고 상태 로그
- `recruitment_request.rb` - 채용 요청

**블로그 관련 (5개)**
- `blog_post.rb` - 블로그 게시글
- `blog_category.rb` - 블로그 카테고리
- `blog_post_category.rb` - 게시글 카테고리 연결
- `blog_author_permission.rb` - 작성 권한
- `blog_view.rb` - 조회수

**커리어 허브 커뮤니티 (10개)**
- `career_hub_community.rb` - 커뮤니티
- `career_hub_community_feed.rb` - 커뮤니티 피드
- `career_hub_community_event.rb` - 커뮤니티 이벤트
- `career_hub_community_member.rb` - 커뮤니티 멤버
- `career_hub_community_leader.rb` - 커뮤니티 리더
- `career_hub_community_event_participant.rb` - 이벤트 참가자
- `career_hub_community_feed_like.rb` - 피드 좋아요
- `career_hub_event_review.rb` - 이벤트 리뷰
- `career_hub_category.rb` - 커리어 허브 카테고리

**참조 데이터 (3개)**
- `country.rb` - 국가
- `job_category.rb` - 직무 카테고리
- `job.rb` - 직무

**기타 (7개)**
- `featured_profile.rb` - 추천 프로필
- `recommendation_notification_history.rb` - 추천 알림 이력
- `email_template.rb` - 이메일 템플릿
- `event_notification_schedule.rb` - 이벤트 알림 스케줄
- `application_context_reference.rb` - 애플리케이션 컨텍스트 참조
- `highlight_reference.rb` - 하이라이트 참조
- `practical_strength_reference.rb` - 실무 강점 참조

**인증 서비스 (auth/ 네임스페이스, 4개)**
- `auth/base.rb` - 인증 모델 베이스
- `auth/user.rb` - 사용자
- `auth/workspace.rb` - 워크스페이스
- `auth/user_consent.rb` - 사용자 동의

#### 기본 모델 구조
```ruby
class Resource < ApplicationRecord
  # 관계
  belongs_to :user
  has_many :items, dependent: :destroy

  # Enum (Rails 8 문법)
  enum :status, { draft: 0, published: 1, archived: 2 }

  # 검증
  validates :name, presence: true
  validates :email, uniqueness: true
end
```

#### Association 네이밍 규칙 (필수)
```ruby
# Good - 파일명(테이블명) 기준
class CareerHubCommunityEvent < ApplicationRecord
  belongs_to :career_hub_community, foreign_key: :community_id, optional: true
  has_many :career_hub_community_event_participants, foreign_key: :event_id
end

# Bad - 축약 이름 (시리얼라이저와 불일치)
class CareerHubCommunityEvent < ApplicationRecord
  belongs_to :community, class_name: 'CareerHubCommunity', optional: true
  has_many :event_participants, class_name: 'CareerHubCommunityEventParticipant'
end
```

#### foreign_key가 필요한 경우
```ruby
# DB 컬럼: community_id
# Association 이름: career_hub_community
# Rails 추론 FK: career_hub_community_id (존재하지 않음)
# → foreign_key 명시 필수
belongs_to :career_hub_community, foreign_key: :community_id, optional: true
```

#### class_name 사용 예외 케이스
```ruby
# 1. 자기 참조
belongs_to :parent, class_name: 'CareerHubCategory', optional: true
has_many :children, class_name: 'CareerHubCategory', foreign_key: :parent_id

# 2. 역할 alias
belongs_to :career_hub_subcategory, class_name: 'CareerHubCategory', foreign_key: :subcategory_id

# 3. 다른 DB 네임스페이스
belongs_to :user, class_name: "Auth::User", foreign_key: "user_id"
```

#### Rails 8 Enum 문법
```ruby
# ✅ Rails 8 문법 (필수)
enum :status, { draft: 0, published: 1 }
enum :status, { draft: 0, published: 1 }, prefix: true  # status_draft?

# ❌ 기존 문법 (Rails 8에서 에러)
# enum status: { draft: 0 }  # 사용 금지
```

#### JSONB 필드
```ruby
# 스키마
# t.jsonb "employment_type", comment: "고용 형태"

# 모델에서 직접 접근
profile.employment_type  # => { "regular" => { "fullTime" => { "value" => true } } }

# 검증 없음 (자유 형식)
```

#### 배열 필드
```ruby
# 스키마
# t.text "skills", comment: "기술", array: true

# 모델에서 직접 접근
profile.skills  # => ["TypeScript", "React", "Node.js"]

# 배열 검증
validates :skills, presence: true
```

#### 외부 서비스 연동 (user_id)
```ruby
class Profile < ApplicationRecord
  # user_id는 외부 인증 서비스의 UUID
  # User 모델이 로컬에 없으므로 belongs_to 대신 foreign key만 사용
  validates :user_id, presence: true, uniqueness: true

  # 컨트롤러에서 user_info.id로 설정
end
```

#### Optional 관계
```ruby
belongs_to :job_category, optional: true
belongs_to :nationality, class_name: 'Country', foreign_key: 'nationality_id', optional: true
```

#### 복잡한 검증
```ruby
class Profile < ApplicationRecord
  validates :user_id, presence: true, uniqueness: true
  validates :email_public, inclusion: { in: [true, false] }
  validates :overall_completeness,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            }
  validates :name, length: { maximum: 100 }, allow_blank: true
end
```

#### Ransack 검색 (전역 허용)
```ruby
# ApplicationRecord에서 모든 컬럼/관계 허용
class ApplicationRecord < ActiveRecord::Base
  def self.ransackable_attributes(auth_object = nil)
    column_names + _ransackers.keys
  end

  def self.ransackable_associations(auth_object = nil)
    reflect_on_all_associations.map(&:name).map(&:to_s)
  end
end

# 필터 제어는 컨트롤러에서
def filter_attributes
  [:name, :status, :created_at]
end
```

## Dependencies

### Internal
- `ApplicationRecord` - 모든 모델의 베이스
- `auth/` - 외부 인증 서비스 모델
- `db/schema.rb` - 데이터베이스 스키마

### External
- ActiveRecord (Rails)
- PostgreSQL (JSONB, Array 타입)
- Ransack gem (검색 및 필터링)

<!-- MANUAL: -->
