# frozen_string_literal: true

class CreateExampleSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :example_categories, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.timestamps null: false

      t.index :name, unique: true
    end

    create_table :example_tags, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.timestamps null: false

      t.index :name, unique: true
    end

    create_table :examples, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :title, limit: 200, null: false
      t.text :description
      t.string :status, default: "draft", null: false
      t.integer :score, default: 0, null: false
      t.uuid :category_id
      t.timestamps null: false

      t.index :category_id
      t.check_constraint "status IN ('draft', 'active', 'archived')", name: "examples_status_check"
      t.check_constraint "score BETWEEN 0 AND 100", name: "examples_score_check"
    end

    create_table :example_taggings, primary_key: [ :example_id, :tag_id ] do |t|
      t.uuid :example_id, null: false
      t.uuid :tag_id, null: false
    end

    add_foreign_key :examples, :example_categories, column: :category_id, on_delete: :nullify
    add_foreign_key :example_taggings, :examples, on_delete: :cascade
    add_foreign_key :example_taggings, :example_tags, column: :tag_id, on_delete: :cascade
  end
end
