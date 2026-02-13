# Serializers

JSON:API 스펙 준수 시리얼라이저. `jsonapi-serializer` gem 사용.

## 구조

```
serializers/
├── application_serializer.rb  # 베이스 시리얼라이저
├── user_serializer.rb
└── post_serializer.rb
```

## 새 시리얼라이저 생성 패턴

```ruby
class ResourceSerializer < ApplicationSerializer
  # 노출할 속성
  attributes :id, :name, :status, :created_at

  # 관계 (include 파라미터로 포함)
  belongs_to :user
  has_many :items

  # 커스텀 속성
  attribute :formatted_date do |object|
    object.created_at.strftime('%Y-%m-%d')
  end

  # 조건부 속성
  attribute :secret, if: proc { |record, params|
    params[:current_user]&.admin?
  }
end
```

## 관계명 = 파일명(테이블명) 규칙 (필수)

**시리얼라이저의 관계명은 반드시 대상 모델의 파일명(=테이블명) 기준으로 작성합니다.**
그리고 **모델의 association 이름과 반드시 일치**해야 합니다.

이유:
- `CrudActions#includes_for_active_record`가 시리얼라이저 관계명을 AR `includes()`에 그대로 전달
- `has_many`는 jsonapi-serializer가 `#{관계명}_ids` 메서드를 모델에서 호출
- 이름 불일치 시 `ActiveRecord::AssociationNotFoundError` 또는 `NoMethodError` 발생

```ruby
# Good - 파일명 기준, 모델과 일치
class CareerHubCommunityEventSerializer < ApplicationSerializer
  belongs_to :career_hub_community, id_method_name: :community_id
  has_many :career_hub_community_event_participants
end

# Bad - 축약 이름 (모델과 불일치 발생)
class CareerHubCommunityEventSerializer < ApplicationSerializer
  belongs_to :community  # 모델에 :community association이 없으면 에러
  has_many :event_participants  # event_participant_ids 메서드가 없으면 에러
end
```

### id_method_name 규칙

`belongs_to`에서 DB FK 컬럼명이 `#{관계명}_id`와 다를 때 `id_method_name`을 명시합니다:

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

### 자기 참조 관계는 예외

자기 참조(parent, root, children, replies)는 의미 기반 이름을 유지합니다:

```ruby
belongs_to :parent, serializer: :career_hub_community_feed
has_many :replies  # 모델에서도 has_many :replies
```

## 관계와 N+1 방지

시리얼라이저에서 `belongs_to`/`has_many` 정의 시, 컨트롤러에서 반드시 eager loading:

```ruby
# 시리얼라이저
class PostSerializer < ApplicationSerializer
  belongs_to :user
end

# 컨트롤러 - 자동 처리됨
# GET /posts?include=user 요청 시 CrudActions에서 자동으로 includes(:user) 적용
```

## JSON:API 응답 형식

```json
{
  "data": {
    "id": "1",
    "type": "post",
    "attributes": {
      "title": "제목",
      "content": "내용"
    },
    "relationships": {
      "user": {
        "data": { "id": "1", "type": "user" }
      }
    }
  },
  "included": [
    {
      "id": "1",
      "type": "user",
      "attributes": { "name": "사용자" }
    }
  ]
}
```

## 외부 서비스 관계 처리

외부 인증 서비스의 User는 로컬 모델이 없으므로 주석으로 표시:

```ruby
class ProfileSerializer < ApplicationSerializer
  attributes :id, :user_id, :name, :email_public, :profile_image,
             :job_seeking_status, :start_work, :skills, :employment_type,
             :work_type, :created_at, :updated_at

  # belongs_to :user - User는 외부 인증 서비스에서 관리
  belongs_to :job_category
  belongs_to :nationality, serializer: :country

  has_many :profile_experiences
  has_many :profile_educations
  # ...
end
```

## 다른 시리얼라이저 지정

관계에서 다른 시리얼라이저 사용:

```ruby
# nationality 관계에 CountrySerializer 사용
belongs_to :nationality, serializer: :country
```

## Enum 직렬화

Rails enum은 자동으로 문자열로 직렬화됨:

```ruby
# 모델
enum :job_seeking_status, { actively_seeking: 0, open_to_offers: 1 }

# JSON 응답
{
  "attributes": {
    "job_seeking_status": "actively_seeking"  # 문자열로 반환
  }
}
```

## JSONB/Array 필드

JSONB와 Array 필드는 그대로 직렬화됨:

```ruby
# 시리얼라이저
attributes :skills, :employment_type, :work_type

# JSON 응답
{
  "attributes": {
    "skills": ["TypeScript", "React"],
    "employment_type": { "regular": { "fullTime": { "value": true } } },
    "work_type": ["remote", "hybrid"]
  }
}
```

## jsonapi_include 설정

컨트롤러에서 기본 include할 관계 지정:

```ruby
# 컨트롤러
def jsonapi_include
  [:profile_experiences, :job_category]
end

# ?include 파라미터 없이도 자동 포함됨
# GET /api/v1/profiles → profile_experiences, job_category 자동 로드
```
