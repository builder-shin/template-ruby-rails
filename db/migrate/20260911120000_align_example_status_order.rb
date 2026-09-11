# frozen_string_literal: true

class AlignExampleStatusOrder < ActiveRecord::Migration[8.1]
  def up
    create_enum :example_status, %w[draft active archived]
    change_column_default :examples, :status, nil
    remove_check_constraint :examples, name: "examples_status_check"
    execute "ALTER TABLE examples ALTER COLUMN status TYPE example_status USING status::example_status"
  end

  def down
    change_column_default :examples, :status, nil
    execute "ALTER TABLE examples ALTER COLUMN status TYPE character varying USING status::text"
    add_check_constraint :examples, "status IN ('draft', 'active', 'archived')", name: "examples_status_check"
    drop_enum :example_status
  end
end
