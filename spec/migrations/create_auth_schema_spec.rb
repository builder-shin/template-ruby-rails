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

    it "uses generated UUID ids as primary keys" do
      %w[users refresh_sessions].each do |table_name|
        id_column = @connection.columns(table_name).find { |column| column.name == "id" }

        expect(@connection.primary_key(table_name)).to eq("id")
        expect(id_column.sql_type).to eq("uuid")
        expect(id_column.default_function).to eq("gen_random_uuid()")
      end
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
end
