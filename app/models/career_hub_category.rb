class CareerHubCategory < ApplicationRecord
  # Associations
  belongs_to :parent, class_name: 'CareerHubCategory', optional: true
  has_many :children, class_name: 'CareerHubCategory', foreign_key: :parent_id, dependent: :nullify

  has_many :communities_as_category, class_name: 'CareerHubCommunity', foreign_key: :category_id
  has_many :communities_as_subcategory, class_name: 'CareerHubCommunity', foreign_key: :subcategory_id

  # Validations
  validates :category_idx, presence: true, uniqueness: true
  validates :key, presence: true, uniqueness: true
  validates :level, presence: true
  validates :name, presence: true
  validates :display_order, presence: true
end
