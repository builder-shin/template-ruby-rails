# frozen_string_literal: true

class ExampleTagSerializer < ApplicationSerializer
  set_key_transform :camel_lower
  set_type :example_tags
  set_id { |tag| tag.id.to_s.downcase }

  attributes :name
end
