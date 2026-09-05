# frozen_string_literal: true

class CreateAuthSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :email, limit: 254, null: false
      t.text :password_hash, null: false
      t.boolean :is_active, null: false, default: true
      t.timestamps null: false

      t.index :email, unique: true
    end

    create_table :refresh_sessions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :token_hash, limit: 64, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.uuid :replaced_by_id
      t.datetime :created_at, null: false

      t.index :user_id
      t.index :token_hash, unique: true

      # user_id에 인덱스가 필요한 이유: user_id FK가 ON DELETE CASCADE라 사용자
      # 삭제 시 이 컬럼으로 대상 행을 찾아야 한다. 인덱스가 없으면 사용자를
      # 지울 때마다 refresh_sessions 전체를 순차 스캔한다.
      #
      # replaced_by_id에 인덱스가 필요한 이유: 이 컬럼은 자기참조 FK이고
      # ON DELETE SET NULL이다. 정리 job이 만료된 세션을 대량 삭제하면, 그
      # 삭제마다 "이 행을 replaced_by_id로 가리키는 행이 있는가"를 찾아 NULL로
      # UPDATE해야 한다 — 인덱스가 없으면 배치마다 테이블 전체를 순차 스캔한다.
      # NestJS가 이 인덱스 없이 배포되어 실제로 이 지점에서 장애를 냈다: batch
      # 크기를 제한해도, lock 대기 타임아웃을 걸어도 막지 못했다. 하나는 왕복
      # 횟수를 제한하고 다른 하나는 대기 시간을 제한할 뿐, 개별 statement의
      # 실행 시간 자체는 아무것도 제한하지 않기 때문이다. 인덱스는 지우기
      # 쉬우니, 지우기 전에 이 코멘트를 읽어라.
      t.index :replaced_by_id
    end

    add_foreign_key :refresh_sessions, :users, on_delete: :cascade
    add_foreign_key :refresh_sessions, :refresh_sessions, column: :replaced_by_id, on_delete: :nullify
  end
end
