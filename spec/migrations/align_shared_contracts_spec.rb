# frozen_string_literal: true

require "rails_helper"
require "securerandom"

RSpec.describe "AlignSharedContracts migration" do
  let(:migration_path) { Rails.root.join("db/migrate/20260911000000_align_shared_contracts.rb") }

  around do |example|
    require migration_path if migration_path.exist?
    schema_name = "shared_contract_migration_spec_#{SecureRandom.hex(8)}"
    record_class = Class.new(ActiveRecord::Base) { self.abstract_class = true }
    record_name = "SharedContractMigrationRecord#{SecureRandom.hex(8)}"
    Object.const_set(record_name, record_class)
    record_class.establish_connection(ActiveRecord::Base.connection_db_config.configuration_hash)
    @connection = record_class.connection
    @connection.create_schema(schema_name)
    @connection.schema_search_path = schema_name
    @connection.create_table(:example_categories, id: :uuid) { |table| table.string :name, null: false }
    @connection.create_table(:example_tags, id: :uuid) { |table| table.string :name, null: false }
    @connection.create_table(:examples, id: :uuid) do |table|
      table.string :status, null: false, default: "draft"
      table.integer :score, null: false, default: 0
    end
    example.run
  ensure
    if @connection
      @connection.schema_search_path = "public"
      @connection.drop_schema(schema_name, if_exists: true, cascade: true)
    end
    record_class&.connection_pool&.disconnect!
    Object.send(:remove_const, record_name) if record_name
  end

  it "narrows both name columns to 200 without changing existing valid rows" do
    skip "migration is not implemented yet" unless migration_path.exist?
    @connection.execute("INSERT INTO example_categories (name) VALUES ('kept category')")
    @connection.execute("INSERT INTO example_tags (name) VALUES ('kept tag')")

    migration = AlignSharedContracts.new
    migration.suppress_messages { migration.exec_migration(@connection, :up) }

    expect(@connection.columns(:example_categories).index_by(&:name).fetch("name").limit).to eq(200)
    expect(@connection.columns(:example_tags).index_by(&:name).fetch("name").limit).to eq(200)
    expect(@connection.columns(:examples).index_by(&:name).fetch("status").default).to be_nil
    expect(@connection.columns(:examples).index_by(&:name).fetch("score").default).to be_nil
    expect(@connection.select_values("SELECT name FROM example_categories")).to eq([ "kept category" ])
    expect(@connection.select_values("SELECT name FROM example_tags")).to eq([ "kept tag" ])
  end

  it "fails before changing either column when legacy data exceeds the canonical limit" do
    skip "migration is not implemented yet" unless migration_path.exist?
    long_name = @connection.quote("x" * 201)
    @connection.execute("INSERT INTO example_tags (name) VALUES (#{long_name})")

    expect do
      migration = AlignSharedContracts.new
      migration.suppress_messages { migration.exec_migration(@connection, :up) }
    end.to raise_error(ActiveRecord::MigrationError, /example_tags/)

    expect(@connection.columns(:example_categories).index_by(&:name).fetch("name").limit).to be_nil
    expect(@connection.columns(:example_tags).index_by(&:name).fetch("name").limit).to be_nil
    expect(@connection.select_value("SELECT name FROM example_tags")).to eq("x" * 201)
    expect(@connection.columns(:examples).index_by(&:name).fetch("status").default).to eq("draft")
    expect(@connection.columns(:examples).index_by(&:name).fetch("score").default).to eq(0)
  end
end
