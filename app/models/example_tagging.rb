# frozen_string_literal: true

class ExampleTagging < ApplicationRecord
  self.primary_key = [ :example_id, :tag_id ]

  belongs_to :example
  belongs_to :example_tag, foreign_key: :tag_id

  validates :tag_id, uniqueness: { scope: :example_id }
end
