# frozen_string_literal: true

class ExampleTagSerializer < ApplicationSerializer
  set_key_transform :camel_lower
  set_type :example_tags
  set_id { |tag| tag.id.to_s.downcase }

  attributes :name

  # 이 링크가 가리킬 URL이 실제로 있다 — `GET /api/v1/tags/{id}`.
  # JSON:API type(`exampleTags`)이 URL 경로(`/api/v1/tags`)와 다른 것은
  # 의도된 결정이다.
  link :self do |tag|
    "/api/v1/tags/#{tag.id.to_s.downcase}"
  end
end
