# frozen_string_literal: true

class AlignSharedContracts < ActiveRecord::Migration[8.1]
  NAME_LIMIT = 200
  TABLES = %i[example_categories example_tags].freeze

  def up
    overlong_table = TABLES.find do |table_name|
      select_value("SELECT 1 FROM #{quote_table_name(table_name)} WHERE char_length(name) > #{NAME_LIMIT} LIMIT 1")
    end
    if overlong_table
      raise ActiveRecord::MigrationError,
            "#{overlong_table}.name contains values longer than #{NAME_LIMIT}; shorten them before migrating"
    end

    TABLES.each do |table_name|
      change_column table_name, :name, :string, limit: NAME_LIMIT, null: false
    end
    change_column_default :examples, :status, from: "draft", to: nil
    change_column_default :examples, :score, from: 0, to: nil
  end

  def down
    TABLES.each do |table_name|
      change_column table_name, :name, :string, limit: nil, null: false
    end
    change_column_default :examples, :status, from: nil, to: "draft"
    change_column_default :examples, :score, from: nil, to: 0
  end
end
