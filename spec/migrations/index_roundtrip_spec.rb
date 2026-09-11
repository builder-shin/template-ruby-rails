# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20260911130000_align_example_indexes")
require Rails.root.join("db/migrate/20260911140000_index_tag_relationship")

RSpec.describe "Exact index migration rollback" do
  [ [ AlignExampleIndexes, [ "btree (created_at DESC, id)", "btree (title, id)" ] ],
    [ IndexTagRelationship, [ "btree (tag_id)" ] ] ].each do |migration_class, required|
    it "restores all index definitions and preserves rows/defaults for #{migration_class}" do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.transaction(requires_new: true) do
          connection.execute("CREATE SCHEMA index_roundtrip_probe")
          connection.execute("SET LOCAL search_path TO index_roundtrip_probe")
          connection.execute(<<~SQL)
            CREATE TABLE examples (id uuid PRIMARY KEY,title varchar(200) NOT NULL,
              created_at timestamptz NOT NULL DEFAULT now(),category_id uuid,
              status varchar(20) NOT NULL,score integer NOT NULL)
          SQL
          connection.execute("CREATE INDEX index_examples_on_category_id ON examples(category_id)")
          connection.execute("CREATE TABLE example_taggings(example_id uuid,tag_id uuid,PRIMARY KEY(example_id,tag_id))")
          connection.execute(<<~SQL)
            INSERT INTO examples VALUES ('00000000-0000-0000-0000-000000000001','kept',
              '2026-09-11 01:02:03.123456+00',NULL,'active',42)
          SQL
          connection.execute(<<~SQL)
            INSERT INTO example_taggings VALUES ('00000000-0000-0000-0000-000000000001',
              '00000000-0000-0000-0000-000000000002')
          SQL
          indexes_sql = "SELECT indexdef FROM pg_indexes WHERE schemaname=current_schema() ORDER BY indexname"
          columns_sql = <<~SQL
            SELECT table_name,column_name,column_default,is_nullable,data_type
            FROM information_schema.columns WHERE table_schema=current_schema() ORDER BY table_name,ordinal_position
          SQL
          rows_sql = "SELECT row_to_json(t)::text FROM examples t UNION ALL SELECT row_to_json(t)::text FROM example_taggings t"
          before = connection.select_rows(indexes_sql)
          columns = connection.select_rows(columns_sql)
          rows = connection.select_rows(rows_sql)
          migration = migration_class.new
          migration.suppress_messages { migration.exec_migration(connection, :up) }
          after = connection.select_values(indexes_sql)
          required.each { |definition| expect(after.any? { |value| value.end_with?(definition) }).to be(true) }
          expect(connection.select_rows(columns_sql)).to eq(columns)
          expect(connection.select_rows(rows_sql)).to eq(rows)
          migration.suppress_messages { migration.exec_migration(connection, :down) }
          expect(connection.select_rows(indexes_sql)).to eq(before)
          expect(connection.select_rows(columns_sql)).to eq(columns)
          expect(connection.select_rows(rows_sql)).to eq(rows)
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end
