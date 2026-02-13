<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Database (db/)

## Purpose
PostgreSQL 데이터베이스 관련 파일 디렉토리. 마이그레이션 파일, 현재 스키마, 시드 데이터를 포함합니다.

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | Database 가이드, 마이그레이션 패턴 |
| `schema.rb` | 현재 데이터베이스 스키마 (자동 생성, 직접 수정 금지) |
| `seeds.rb` | 시드 데이터 정의 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `migrate/` | 마이그레이션 파일 (타임스탬프_파일명.rb 형식) |

## For AI Agents

### Working In This Directory
Database 작업 시:

1. **schema.rb 직접 수정 금지**: 마이그레이션으로만 스키마 변경
2. **마이그레이션 순서**: 타임스탬프 순으로 실행됨
3. **롤백 가능**: `change` 메서드 사용 시 자동 롤백 지원
4. **외래 키**: `references` 또는 `add_foreign_key` 사용
5. **인덱스**: 검색 및 외래 키 컬럼에 인덱스 추가

### Common Patterns

#### 마이그레이션 생성
```bash
# 테이블 생성
bin/rails g migration CreateProfiles user_id:uuid name:string status:integer

# 컬럼 추가
bin/rails g migration AddEmailToProfiles email:string

# 컬럼 삭제
bin/rails g migration RemoveFieldFromProfiles field:string

# 인덱스 추가
bin/rails g migration AddIndexToProfiles email:index
```

#### 테이블 생성 마이그레이션
```ruby
class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      # UUID 외래 키 (외부 인증 서비스)
      t.uuid :user_id, null: false, index: { unique: true }

      # 문자열 컬럼
      t.string :name, limit: 100
      t.string :email, null: false

      # 정수 컬럼 (Enum)
      t.integer :job_seeking_status, default: 0, null: false

      # 텍스트 컬럼
      t.text :bio

      # JSONB 컬럼 (PostgreSQL)
      t.jsonb :employment_type, default: {}

      # Array 컬럼 (PostgreSQL)
      t.text :skills, array: true, default: []

      # Boolean 컬럼
      t.boolean :email_public, default: false, null: false

      # 외래 키 (references)
      t.references :job_category, foreign_key: true, null: true
      t.references :nationality, foreign_key: { to_table: :countries }, null: true

      # 타임스탬프 (created_at, updated_at)
      t.timestamps
    end

    # 인덱스 추가
    add_index :profiles, :email
    add_index :profiles, :job_seeking_status
  end
end
```

#### 컬럼 추가/삭제
```ruby
class AddFieldToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :profile_image, :string
    add_column :profiles, :overall_completeness, :integer, default: 0

    # 컬럼 삭제
    remove_column :profiles, :old_field, :string
  end
end
```

#### 인덱스 추가
```ruby
class AddIndexToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_index :profiles, :user_id, unique: true
    add_index :profiles, [:job_category_id, :created_at]
  end
end
```

#### 외래 키 추가
```ruby
class AddForeignKeys < ActiveRecord::Migration[8.1]
  def change
    # 일반 외래 키
    add_foreign_key :profiles, :job_categories

    # 다른 테이블명으로 참조
    add_foreign_key :profiles, :countries, column: :nationality_id

    # 외래 키 삭제
    remove_foreign_key :profiles, :job_categories
  end
end
```

#### 조인 테이블 생성
```ruby
class CreateJobPostCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :job_post_categories do |t|
      t.references :job_post, null: false, foreign_key: true
      t.references :job_category, null: false, foreign_key: true

      t.timestamps
    end

    # 복합 인덱스 (중복 방지)
    add_index :job_post_categories, [:job_post_id, :job_category_id], unique: true
  end
end
```

#### JSONB 컬럼 추가
```ruby
class AddEmploymentTypeToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :employment_type, :jsonb, default: {}
    add_index :profiles, :employment_type, using: :gin
  end
end
```

#### Array 컬럼 추가
```ruby
class AddSkillsToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :skills, :text, array: true, default: []
    add_column :profiles, :work_type, :text, array: true, default: []
  end
end
```

#### 롤백 가능한 마이그레이션 (up/down)
```ruby
class ComplexMigration < ActiveRecord::Migration[8.1]
  def up
    # 복잡한 변경 (자동 롤백 불가)
    execute "UPDATE profiles SET status = 1 WHERE created_at < '2024-01-01'"
  end

  def down
    # 수동 롤백 로직
    execute "UPDATE profiles SET status = 0 WHERE created_at < '2024-01-01'"
  end
end
```

#### 데이터 마이그레이션
```ruby
class MigrateOldData < ActiveRecord::Migration[8.1]
  def up
    Profile.where(old_status: 'active').update_all(status: 1)
  end

  def down
    Profile.where(status: 1).update_all(old_status: 'active')
  end
end
```

#### 시드 데이터 (seeds.rb)
```ruby
# db/seeds.rb

# 국가 데이터
countries = [
  { name: '한국', code: 'KR' },
  { name: '미국', code: 'US' },
  { name: '일본', code: 'JP' }
]

countries.each do |country_data|
  Country.find_or_create_by(code: country_data[:code]) do |country|
    country.name = country_data[:name]
  end
end

# 직무 카테고리
job_categories = [
  { name: '프론트엔드 개발' },
  { name: '백엔드 개발' },
  { name: 'DevOps' }
]

job_categories.each do |category_data|
  JobCategory.find_or_create_by(name: category_data[:name])
end
```

#### 마이그레이션 실행 명령어
```bash
# 마이그레이션 실행
bin/rails db:migrate

# 특정 버전으로 마이그레이션
bin/rails db:migrate VERSION=20240101000000

# 롤백 (마지막 마이그레이션 취소)
bin/rails db:rollback

# N개 롤백
bin/rails db:rollback STEP=3

# 데이터베이스 초기화 (drop + create + migrate)
bin/rails db:reset

# 시드 데이터 로드
bin/rails db:seed

# 스키마 로드 (마이그레이션 없이)
bin/rails db:schema:load
```

#### schema.rb 예시
```ruby
# db/schema.rb (자동 생성, 직접 수정 금지)
ActiveRecord::Schema[8.1].define(version: 2024_01_01_000000) do
  enable_extension "plpgsql"

  create_table "profiles", force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", limit: 100
    t.integer "job_seeking_status", default: 0, null: false
    t.jsonb "employment_type", default: {}
    t.text "skills", default: [], array: true
    t.bigint "job_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_category_id"], name: "index_profiles_on_job_category_id"
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  add_foreign_key "profiles", "job_categories"
end
```

## Dependencies

### Internal
- `app/models/` - 마이그레이션이 정의하는 테이블에 대응하는 모델
- `config/database.yml` - 데이터베이스 연결 설정

### External
- PostgreSQL - 데이터베이스 시스템
- ActiveRecord (Rails) - ORM 및 마이그레이션 프레임워크

<!-- MANUAL: -->
