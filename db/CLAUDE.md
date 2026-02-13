# Database

PostgreSQL 데이터베이스 관련 파일들.

## 구조

```
db/
├── migrate/        # 마이그레이션 파일
├── schema.rb       # 현재 스키마 (자동 생성)
└── seeds.rb        # 시드 데이터
```

## 현재 마이그레이션

4개의 마이그레이션 파일이 존재합니다:
- `20260201134935_convert_to_rails_conventions.rb` - Rails 컨벤션 변환
- `20260204100000_setup_active_storage_for_attachments.rb` - Active Storage 첨부파일 설정
- `20260204100001_create_active_storage_tables.active_storage.rb` - Active Storage 테이블 생성
- `20260205161903_create_recruitment_requests.rb` - 채용 요청 테이블 생성

전체 스키마는 `schema.rb`를 참조하세요.

## 명령어

```bash
# 마이그레이션 실행
bin/rails db:migrate

# 롤백
bin/rails db:rollback

# 리셋 (drop + create + migrate)
bin/rails db:reset

# 시드 데이터 로드
bin/rails db:seed

# 스키마 로드 (마이그레이션 없이)
bin/rails db:schema:load
```

## 새 마이그레이션 생성

```bash
# 테이블 생성
bin/rails g migration CreateResources name:string status:integer user:references

# 컬럼 추가
bin/rails g migration AddFieldToResources field:string

# 인덱스 추가
bin/rails g migration AddIndexToResources field:index
```

## 마이그레이션 패턴

```ruby
class CreateResources < ActiveRecord::Migration[8.1]
  def change
    create_table :resources do |t|
      t.string :name, null: false
      t.integer :status, default: 0
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :resources, :status
  end
end
```
