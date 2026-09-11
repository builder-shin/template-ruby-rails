# frozen_string_literal: true

class IndexTagRelationship < ActiveRecord::Migration[8.1]
  def change
    add_index :example_taggings, :tag_id, name: "index_example_taggings_on_tag_id"
  end
end
