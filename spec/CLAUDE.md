# Specs (Tests)

RSpec + **rswag** 기반 API 테스트. OpenAPI 문서 자동 생성.

## 테스트 네이밍 컨벤션

**"~할 때, ~된다"** 형식으로 통일:

```ruby
# Good
response '200', '유효한 데이터로 로그인할 때, 로그인된다'
response '400', '비밀번호가 틀릴 때, BadRequest가 반환된다'
response '404', '존재하지 않는 리소스를 조회할 때, 404가 반환된다'

# Bad
response '200', '성공'
response '400', '실패'
response '404', '리소스 없음'
```

## 구조

```
spec/
├── rails_helper.rb           # RSpec 설정
├── swagger_helper.rb         # rswag 설정 및 헬퍼
├── factories/                # FactoryBot 팩토리
│   └── users.rb
├── requests/                 # Request specs (rswag)
│   └── api/v1/
│       ├── sign_controller/
│       │   ├── up_spec.rb
│       │   ├── in_spec.rb
│       │   └── out_spec.rb
│       └── users_controller/
│           └── index_spec.rb
└── support/                  # 헬퍼 및 설정
```

## 테스트 실행

```bash
# 전체 테스트
bundle exec rspec

# 특정 파일
bundle exec rspec spec/requests/api/v1/sign_controller/in_spec.rb

# Swagger 문서 생성
bundle exec rake rswag:specs:swaggerize
```

## rswag Request Spec 패턴

```ruby
require 'swagger_helper'

describe 'Resources API', type: :request do
  path '/api/v1/resources' do
    get '리소스 목록 조회' do
      tags 'Resources'
      produces 'application/json'
      parameter name: :include, in: :query, type: :string, required: false

      response '200', '리소스 목록을 조회할 때, 목록이 반환된다' do
        run_test!
      end
    end

    post '리소스 생성' do
      tags 'Resources'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :resource, in: :body, schema: jsonapi_schema({
        properties: {
          name: { type: :string },
          status: { type: :integer }
        },
        required: ['name']
      })

      response '200', '유효한 데이터로 생성할 때, 리소스가 생성된다' do
        let(:resource) { jsonapi_body({ name: 'Test' }) }
        run_test!
      end

      response '422', '이름이 비어있을 때, 검증 에러가 반환된다' do
        let(:resource) { jsonapi_body({ name: '' }) }
        run_test!
      end
    end
  end

  path '/api/v1/resources/{id}' do
    parameter name: :id, in: :path, type: :string

    get '리소스 상세 조회' do
      tags 'Resources'
      produces 'application/json'

      response '200', '존재하는 리소스를 조회할 때, 리소스가 반환된다' do
        let(:id) { create(:resource).id }
        run_test!
      end

      response '404', '존재하지 않는 리소스를 조회할 때, 404가 반환된다' do
        let(:id) { 'invalid' }
        run_test!
      end
    end
  end
end
```

## swagger_helper 헬퍼

```ruby
# JSON:API 스키마 생성
jsonapi_schema({
  properties: {
    name: { type: :string }
  },
  required: ['name']
})

# JSON:API body 생성
jsonapi_body({ name: 'Test', status: 1 })
# => { data: { attributes: { name: 'Test', status: 1 } } }

# 에러 응답 검증
expect_response_to_raise_error(response, 'BadRequest')
```

## 인증이 필요한 테스트

```ruby
describe 'Protected API', type: :request do
  path '/api/v1/protected' do
    get '보호된 리소스' do
      tags 'Protected'
      produces 'application/json'
      security [Bearer: []]

      response '401', '인증 없이 접근할 때, 401이 반환된다' do
        run_test! do |response|
          expect_response_to_raise_error(response, 'Unauthorized')
        end
      end

      response '200', '인증된 사용자가 접근할 때, 리소스가 반환된다' do
        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        run_test!
      end
    end
  end
end
```

## FactoryBot

```ruby
# spec/factories/resources.rb
FactoryBot.define do
  factory :resource do
    sequence(:name) { |n| "Resource #{n}" }
    association :user
  end
end
```

## API 문서 확인

```bash
# 서버 실행 후
open http://localhost:3000/api-docs
```
