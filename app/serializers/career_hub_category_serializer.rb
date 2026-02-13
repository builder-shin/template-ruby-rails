# frozen_string_literal: true

class CareerHubCategorySerializer < ApplicationSerializer
  attributes :id, :category_idx, :key, :level, :name, :display_order,
             :parent_id, :parent_idx, :active, :visible,
             :description, :color, :icon_name, :icon_url,
             :created_at, :updated_at

  belongs_to :parent, serializer: :career_hub_category
  has_many :children
  has_many :communities_as_category
  has_many :communities_as_subcategory
end
