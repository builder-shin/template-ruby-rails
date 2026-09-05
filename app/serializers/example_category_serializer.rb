# frozen_string_literal: true

class ExampleCategorySerializer < ApplicationSerializer
  set_key_transform :camel_lower
  set_type :example_categories
  set_id { |category| category.id.to_s.downcase }

  attributes :name

  # 이 링크가 가리킬 URL이 실제로 있다 — `GET /api/v1/categories/{id}`.
  # JSON:API type(`exampleCategories`)이 URL 경로(`/api/v1/categories`)와 다른 것은
  # 의도된 결정이다.
  link :self do |category|
    "/api/v1/categories/#{category.id.to_s.downcase}"
  end
end
