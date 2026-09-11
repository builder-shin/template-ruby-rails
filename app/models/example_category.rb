# frozen_string_literal: true

class ExampleCategory < ApplicationRecord
  has_many :examples, foreign_key: :category_id

  validates :name, presence: true, uniqueness: true, length: { maximum: 200 }
end
