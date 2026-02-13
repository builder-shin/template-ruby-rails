# PRD 데이터베이스 마이그레이션 가이드

**작성일**: 2026-02-04
**최종 검증일**: 2026-02-04
**대상**: TypeORM/NestJS → Rails 컨벤션 변환
**환경**: Production

---

## 개요

기존 TypeORM/NestJS로 관리되던 PostgreSQL 데이터베이스를 Ruby on Rails 컨벤션에 맞게 마이그레이션하는 절차입니다.

### 변환 내용

| 항목 | 변환 전 (TypeORM) | 변환 후 (Rails) |
|------|------------------|-----------------|
| 컬럼명 | camelCase | snake_case |
| Enum 타입 | PostgreSQL enum | integer |
| 타임스탬프 | createdAt, updatedAt | created_at, updated_at |
| Boolean 접두사 | isActive, isEmailPublic | active, email_public |

### 스크립트 특징

- **멱등성 보장**: 모든 스크립트는 이미 변환된 컬럼을 스킵하므로 **실패 시 재실행 가능**
- **트랜잭션 사용**: `BEGIN/COMMIT`으로 감싸서 실패 시 자동 롤백
- **Orphan 컬럼 처리**: 이전 실패한 변환에서 남은 `_int` suffix 컬럼 자동 정리

---

## 사전 준비

### 1. 필수 도구 확인

```bash
# 설치된 PostgreSQL 17 버전 확인
ls /opt/homebrew/Cellar/postgresql@17/

# 출력 예시: 17.6_1  17.7_1
# 가장 최신 버전 사용 (예: 17.7_1)

# 버전 확인
/opt/homebrew/Cellar/postgresql@17/17.7_1/bin/pg_dump --version
/opt/homebrew/Cellar/postgresql@17/17.7_1/bin/psql --version

# 버전 불일치 시 설치
brew install postgresql@17
```

**주의**: 위 경로의 버전 번호(`17.7_1`)는 설치된 버전에 따라 다를 수 있습니다. `ls` 명령으로 확인 후 사용하세요.

### 2. 환경 변수 준비

다음 정보를 확인하세요:

```bash
# Source DB (기존 PRD - 읽기만)
export PRD_SOURCE_HOST=<기존_PRD_DB_호스트>
export PRD_SOURCE_PORT=<기존_PRD_DB_포트>
export PRD_SOURCE_USER=postgres
export PRD_SOURCE_PASSWORD=<기존_PRD_DB_비밀번호>
export PRD_SOURCE_DB=railway

# Target DB (새 PRD - Rails용)
export PRD_TARGET_HOST=<새_PRD_DB_호스트>
export PRD_TARGET_PORT=<새_PRD_DB_포트>
export PRD_TARGET_USER=postgres
export PRD_TARGET_PASSWORD=<새_PRD_DB_비밀번호>
export PRD_TARGET_DB=railway

# PostgreSQL 클라이언트 경로 (설치된 버전에 맞게 수정)
export PG_BIN=/opt/homebrew/Cellar/postgresql@17/17.7_1/bin
```

### 3. 새 PRD 데이터베이스 생성

Railway 또는 사용 중인 클라우드 서비스에서 새 PostgreSQL 인스턴스를 생성하세요.

---

## 마이그레이션 절차

### Step 1: 데이터 백업 (Source DB)

```bash
# 타임스탬프 생성
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 백업 디렉토리 생성
mkdir -p tmp/db_backups

# pg_dump 실행 (schema_migrations 제외 - 중요!)
PGPASSWORD=$PRD_SOURCE_PASSWORD $PG_BIN/pg_dump \
  -h $PRD_SOURCE_HOST \
  -p $PRD_SOURCE_PORT \
  -U $PRD_SOURCE_USER \
  -d $PRD_SOURCE_DB \
  --no-owner \
  --no-acl \
  --clean \
  --if-exists \
  --exclude-table=schema_migrations \
  --exclude-table=ar_internal_metadata \
  -f tmp/db_backups/backup_prd_${TIMESTAMP}.sql

echo "백업 완료: tmp/db_backups/backup_prd_${TIMESTAMP}.sql"
ls -la tmp/db_backups/backup_prd_${TIMESTAMP}.sql
```

**중요**:
- `--exclude-table=schema_migrations` 옵션은 **필수**입니다
- 이 옵션이 없으면 Rails가 마이그레이션이 이미 완료된 것으로 인식하여 변환 스크립트가 무시됩니다

### Step 2: 데이터 복원 (Target DB)

```bash
# 복원 실행
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -f tmp/db_backups/backup_prd_${TIMESTAMP}.sql

echo "복원 완료"
```

### Step 2.5: VIEW 삭제 (필수)

컬럼명과 enum 변환 전에 VIEW를 먼저 삭제해야 합니다.

```bash
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -c "DROP VIEW IF EXISTS career_hub_event_participant_summary CASCADE"
```

### Step 3: 컬럼명 변환 (SQL 스크립트 실행)

모든 camelCase 컬럼을 snake_case로 변환합니다.

```bash
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -f scripts/convert_columns_to_snake_case.sql
```

**예상 출력**:
```
DO
DO
...
COMMIT
 Column conversion completed successfully!
ERROR:  operator does not exist: ... (VIEW 생성 실패 - 정상)
```

**주의**: VIEW 생성 오류는 enum이 아직 integer로 변환되지 않았기 때문에 발생하며, **정상입니다**. COMMIT이 표시되면 컬럼 변환은 성공한 것입니다.

### Step 4: Enum → Integer 변환

PostgreSQL enum 타입을 integer로 변환합니다. **반드시 Step 3 후에 실행해야 합니다.**

```bash
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -f scripts/convert_enums_to_integers.sql
```

**예상 출력**:
```
NOTICE:  Converted ... to integer
...
DROP TYPE
...
COMMIT
 Enum to integer conversion completed successfully!
```

`NOTICE: ... does not exist, skipping` 메시지는 이미 삭제된 타입에 대한 정상적인 메시지입니다.

### Step 4.5: VIEW 재생성

Enum 변환 후 VIEW를 재생성합니다.

```bash
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB << 'EOF'
CREATE OR REPLACE VIEW career_hub_event_participant_summary AS
SELECT
  event_id,
  count(*) FILTER (WHERE status = 0)::integer AS registered,
  count(*) FILTER (WHERE status = 1)::integer AS confirmed,
  count(*) FILTER (WHERE status = 3)::integer AS attended,
  count(*) FILTER (WHERE status = 2)::integer AS cancelled,
  count(*) FILTER (WHERE status = 4)::integer AS no_show,
  count(*)::integer AS total
FROM career_hub_community_event_participants
GROUP BY event_id;
EOF
```

### Step 5: Rails 환경 설정

`.env` 파일 업데이트:

```bash
# Production Database (Railway)
PRD_DATABASE_HOST=<새_PRD_DB_호스트>
PRD_DATABASE_PORT=<새_PRD_DB_포트>
PRD_DATABASE_USERNAME=postgres
PRD_DATABASE_PASSWORD=<새_PRD_DB_비밀번호>
```

### Step 6: Rails 마이그레이션 기록 동기화

```bash
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB << 'EOF'
CREATE TABLE IF NOT EXISTS schema_migrations (version varchar(255) PRIMARY KEY);
CREATE TABLE IF NOT EXISTS ar_internal_metadata (
  key varchar(255) PRIMARY KEY,
  value varchar(255),
  created_at timestamp(6) NOT NULL,
  updated_at timestamp(6) NOT NULL
);

-- 변환 스크립트 마이그레이션만 완료로 표시 (Active Storage는 제외!)
INSERT INTO schema_migrations (version) VALUES
  ('20260201134935')
ON CONFLICT DO NOTHING;

INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) VALUES
  ('environment', 'production', NOW(), NOW())
ON CONFLICT (key) DO UPDATE SET value = 'production', updated_at = NOW();
EOF
```

**중요**: Active Storage 마이그레이션(20260204100000, 20260204100001)은 여기서 추가하지 **않습니다**. Step 6.5에서 Rails가 실제 테이블을 생성하도록 합니다.

### Step 6.5: Rails 마이그레이션 실행 (Active Storage 등)

pg_dump로 복원된 데이터는 데이터만 포함하고, Active Storage 등 Rails 전용 테이블은 없습니다.
Rails 마이그레이션을 실행하여 필요한 테이블을 생성합니다.

```bash
# Rails 환경 설정 (.env 파일이 PRD를 가리키는지 확인)
RAILS_ENV=production bin/rails db:migrate

# 또는 특정 DB 연결 사용
DATABASE_URL="postgresql://$PRD_TARGET_USER:$PRD_TARGET_PASSWORD@$PRD_TARGET_HOST:$PRD_TARGET_PORT/$PRD_TARGET_DB" \
  RAILS_ENV=production bin/rails db:migrate
```

**예상 출력**:
```
== 20260204100000 SetupActiveStorageForAttachments: migrating =================
-- change_column_null(:profile_attachments, :url, true)
== 20260204100001 CreateActiveStorageTables: migrating ========================
-- create_table(:active_storage_blobs)
-- create_table(:active_storage_attachments)
-- create_table(:active_storage_variant_records)
```

**생성되는 테이블**:
- `active_storage_blobs` - 파일 메타데이터
- `active_storage_attachments` - 모델-파일 연결
- `active_storage_variant_records` - 이미지 변환 기록

### Step 7: 검증

```bash
echo "=== 마이그레이션 검증 ==="

# 1. camelCase 컬럼 수 확인 (0이어야 함)
echo -e "\n1. camelCase 컬럼 수 (0이어야 함):"
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -t -c "SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND column_name ~ '[A-Z]' AND table_name NOT LIKE 'pg_%'"

# 2. _int suffix 컬럼 수 확인 (0이어야 함)
echo -e "\n2. _int suffix 컬럼 수 (0이어야 함):"
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -t -c "SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND column_name LIKE '%_int'"

# 3. PostgreSQL enum 타입 수 확인 (0이어야 함)
echo -e "\n3. Enum 타입 수 (0이어야 함):"
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -t -c "SELECT count(*) FROM pg_type WHERE typtype = 'e' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')"

# 4. VIEW 존재 확인
echo -e "\n4. VIEW 존재 확인:"
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -t -c "SELECT table_name FROM information_schema.views WHERE table_schema = 'public'"

# 5. Active Storage 테이블 존재 확인
echo -e "\n5. Active Storage 테이블 확인 (3개여야 함):"
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -t -c "SELECT tablename FROM pg_tables WHERE tablename LIKE 'active_storage%' ORDER BY tablename"
```

**예상 결과**:
```
1. camelCase 컬럼 수: 0
2. _int suffix 컬럼 수: 0
3. Enum 타입 수: 0
4. VIEW: career_hub_event_participant_summary
5. Active Storage 테이블:
   - active_storage_attachments
   - active_storage_blobs
   - active_storage_variant_records
```

### Step 8: API 테스트

Rails 서버를 시작하고 API를 테스트합니다.

```bash
# 서버 시작 (별도 터미널)
RAILS_ENV=production bundle exec rails server

# API 테스트
curl -s "http://localhost:4000/api/v1/profiles/<profile_uuid>?include=profile_jobs,profile_experiences" \
  -H "Accept: application/vnd.api+json" | head -c 500

curl -s "http://localhost:4000/api/v1/featured_profiles" \
  -H "Accept: application/vnd.api+json" | head -c 500

curl -s "http://localhost:4000/api/v1/job_categories" \
  -H "Accept: application/vnd.api+json" | head -c 500
```

---

## SQL 스크립트

### scripts/convert_columns_to_snake_case.sql

이 스크립트는 `scripts/` 디렉토리에 있으며 다음 기능을 포함합니다:
- VIEW 삭제 (의존성 제거)
- 모든 테이블의 camelCase 컬럼을 snake_case로 변환
- Orphan `_int` 컬럼 자동 정리
- VIEW 재생성

### scripts/convert_enums_to_integers.sql

이 스크립트는 `scripts/` 디렉토리에 있으며 다음 기능을 포함합니다:
- PostgreSQL enum 타입을 integer로 변환
- Orphan `_int` 컬럼 자동 정리
- 사용되지 않는 enum 타입 삭제

---

## 체크리스트

### 마이그레이션 전

- [ ] 새 PRD 데이터베이스 인스턴스 생성 완료
- [ ] PostgreSQL 17 클라이언트 설치 및 경로 확인
- [ ] Source/Target DB 연결 정보 확인
- [ ] 환경 변수 설정 완료 (export)
- [ ] 충분한 디스크 공간 확인 (백업 파일용)

### 마이그레이션 중

- [ ] Step 1: pg_dump 백업 완료 (**schema_migrations 제외 확인**)
- [ ] Step 2: psql 복원 완료
- [ ] Step 2.5: VIEW 삭제 완료
- [ ] Step 3: 컬럼명 snake_case 변환 완료 (`COMMIT` 확인)
- [ ] Step 4: Enum → Integer 변환 완료 (`COMMIT` 확인)
- [ ] Step 4.5: VIEW 재생성 완료
- [ ] Step 5: .env 파일 업데이트 완료
- [ ] Step 6: schema_migrations 동기화 완료 (**Active Storage 버전 제외**)
- [ ] Step 6.5: Rails 마이그레이션 실행 완료 (Active Storage 테이블 생성 확인)

### 마이그레이션 후

- [ ] camelCase 컬럼 **0개** 확인
- [ ] `_int` suffix 컬럼 **0개** 확인
- [ ] PostgreSQL enum 타입 **0개** 확인
- [ ] `career_hub_event_participant_summary` VIEW 존재 확인
- [ ] Active Storage 테이블 **3개** 존재 확인 (blobs, attachments, variant_records)
- [ ] Rails 서버 정상 기동 확인
- [ ] API 엔드포인트 테스트 완료 (ProfileAttachment 포함)
- [ ] 프론트엔드 연동 테스트 완료

---

## 트러블슈팅

### 문제 1: pg_dump 버전 불일치

**증상**: `pg_dump: error: server version: 17.0; pg_dump version: 16.x`

**해결**:
```bash
# 설치된 PostgreSQL 17 버전 확인
ls /opt/homebrew/Cellar/postgresql@17/

# 해당 버전의 pg_dump 사용
/opt/homebrew/Cellar/postgresql@17/<버전>/bin/pg_dump ...
```

### 문제 2: 마이그레이션 실행 시 "already exists" 오류

**증상**: Rails 마이그레이션 실행 시 테이블/컬럼이 이미 존재한다는 오류

**원인**: pg_dump에 schema_migrations가 포함되어 Rails가 마이그레이션 완료로 인식

**해결**: `--exclude-table=schema_migrations` 옵션 사용

### 문제 3: `_int` suffix 컬럼이 남아있음

**증상**: `status_int`, `join_policy_int` 등의 컬럼이 남아있음

**원인**: 이전 enum 변환 중 스크립트가 중단되어 임시 컬럼이 정리되지 않음

**해결**: 스크립트는 자동으로 처리하지만, 수동으로 해결하려면:
```sql
-- 예: status_int → status
ALTER TABLE career_hub_community_event_participants RENAME COLUMN status_int TO status;
```

### 문제 4: VIEW 생성 실패 - "column does not exist"

**증상**: `CREATE VIEW` 시 `status` 컬럼이 없다는 오류

**원인**: enum 변환이 완료되지 않아 `status` 대신 `status_int`가 있음

**해결**:
1. 컬럼 변환 스크립트를 먼저 재실행
2. 또는 수동으로 컬럼 이름 변경 후 VIEW 생성

### 문제 5: Foreign Key 제약 조건 오류

**증상**: 컬럼명 변환 시 FK 제약 조건 오류

**해결**: FK 제약 조건 먼저 삭제 후 컬럼 변환, 이후 재생성
```sql
-- FK 제약 조건 확인
SELECT conname, conrelid::regclass, confrelid::regclass
FROM pg_constraint WHERE contype = 'f';
```

### 문제 6: 스크립트 실행 중 ROLLBACK

**증상**: 스크립트 마지막에 `ROLLBACK`이 표시됨

**원인**: 트랜잭션 내에서 오류 발생

**해결**:
1. 오류 메시지 확인
2. 문제 해결 후 스크립트 재실행 (멱등성 보장됨)

### 문제 7: Active Storage 테이블 누락 - "relation does not exist"

**증상**: API 호출 시 `PG::UndefinedTable: ERROR: relation "active_storage_attachments" does not exist`

**원인**:
- schema_migrations에 Active Storage 마이그레이션이 완료로 표시되어 있지만
- 실제 테이블(active_storage_blobs, active_storage_attachments, active_storage_variant_records)은 생성되지 않음
- Step 6에서 모든 마이그레이션을 완료로 표시하면 이 문제가 발생

**해결**:
```bash
# 1. schema_migrations에서 Active Storage 마이그레이션 기록 삭제
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -c "DELETE FROM schema_migrations WHERE version IN ('20260204100000', '20260204100001')"

# 2. Rails 마이그레이션 재실행
RAILS_ENV=production bin/rails db:migrate
```

**검증**:
```bash
# Active Storage 테이블 존재 확인
PGPASSWORD=$PRD_TARGET_PASSWORD $PG_BIN/psql \
  -h $PRD_TARGET_HOST \
  -p $PRD_TARGET_PORT \
  -U $PRD_TARGET_USER \
  -d $PRD_TARGET_DB \
  -c "SELECT tablename FROM pg_tables WHERE tablename LIKE 'active_storage%'"
```

**예상 결과**:
```
       tablename
------------------------
 active_storage_blobs
 active_storage_attachments
 active_storage_variant_records
```

---

## 롤백 절차

문제 발생 시 원래 DB로 롤백:

1. 애플리케이션 환경 변수를 원래 DB로 변경
2. 애플리케이션 재시작
3. 새 DB 인스턴스 삭제 (필요 시)

**중요**: 원본 DB는 읽기 전용으로만 사용하며 절대 수정하지 않습니다.

---

## 연락처

문제 발생 시 담당자에게 문의하세요.

---

*이 문서는 Dev 환경 마이그레이션 및 검증 테스트를 바탕으로 작성되었습니다.*
*최종 검증: 2026-02-04 - 모든 스크립트 멱등성 테스트 통과*
*업데이트: 2026-02-04 - Active Storage 테이블 생성 단계(Step 6.5) 추가*
*업데이트: 2026-02-04 - VIEW 삭제/재생성 단계(Step 2.5, 4.5) 추가, 스크립트 실행 순서 명확화*
