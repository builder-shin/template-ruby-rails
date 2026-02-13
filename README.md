# Template Ruby Rails

Ruby on Rails 8 기반 JSON:API 백엔드 템플릿 프로젝트입니다.

## 기술 스택

- **Ruby** 3.4.8
- **Rails** 8.1.2
- **PostgreSQL** - 데이터베이스
- **Redis** - Sidekiq 백그라운드 작업
- **Sidekiq** - 백그라운드 작업 처리
- **jsonapi.rb + jsonapi-serializer** - JSON:API 스펙 준수

## 필요 환경

- Ruby 3.4.8
- PostgreSQL
- Redis (Sidekiq용)

## 설정 및 실행

### 1. 의존성 설치

```bash
bundle install
```

### 2. 환경 변수 설정

```bash
cp .env.example .env
# .env 파일을 열어 값을 채워넣으세요
```

### 3. 데이터베이스 설정

```bash
bin/rails db:create
bin/rails db:migrate
```

### 4. 서버 실행

```bash
bin/rails server
# http://localhost:4000 에서 실행됩니다
```

## 개발 명령어

| 명령어 | 설명 |
|--------|------|
| `bin/rails server` | 개발 서버 실행 (포트 4000) |
| `bin/rails console` | Rails 콘솔 |
| `bundle exec rspec` | 테스트 실행 |
| `bundle exec rubocop` | 코드 린트 |
| `bin/rails db:migrate` | 마이그레이션 실행 |
| `bin/rails db:rollback` | 마이그레이션 롤백 |
| `bin/rails db:reset` | 데이터베이스 초기화 |

## Docker

### 빌드

```bash
docker build -t template-ruby-rails .
```

### 실행

```bash
docker run -p 4000:4000 --env-file .env template-ruby-rails
```

## 디렉토리 구조

```
├── app/
│   ├── controllers/        # API 컨트롤러
│   │   ├── api_controller.rb      # API 베이스 컨트롤러
│   │   ├── concerns/
│   │   │   └── crud_actions.rb    # CRUD 공통 로직
│   │   └── api/v1/                # API v1 엔드포인트
│   ├── models/             # ActiveRecord 모델
│   ├── serializers/        # JSON:API 시리얼라이저
│   ├── services/           # 서비스 객체
│   └── jobs/               # Sidekiq 백그라운드 작업
├── config/                 # Rails 설정
├── db/
│   ├── migrate/            # 마이그레이션 파일
│   └── schema.rb           # 데이터베이스 스키마
├── spec/                   # RSpec 테스트
├── docs/                   # 프로젝트 문서
├── scripts/                # 유틸리티 스크립트
├── Gemfile                 # Ruby 의존성
├── Dockerfile              # Docker 빌드 설정
└── .env.example            # 환경 변수 템플릿
```

## 환경 변수

환경 변수 목록은 `.env.example` 파일을 참고하세요.

## 주요 패턴

### JSON:API

- `?include=relation` - 관계 포함 (자동 eager loading)
- `?filter[attr]=value` - 필터링
- `?page[number]=1&page[size]=10` - 페이지네이션

### 인증

쿠키 기반 인증으로 외부 Auth 서비스와 연동합니다.

```ruby
before_action :user_check!        # 인증 필수
before_action :personal_check!    # 개인회원만
before_action :enterprise_check!  # 기업회원만
```

## 테스트

```bash
# 전체 테스트
bundle exec rspec

# 특정 파일 테스트
bundle exec rspec spec/models/profile_spec.rb

# 특정 테스트
bundle exec rspec spec/models/profile_spec.rb:10
```

## 주의사항

- 이 템플릿은 기본적인 설정을 포함하고 있으며, 실제 사용 시에는 프로젝트에 맞게 설정을 수정해야 합니다.
- 환경 변수 설정은 `.env` 파일을 사용하여 관리합니다.
