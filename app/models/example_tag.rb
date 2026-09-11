# frozen_string_literal: true

class ExampleTag < ApplicationRecord
  has_many :example_taggings, foreign_key: :tag_id, dependent: :destroy
  has_many :examples, through: :example_taggings

  validates :name, presence: true, uniqueness: true, length: { maximum: 200 }
end
