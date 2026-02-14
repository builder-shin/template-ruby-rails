class DropLegacyTypeormTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :typeorm_metadata, if_exists: true
    drop_table :migrations_history, if_exists: true
    drop_table :"query-result-cache", if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
