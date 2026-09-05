# frozen_string_literal: true

require "rails_helper"
require "securerandom"

RSpec.describe "CreateAuthSchema migration" do
  let(:migration_path) { Rails.root.join("db/migrate/20260205000000_create_auth_schema.rb") }

  def insert_user(id: SecureRandom.uuid, email: "user-#{SecureRandom.hex(8)}@example.com",
                   password_hash: "placeholder-hash", is_active: true)
    @connection.execute(<<~SQL.squish)
      INSERT INTO users (id, email, password_hash, is_active, created_at, updated_at)
      VALUES (
        #{@connection.quote(id)},
        #{@connection.quote(email)},
        #{@connection.quote(password_hash)},
        #{@connection.quote(is_active)},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
    SQL
    id
  end

  def insert_refresh_session(user_id:, id: SecureRandom.uuid, token_hash: SecureRandom.hex(32),
                              expires_at: 1.day.from_now, revoked_at: nil, replaced_by_id: nil)
    @connection.execute(<<~SQL.squish)
      INSERT INTO refresh_sessions (id, user_id, token_hash, expires_at, revoked_at, replaced_by_id, created_at)
      VALUES (
        #{@connection.quote(id)},
        #{@connection.quote(user_id)},
        #{@connection.quote(token_hash)},
        #{@connection.quote(expires_at)},
        #{revoked_at ? @connection.quote(revoked_at) : "NULL"},
        #{replaced_by_id ? @connection.quote(replaced_by_id) : "NULL"},
        CURRENT_TIMESTAMP
      )
    SQL
    id
  end

  it "defines the auth schema migration" do
    expect(migration_path).to exist
  end

  context "when applied to a fresh database connection" do
    around do |example|
      unless migration_path.exist?
        example.run
        next
      end

      require migration_path

      schema_name = "auth_migration_spec_#{SecureRandom.hex(8)}"
      connection_class = Class.new(ActiveRecord::Base) do
        self.abstract_class = true
      end
      connection_class_name = "MigrationSpecRecord#{SecureRandom.hex(8)}"
      Object.const_set(connection_class_name, connection_class)
      connection_class.establish_connection(ActiveRecord::Base.connection_db_config.configuration_hash)

      @connection = connection_class.connection
      @connection.create_schema(schema_name)
      @connection.schema_search_path = schema_name
      @migration = CreateAuthSchema.new
      @migration.suppress_messages { @migration.exec_migration(@connection, :up) }

      example.run
    ensure
      if @connection
        @connection.schema_search_path = "public"
        @connection.drop_schema(schema_name, if_exists: true, cascade: true)
      end
      connection_class&.connection_pool&.disconnect!
      Object.send(:remove_const, connection_class_name) if connection_class_name
    end

    before do
      skip "auth schema migration is not implemented yet" unless migration_path.exist?
    end

    it "creates the users and refresh_sessions tables" do
      expect(@connection.tables).to include("users", "refresh_sessions")
    end

    it "uses a generated UUID id as the users primary key" do
      id_column = @connection.columns("users").find { |column| column.name == "id" }

      expect(@connection.primary_key("users")).to eq("id")
      expect(id_column.sql_type).to eq("uuid")
      expect(id_column.default_function).to eq("gen_random_uuid()")
    end

    it "uses an application-supplied UUID id for refresh_sessions, with no DB default" do
      # refresh_sessions.id는 refresh JWT의 jti와 같아야 하므로 애플리케이션이
      # 매번 명시적으로 채운다(Task 3+). DB 기본값이 있으면 id를 빠뜨리는
      # 실수가 나도 삽입이 조용히 성공해 jti와 무관한 UUID가 PK로 들어가 버리고,
      # 그 refresh 토큰을 쓰는 모든 요청이 원인을 알기 어려운 "session not
      # found"로 실패한다. 기본값이 없어야 같은 실수가 NOT NULL 위반으로 즉시
      # 드러난다 — 이 부재는 실수가 아니라 설계이므로 되돌리지 말 것.
      id_column = @connection.columns("refresh_sessions").find { |column| column.name == "id" }

      expect(@connection.primary_key("refresh_sessions")).to eq("id")
      expect(id_column.sql_type).to eq("uuid")
      expect(id_column.default_function).to be_nil
    end

    it "rejects an insert into refresh_sessions that omits id" do
      user_id = insert_user

      expect do
        @connection.transaction(requires_new: true) do
          @connection.execute(<<~SQL.squish)
            INSERT INTO refresh_sessions (user_id, token_hash, expires_at, created_at)
            VALUES (
              #{@connection.quote(user_id)},
              #{@connection.quote(SecureRandom.hex(32))},
              CURRENT_TIMESTAMP + INTERVAL '1 day',
              CURRENT_TIMESTAMP
            )
          SQL
        end
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "defines the users columns with the expected types and null constraints" do
      columns = @connection.columns("users").index_by(&:name)

      expect(columns.fetch("email").sql_type).to eq("character varying(254)")
      expect(columns.fetch("email").null).to be(false)
      expect(columns.fetch("password_hash").sql_type).to eq("text")
      expect(columns.fetch("password_hash").null).to be(false)
      expect(columns.fetch("is_active").sql_type).to eq("boolean")
      expect(columns.fetch("is_active").null).to be(false)
      expect(columns.fetch("is_active").default).to eq(true)
      expect(columns.fetch("created_at").null).to be(false)
      expect(columns.fetch("updated_at").null).to be(false)
    end

    it "defines the refresh_sessions columns with the expected types and null constraints" do
      columns = @connection.columns("refresh_sessions").index_by(&:name)

      expect(columns.fetch("user_id").sql_type).to eq("uuid")
      expect(columns.fetch("user_id").null).to be(false)
      expect(columns.fetch("token_hash").sql_type).to eq("character varying(64)")
      expect(columns.fetch("token_hash").null).to be(false)
      expect(columns.fetch("expires_at").null).to be(false)
      expect(columns.fetch("revoked_at").null).to be(true)
      expect(columns.fetch("replaced_by_id").sql_type).to eq("uuid")
      expect(columns.fetch("replaced_by_id").null).to be(true)
      expect(columns.fetch("created_at").null).to be(false)
      expect(columns.key?("updated_at")).to be(false)
    end

    it "adds a unique index on users.email" do
      index = @connection.indexes("users").find { |i| i.columns == [ "email" ] }

      expect(index).to be_present
      expect(index.unique).to be(true)
    end

    it "adds a unique index on refresh_sessions.token_hash" do
      index = @connection.indexes("refresh_sessions").find { |i| i.columns == [ "token_hash" ] }

      expect(index).to be_present
      expect(index.unique).to be(true)
    end

    it "adds a non-unique index on refresh_sessions.user_id" do
      index = @connection.indexes("refresh_sessions").find { |i| i.columns == [ "user_id" ] }

      expect(index).to be_present
    end

    it "adds a non-unique index on refresh_sessions.expires_at" do
      # 정리 job(Task 7)이 expires_at < now() ORDER BY expires_at LIMIT n으로
      # 만료된 세션을 배치 조회한다. 인덱스가 없으면 그 후보 조회가 매번
      # 테이블 전체를 스캔한다.
      index = @connection.indexes("refresh_sessions").find { |i| i.columns == [ "expires_at" ] }

      expect(index).to be_present
    end

    it "adds a non-unique index on refresh_sessions.replaced_by_id" do
      # 이 인덱스가 없으면 정리 job의 대량 삭제가 유발하는 cascade UPDATE가
      # 배치마다 테이블 전체를 순차 스캔한다 (NestJS 사고 재현 방지).
      index = @connection.indexes("refresh_sessions").find { |i| i.columns == [ "replaced_by_id" ] }

      expect(index).to be_present
    end

    it "adds the user_id foreign key with ON DELETE CASCADE" do
      foreign_key = @connection.foreign_keys("refresh_sessions").find do |fk|
        fk.options[:column] == "user_id"
      end

      expect(foreign_key.to_table).to eq("users")
      expect(foreign_key.options[:on_delete]).to eq(:cascade)
    end

    it "adds the replaced_by_id self-referential foreign key with ON DELETE SET NULL" do
      foreign_key = @connection.foreign_keys("refresh_sessions").find do |fk|
        fk.options[:column] == "replaced_by_id"
      end

      expect(foreign_key.to_table).to eq("refresh_sessions")
      expect(foreign_key.options[:on_delete]).to eq(:nullify)
    end

    it "cascades user deletion to their refresh sessions" do
      user_id = insert_user
      insert_refresh_session(user_id: user_id)

      @connection.execute("DELETE FROM users WHERE id = #{@connection.quote(user_id)}")

      expect(@connection.select_value("SELECT COUNT(*) FROM refresh_sessions WHERE user_id = #{@connection.quote(user_id)}").to_i).to eq(0)
    end

    it "nullifies replaced_by_id when the replacing session is deleted" do
      user_id = insert_user
      original_id = insert_refresh_session(user_id: user_id)
      replacement_id = insert_refresh_session(user_id: user_id, replaced_by_id: nil)

      @connection.execute(<<~SQL.squish)
        UPDATE refresh_sessions SET replaced_by_id = #{@connection.quote(replacement_id)}
        WHERE id = #{@connection.quote(original_id)}
      SQL

      @connection.execute("DELETE FROM refresh_sessions WHERE id = #{@connection.quote(replacement_id)}")

      reloaded = @connection.select_one(<<~SQL.squish)
        SELECT replaced_by_id FROM refresh_sessions WHERE id = #{@connection.quote(original_id)}
      SQL
      expect(reloaded["replaced_by_id"]).to be_nil
    end

    it "removes both auth tables on rollback" do
      @migration.suppress_messages { @migration.exec_migration(@connection, :down) }

      expect(@connection.tables).not_to include("users", "refresh_sessions")
    end
  end

  # 위 컨텍스트는 예제마다 새로 만드는 격리된 스키마에 마이그레이션 파일을 직접
  # 재생해서 검증한다 — db/schema.rb는 전혀 읽지 않는다. 그런데 이 스위트가 실제로
  # 도는 테스트 DB는 로컬에서는 db:migrate로, CI(.github/workflows/ci.yml)에서는
  # db:create + db:schema:load로 만들어진다. 즉 db/schema.rb와 마이그레이션 파일은
  # 독립적으로 손댈 수 있는 두 산출물인데, 검증하는 건 마이그레이션 파일뿐이었다.
  #
  # 예를 들어 누군가 db/schema.rb에서 "불필요해 보이는" `default: nil`만 지우고
  # 마이그레이션 파일은 그대로 둔다면: 위 컨텍스트는 여전히 초록이고(마이그레이션
  # 파일은 안 바뀌었으니), 모델/factory spec들도 여전히 초록이다(factory가 항상
  # id를 명시적으로 채우므로 DB 기본값 유무와 무관하게 통과한다). 그 사이 CI가
  # db:schema:load로 만드는 실제 DB는 refresh_sessions.id에 gen_random_uuid()
  # 기본값을 다시 갖게 되어, 이 태스크가 막으려던 사고(빠뜨린 id가 조용히
  # 무관한 UUID로 채워지는 것)가 그대로 재현된다 — 아무 spec도 이를 못 잡는다.
  #
  # 그래서 이 블록은 격리된 스키마가 아니라 이 프로세스가 실제로 물려 있는
  # ActiveRecord::Base.connection을 직접 본다. db:migrate로 만들어졌든
  # db:schema:load로 만들어졌든 상관없이, "이 테스트 스위트가 지금 돌고 있는
  # 바로 그 DB"의 실제 상태를 확인한다.
  context "against the database this test suite is actually running on" do
    it "gives users.id a database default but leaves refresh_sessions.id without one" do
      connection = ActiveRecord::Base.connection

      users_id = connection.columns("users").find { |column| column.name == "id" }
      refresh_sessions_id = connection.columns("refresh_sessions").find { |column| column.name == "id" }

      expect(users_id.default_function).to eq("gen_random_uuid()")
      expect(refresh_sessions_id.default_function).to be_nil
    end
  end
end
