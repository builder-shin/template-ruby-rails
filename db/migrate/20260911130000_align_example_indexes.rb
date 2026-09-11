# frozen_string_literal: true

class AlignExampleIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :examples, [ :created_at, :id ], order: { created_at: :desc, id: :asc }, name: "index_examples_on_created_at_and_id"
    add_index :examples, [ :title, :id ], name: "index_examples_on_title_and_id"
  end
end
