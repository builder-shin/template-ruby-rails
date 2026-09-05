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

    # id에 DB 기본값을 주지 않는다. refresh_sessions.id는 반드시 refresh JWT의
    # jti와 같아야 하므로 애플리케이션이 매번 명시적으로 채운다(Task 3+). DB가
    # 기본값을 대신 채워주면 id를 빠뜨리는 실수가 나도 삽입은 조용히 성공하고
    # Postgres가 jti와 무관한 UUID를 만들어 버린다 — 그러면 세션의 PK가 발급된
    # 토큰의 jti와 어긋나, 그 refresh 토큰을 쓰는 모든 요청이 원인을 알기 어려운
    # "session not found"로 실패한다. 기본값을 없애면 같은 실수가 NOT NULL
    # 위반으로 즉시, 시끄럽게 실패한다.
    #
    # 주의: `default:`를 그냥 생략하면 안 된다. Rails PostgreSQL 어댑터의
    # `primary_key`가 `id: :uuid`에 `options.fetch(:default, "gen_random_uuid()")`를
    # 적용해서, 아무것도 안 쓰면 여전히 자동으로 gen_random_uuid() 기본값이
    # 붙는다. 반드시 `default: nil`을 명시해야 기본값이 실제로 없어진다.
    create_table :refresh_sessions, id: :uuid, default: nil do |t|
      t.uuid :user_id, null: false
      t.string :token_hash, limit: 64, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.uuid :replaced_by_id
      t.datetime :created_at, null: false

      # user_id에 인덱스가 필요한 이유: user_id FK가 ON DELETE CASCADE라 사용자
      # 삭제 시 이 컬럼으로 대상 행을 찾아야 한다. 인덱스가 없으면 사용자를
      # 지울 때마다 refresh_sessions 전체를 순차 스캔한다.
      t.index :user_id

      t.index :token_hash, unique: true

      # expires_at에 인덱스가 필요한 이유: 정리 job(Task 7)이 만료된 세션을
      # expires_at < now() ORDER BY expires_at LIMIT n 형태로 배치 조회한다.
      # 인덱스가 없으면 그 후보 조회 자체가 매번 테이블 전체를 스캔한다.
      t.index :expires_at

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
