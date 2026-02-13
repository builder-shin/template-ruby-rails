# frozen_string_literal: true

class CountrySerializer < ApplicationSerializer
  attributes :id, :name, :created_at, :updated_at

  has_many :profiles
end
