# frozen_string_literal: true

class ExampleCategorySerializer < ApplicationSerializer
  set_key_transform :camel_lower
  set_type :example_categories
  set_id { |category| category.id.to_s.downcase }

  attributes :name
end
