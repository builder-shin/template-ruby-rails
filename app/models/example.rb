# frozen_string_literal: true

class Example < ApplicationRecord
  enum :status, { draft: "draft", active: "active", archived: "archived" }, prefix: true

  belongs_to :category, class_name: "ExampleCategory", optional: true
  has_many :example_taggings, dependent: :destroy
  has_many :tags, through: :example_taggings, source: :example_tag

  validates :title, presence: true, length: { maximum: 200 }
  validates :score, numericality: { only_integer: true, in: 0..100 }
end
