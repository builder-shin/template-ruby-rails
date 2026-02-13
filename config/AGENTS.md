<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Config (config/)

## Purpose
Rails 애플리케이션 설정 파일 디렉토리. 라우팅, 데이터베이스 연결, 환경별 설정, 초기화 스크립트 등을 포함합니다.

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | Config 가이드, 환경 변수, 라우팅 패턴 |
| `routes.rb` | API 라우팅 정의 (namespace :api, :v1) |
| `database.yml` | PostgreSQL 연결 설정 (환경 변수 사용) |
| `application.rb` | Rails 앱 전역 설정 |
| `application.yml` | 앱별 설정 (현재 비어있음) |
| `boot.rb` | 부트스트랩 설정 |
| `environment.rb` | 환경 로드 |
| `puma.rb` | Puma 웹 서버 설정 |
| `storage.yml` | Active Storage 설정 (S3 등) |
| `secrets.yml` | 비밀 키 설정 |
| `cable.yml` | ActionCable 설정 |
| `credentials.yml.enc` | 암호화된 인증 정보 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `environments/` | 환경별 설정 (development.rb, test.rb, production.rb) |
| `initializers/` | 초기화 스크립트 (CORS, JSON:API, Sidekiq 등) |
| `locales/` | 다국어 지원 (한국어 기본) |

## For AI Agents

### Working In This Directory
Config 작업 시:

1. **환경 변수 우선**: 민감 정보는 `.env` 파일에서 관리 (gitignore됨)
2. **라우팅**: `routes.rb`에서 `namespace :api, :v1` 블록 내에 리소스 추가
3. **Initializers**: 알파벳 순으로 로드됨, 순서 의존성 주의
4. **CORS 설정**: `initializers/cors.rb`에서 프론트엔드 origin 허용
5. **JSON:API**: `initializers/jsonapi.rb`에서 JSON:API 전역 설정

### Common Patterns

#### 라우팅 추가 (routes.rb)
```ruby
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # CRUD 전체
      resources :profiles
      resources :job_posts

      # 읽기 전용
      resources :countries, only: [:index, :show]

      # 커스텀 액션
      resources :profiles do
        member do
          post :complete
        end
      end
    end
  end
end
```

#### 데이터베이스 설정 (database.yml)
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: template_development
  host: <%= ENV['DEV_DATABASE_HOST'] %>
  username: <%= ENV['DEV_DATABASE_USERNAME'] %>
  password: <%= ENV['DEV_DATABASE_PASSWORD'] %>

production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
```

#### 환경 변수 (.env)
```env
# 인증 서비스
AUTH_SERVICE_URL=http://localhost:4000

# 데이터베이스
DATABASE_URL=postgres://user:pass@localhost:5432/template_development
DEV_DATABASE_HOST=localhost
DEV_DATABASE_USERNAME=postgres
DEV_DATABASE_PASSWORD=password

# Rails
SECRET_KEY_BASE=...
RAILS_ENV=development

# 프론트엔드
FRONTEND_URL=http://localhost:3000
```

#### 필수 환경 변수
| 변수 | 설명 | 예시 |
|------|------|------|
| `AUTH_SERVICE_URL` | 외부 인증 서비스 URL | `http://localhost:4000` |
| `DATABASE_URL` | PostgreSQL 연결 | `postgres://localhost/template_development` |
| `SECRET_KEY_BASE` | Rails secret key | 64자 이상 랜덤 문자열 |
| `FRONTEND_URL` | Next.js 프론트엔드 URL | `http://localhost:3000` |

#### CORS 설정 (initializers/cors.rb)
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['FRONTEND_URL'] || 'http://localhost:3000'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

#### JSON:API 설정 (initializers/jsonapi.rb)
```ruby
JSONAPI.configure do |config|
  config.json_key_format = :underscored_key
  config.route_format = :dasherized_route
end
```

#### 환경별 설정
**development.rb** - 개발 환경
```ruby
Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.active_storage.service = :local
end
```

**production.rb** - 프로덕션 환경
```ruby
Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.active_storage.service = :amazon
  config.force_ssl = true
end
```

#### Initializer 추가
```ruby
# config/initializers/my_config.rb
Rails.application.config.my_setting = ENV['MY_SETTING']

# 알파벳 순 로드: cors.rb → jsonapi.rb → my_config.rb
# 순서 의존성 있으면 파일명 앞에 숫자 추가 (00_first.rb)
```

#### Active Storage 설정 (storage.yml)
```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['AWS_REGION'] %>
  bucket: <%= ENV['AWS_BUCKET'] %>
```

## Dependencies

### Internal
- `app/` - 설정이 적용되는 애플리케이션 코드
- `.env` - 환경 변수 (루트 디렉토리)

### External
- `dotenv-rails` gem - 환경 변수 로드
- `rack-cors` gem - CORS 설정
- `jsonapi.rb` gem - JSON:API 설정
- `aws-sdk-s3` gem - S3 연동 (Active Storage)

<!-- MANUAL: -->
