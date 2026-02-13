# Models

## 현재 모델

44개 모델이 정의되어 있습니다.

## 새 모델 생성 패턴

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

## Ransack 검색

`ApplicationRecord`에서 모든 컬럼과 관계를 전역 허용합니다.
실제 필터 제어는 **컨트롤러의 `filter_attributes`**에서 담당합니다.

```ruby
# 컨트롤러에서 filter_attributes 정의
def filter_attributes
  [:name, :status]  # ?filter[name]=value 형식으로 필터링
end
```

개별 모델에서 `ransackable_attributes`나 `ransackable_associations`를 정의할 필요가 없습니다.

## Enum 문법 (Rails 8)

```ruby
# Rails 8 문법 (필수)
enum :status, { draft: 0, published: 1 }
enum :status, { draft: 0, published: 1 }, prefix: true  # status_draft?

# 기존 문법 (Rails 8에서 에러 발생)
# enum status: { draft: 0 }  # 사용 금지
```

## 마이그레이션 위치

`db/migrate/` 디렉토리에 위치.

## JSONB 필드

PostgreSQL JSONB 타입으로 복잡한 구조 저장:

```ruby
# 스키마
t.jsonb "employment_type", comment: "고용 형태"

# 모델에서 직접 접근
profile.employment_type  # => { "regular" => { "fullTime" => { "value" => true } } }

# 컨트롤러 strong params
def model_params_options
  { only: [:employment_type] }  # JSONB는 그대로 전달
end
```

## 배열 필드

PostgreSQL Array 타입:

```ruby
# 스키마
t.text "skills", comment: "기술", array: true
t.text "work_type", comment: "근무 형태", array: true

# 모델에서 직접 접근
profile.skills  # => ["TypeScript", "React", "Node.js"]

# 컨트롤러 strong params
def model_params_options
  { only: [:skills, :work_type] }  # 배열도 그대로 전달됨
end
```

## 외부 서비스 연동

외부 인증 서비스의 사용자 ID 참조:

```ruby
class Profile < ApplicationRecord
  # user_id는 외부 인증 서비스의 UUID
  # User 모델이 로컬에 없으므로 belongs_to 대신 foreign key만 사용
  validates :user_id, presence: true, uniqueness: true

  # 컨트롤러에서 현재 사용자 ID 설정
  # def create_after_init
  #   @model.user_id = user_info.id  # user_info는 AuthUser 객체
  # end
end
```

## Association 네이밍 규칙 (필수)

**Association 이름은 반드시 파일명(=테이블명) 기준으로 작성합니다.**

이 규칙은 `CrudActions#includes_for_active_record`가 시리얼라이저 관계명을 그대로 AR `includes()`에 전달하고, jsonapi-serializer가 `has_many`에서 `#{관계명}_ids` 메서드를 호출하기 때문에 **모델↔시리얼라이저 관계명이 반드시 일치**해야 하기 때문입니다.

### 원칙

```ruby
# Good - 파일명/테이블명 기준
belongs_to :career_hub_community, foreign_key: :community_id, optional: true
has_many :career_hub_community_events, foreign_key: :community_id, dependent: :destroy

# Bad - 축약된 이름 사용 (시리얼라이저와 불일치 발생)
belongs_to :community, class_name: 'CareerHubCommunity', optional: true
has_many :community_events, class_name: 'CareerHubCommunityEvent', dependent: :destroy
```

### foreign_key가 필요한 경우

Association 이름을 파일명 기준으로 바꾸면 Rails가 추론하는 FK 컬럼명이 실제 DB 컬럼과 달라질 수 있습니다. 이때 `foreign_key:`를 명시합니다.

```ruby
# CareerHubCommunityEvent 모델
# DB 컬럼: community_id
# Rails 추론: career_hub_community_id (존재하지 않음)
# → foreign_key 필수
belongs_to :career_hub_community, foreign_key: :community_id, optional: true

# has_many도 동일
# CareerHubCommunity 모델에서 CareerHubCommunityEvent를 참조할 때
# Rails 추론 FK: career_hub_community_id, 실제 FK: community_id
has_many :career_hub_community_events, foreign_key: :community_id, dependent: :destroy
```

### class_name을 사용해야 하는 예외 케이스

`class_name`은 association 이름만으로 모델 클래스를 추론할 수 없는 경우에만 사용합니다:

```ruby
# 1. 자기 참조 (Self-referential)
belongs_to :parent, class_name: 'CareerHubCategory', optional: true
has_many :children, class_name: 'CareerHubCategory', foreign_key: :parent_id
has_many :replies, class_name: 'CareerHubCommunityFeed', foreign_key: :parent_id

# 2. 같은 모델을 다른 이름으로 참조 (역할 alias)
belongs_to :career_hub_subcategory, class_name: 'CareerHubCategory', foreign_key: :subcategory_id
belongs_to :nationality, class_name: 'Country', foreign_key: 'nationality_id'
belongs_to :sender, class_name: 'User', foreign_key: 'sender_id'

# 3. 같은 모델 + 다른 FK (역방향 alias)
has_many :communities_as_category, class_name: 'CareerHubCommunity', foreign_key: :category_id
has_many :communities_as_subcategory, class_name: 'CareerHubCommunity', foreign_key: :subcategory_id

# 4. 다른 DB 네임스페이스 모델
belongs_to :user, class_name: "Auth::User", foreign_key: "user_id"
```

### 시리얼라이저와의 일치 체크리스트

새 모델/관계 추가 시 반드시 확인:

1. 모델 association 이름 == 시리얼라이저 relationship 이름
2. 시리얼라이저 `belongs_to`에 `id_method_name`이 필요한지 확인 (DB FK 컬럼명 ≠ `#{관계명}_id`일 때)
3. 컨트롤러 `allowed_includes`에 같은 이름으로 추가

## Optional 관계

```ruby
# optional: true로 nil 허용
belongs_to :job_category, optional: true
belongs_to :nationality, class_name: 'Country', foreign_key: 'nationality_id', optional: true
```

## 복잡한 검증 예시

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
