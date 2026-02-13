# Template Ruby Rails

Rails 8 기반 JSON:API 백엔드 템플릿 프로젝트.

## 기술 스택

- **Rails 8.1** - 웹 프레임워크
- **PostgreSQL** - 데이터베이스
- **jsonapi.rb + jsonapi-serializer** - JSON:API 스펙 준수
- **Sidekiq** - 백그라운드 작업
- **RSpec** - 테스트

## 프로젝트 구조

```
app/
├── controllers/
│   ├── api_controller.rb      # API 베이스 컨트롤러
│   ├── concerns/
│   │   └── crud_actions.rb    # CRUD 공통 로직
│   └── api/v1/                # API v1 엔드포인트
├── models/                    # ActiveRecord 모델
├── serializers/               # JSON:API 시리얼라이저
└── jobs/                      # Sidekiq 작업
```

## 주요 패턴

### 컨트롤러
- `ApiController` 상속하여 API 컨트롤러 생성
- `CrudActions` concern은 `ApiController`에 이미 포함되어 있음 (개별 컨트롤러에서 include 불필요)
- `before_action :user_check!`로 인증 필수 설정

### JSON:API
- `?include=relation`으로 관계 포함 (자동 eager loading)
- `?filter[attr]=value`로 필터링
- `?page[number]=1&page[size]=10`으로 페이지네이션

### 인증

쿠키 기반 인증 (외부 Auth 서비스 연동):

```ruby
# ApiController에서 자동 처리
# request.cookies['session_web']에서 세션 토큰 추출
# AuthServiceClient로 토큰 검증 후 Current.user 설정

# 인증 필수 설정
before_action :user_check!

# 회원 유형별 체크
before_action :personal_check!    # 개인회원만
before_action :enterprise_check!  # 기업회원만
```

**클라이언트 요청 시**: `credentials: 'include'`로 쿠키 자동 포함

### 환경 변수

| 변수 | 설명 |
|------|------|
| `AUTH_SERVICE_URL` | 인증 서비스 URL |
| `DATABASE_URL` | PostgreSQL 연결 URL |
| `SECRET_KEY_BASE` | Rails secret key |

## 명령어

```bash
# 서버 실행
bin/rails server

# 테스트
bundle exec rspec

# 마이그레이션
bin/rails db:migrate

# 콘솔
bin/rails console
```

## 환경 설정

- `.env` - 환경 변수 (gitignore됨)
- `config/database.yml` - DB 설정
- `config/application.yml` - 앱 설정

## 코드 컨벤션

### Flat 디렉토리 구조
- **깊은 중첩 금지**: 디렉토리는 최대 2-3단계까지만
- 불필요한 하위 폴더 생성하지 않기
- 관련 파일들은 같은 레벨에 배치

```
# Good - flat 구조
app/controllers/api/v1/users_controller.rb
app/controllers/api/v1/posts_controller.rb

# Bad - 과도한 중첩
app/controllers/api/v1/users/profile/settings_controller.rb
```

### Association / Serializer 관계명 규칙
- **모델 association 이름 = 시리얼라이저 relationship 이름 = 파일명(테이블명) 기준**
- `class_name`은 자기 참조, 역할 alias, 다른 네임스페이스 등 추론 불가 시에만 사용
- FK 컬럼명이 `#{관계명}_id`와 다르면 모델에 `foreign_key:`, 시리얼라이저에 `id_method_name:` 명시
- 상세 규칙은 `app/models/CLAUDE.md`와 `app/serializers/CLAUDE.md` 참조

### Guard Clause 패턴 (필수)
- **if/elsif/else 패턴 금지** — guard clause (early return/raise) 사용
- 조건 불일치 시 `raise` 또는 `return` 으로 먼저 빠져나가고, 정상 흐름을 아래에 배치
- `case/when/else`는 허용 (switch-case 패턴)
- 상세 규칙 및 예시는 `app/controllers/CLAUDE.md` 참조

### 기타 컨벤션
- 한국어 에러 메시지 사용
- Serializer에서 `belongs_to`/`has_many` 사용 시 컨트롤러에서 `includes` 적용
- 새 API 엔드포인트는 `api/v1/` 네임스페이스 아래 생성
