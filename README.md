# Template Ruby Rails

Ruby on Rails 8 기반 JSON:API 백엔드 템플릿 프로젝트입니다.

인증(외부 Auth 서비스 연동), 공통 CRUD(`CrudActions`), JSON:API 직렬화, 페이지네이션·필터링,
Sidekiq, 이메일(SendGrid), ActiveStorage, 관측(lograge/Sentry), 레이트리밋(rack-attack) 등
**재사용 가능한 인프라**를 제공합니다. 도메인 코드로는 패턴을 보여주는 **Blog 예시 하나**만 포함합니다 —
새 프로젝트를 시작할 때 이 예시를 교체하세요. 자세한 내용은 [템플릿 사용법](#템플릿-사용법)을 참고하세요.

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
# schema.rb 로부터 스키마 적재 (권장 — db:create 후 db:schema:load)
bin/rails db:prepare
```

> 스키마의 정식 소스는 `db/schema.rb` 이며 `db:schema:load`(= `db:prepare`/`db:setup`)로 적재합니다.

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
├── Gemfile                 # Ruby 의존성
├── Dockerfile              # Docker 빌드 설정
└── .env.example            # 환경 변수 템플릿
```

## 환경 변수

환경 변수 목록은 `.env.example` 파일을 참고하세요.

## 템플릿 사용법

이 저장소는 **인프라 + 예시 도메인(Blog)** 으로 구성됩니다.

### 인프라 (그대로 사용)

- `app/controllers/api_controller.rb`, `app/controllers/concerns/crud_actions.rb` — 인증 + 공통 CRUD
- `app/services/auth_service_client.rb` — 외부 Auth 서비스 연동(쿠키 세션 검증, 서킷 브레이커)
- `app/services/notification_service.rb` + `sendgrid_email_service.rb` + `EmailTemplate` — 템플릿 키 기반 이메일 발송
- `app/jobs/process_image_variants_job.rb`, ActiveStorage 설정 — 파일 업로드/이미지 변형
- `config/initializers/*` — CORS, CSP, rack-attack, lograge, Sentry, Sidekiq 등

### 예시 도메인 (교체 대상)

`blog_*` 리소스(모델·컨트롤러·시리얼라이저·라우트·`db/schema.rb` 의 `blog_*` 테이블)는
`CrudActions` 사용법(필터·페이지네이션·include·enum, 소유권 검증, 계층형 카테고리, through 조인)을
보여주기 위한 **예시**입니다.

### 새 프로젝트로 시작하기

1. `blog_*` 리소스를 자신의 도메인으로 교체(또는 삭제)합니다.
2. `db/schema.rb` 와 `db/migrate/` 를 자신의 스키마로 교체합니다.
3. `config/routes.rb` 의 라우트를 수정합니다.
4. `EmailTemplate` 기반 이메일이 필요 없다면 관련 파일과 라우트를 제거합니다.

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
bundle exec rspec spec/models/blog_post_spec.rb

# 특정 테스트
bundle exec rspec spec/models/blog_post_spec.rb:21
```

## 주의사항

- 이 템플릿은 기본적인 설정을 포함하고 있으며, 실제 사용 시에는 프로젝트에 맞게 설정을 수정해야 합니다.
- 환경 변수 설정은 `.env` 파일을 사용하여 관리합니다.
