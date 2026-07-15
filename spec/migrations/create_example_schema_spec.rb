# frozen_string_literal: true

require "rails_helper"
require "securerandom"

RSpec.describe "CreateExampleSchema migration" do
  let(:migration_path) { Rails.root.join("db/migrate/20260201000000_create_example_schema.rb") }

  def insert_example(title: SecureRandom.hex(8), status: "draft", score: 0)
    @connection.execute(<<~SQL.squish)
      INSERT INTO examples (title, status, score, created_at, updated_at)
      VALUES (
        #{@connection.quote(title)},
        #{@connection.quote(status)},
        #{Integer(score)},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
    SQL
  end

  it "defines the replacement initial migration" do
    expect(migration_path).to exist
  end

  context "when applied to a fresh database connection" do
    around do |example|
      unless migration_path.exist?
        example.run
        next
      end

      require migration_path

      schema_name = "example_migration_spec_#{SecureRandom.hex(8)}"
      connection_class = Class.new(ActiveRecord::Base) do
        self.abstract_class = true
      end
      connection_class_name = "MigrationSpecRecord#{SecureRandom.hex(8)}"
      Object.const_set(connection_class_name, connection_class)
      connection_class.establish_connection(ActiveRecord::Base.connection_db_config.configuration_hash)

      @connection = connection_class.connection
      @connection.create_schema(schema_name)
      @connection.schema_search_path = schema_name
      @migration = CreateExampleSchema.new
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
      skip "replacement migration is not implemented yet" unless migration_path.exist?
    end

    it "creates only the Example domain tables" do
      expect(@connection.tables).to include(
        "examples", "example_categories", "example_tags", "example_taggings"
      )
      expect(@connection.tables.grep(/\Ablog_/)).to be_empty
      expect(@connection.table_exists?("email_templates")).to be(false)
    end

    it "uses generated UUID ids as primary keys" do
      %w[examples example_categories example_tags].each do |table_name|
        id_column = @connection.columns(table_name).find { |column| column.name == "id" }

        expect(@connection.primary_key(table_name)).to eq("id")
        expect(id_column.sql_type).to eq("uuid")
        expect(id_column.default_function).to eq("gen_random_uuid()")
      end
    end

    it "adds the nullable category relationship with nullification on delete" do
      category_column = @connection.columns("examples").find { |column| column.name == "category_id" }
      category_foreign_key = @connection.foreign_keys("examples").find do |foreign_key|
        foreign_key.options[:column] == "category_id"
      end

      expect(category_column.sql_type).to eq("uuid")
      expect(category_column.null).to be(true)
      expect(category_foreign_key.to_table).to eq("example_categories")
      expect(category_foreign_key.options[:on_delete]).to eq(:nullify)
    end

    it "uses a composite primary key and cascading foreign keys for taggings" do
      expect(@connection.primary_keys("example_taggings")).to eq(%w[example_id tag_id])

      foreign_keys = @connection.foreign_keys("example_taggings").index_by do |foreign_key|
        foreign_key.options[:column]
      end
      expect(foreign_keys.fetch("example_id").to_table).to eq("examples")
      expect(foreign_keys.fetch("example_id").options[:on_delete]).to eq(:cascade)
      expect(foreign_keys.fetch("tag_id").to_table).to eq("example_tags")
      expect(foreign_keys.fetch("tag_id").options[:on_delete]).to eq(:cascade)
    end

    it "constrains Example title, status, and score" do
      columns = @connection.columns("examples").index_by(&:name)
      constraints = @connection.check_constraints("examples").index_by(&:name)

      expect(columns.fetch("title").limit).to eq(200)
      expect(columns.fetch("status").default).to eq("draft")
      expect(columns.fetch("score").default).to eq(0)
      expect(constraints.fetch("examples_status_check").expression).to include(
        "draft", "active", "archived"
      )
      expect(constraints.fetch("examples_score_check").expression).to match(/score.*(?:BETWEEN|>=).*100/i)
    end

    it "accepts every allowed status" do
      %w[draft active archived].each do |status|
        insert_example(status: status, score: 50)
      end

      expect(@connection.select_values("SELECT status FROM examples")).to contain_exactly(
        "draft", "active", "archived"
      )
    end

    it "accepts both score boundaries" do
      [ 0, 100 ].each do |score|
        insert_example(score: score)
      end

      scores = @connection.select_values("SELECT score FROM examples").map(&:to_i)
      expect(scores).to contain_exactly(0, 100)
    end

    it "rejects a status outside the allowed set" do
      expect do
        @connection.transaction(requires_new: true) do
          insert_example(status: "pending", score: 50)
        end
      end.to raise_error(ActiveRecord::StatementInvalid, /examples_status_check/)
    end

    it "rejects scores outside both boundaries" do
      [ -1, 101 ].each do |score|
        expect do
          @connection.transaction(requires_new: true) do
            insert_example(score: score)
          end
        end.to raise_error(ActiveRecord::StatementInvalid, /examples_score_check/)
      end
    end

    it "adds unique indexes for category and tag names" do
      %w[example_categories example_tags].each do |table_name|
        name_index = @connection.indexes(table_name).find { |index| index.columns == [ "name" ] }

        expect(name_index.unique).to be(true)
      end
    end

    it "uses non-null timestamps on Example, Category, and Tag" do
      %w[examples example_categories example_tags].each do |table_name|
        columns = @connection.columns(table_name).index_by(&:name)

        expect(columns.fetch("created_at").null).to be(false)
        expect(columns.fetch("updated_at").null).to be(false)
      end
    end

    it "removes every Example domain table on rollback" do
      @migration.suppress_messages { @migration.exec_migration(@connection, :down) }

      expect(@connection.tables).not_to include(
        "examples", "example_categories", "example_tags", "example_taggings"
      )
    end
  end
end
