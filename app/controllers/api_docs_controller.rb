# frozen_string_literal: true

require "yaml"

class ApiDocsController < ApplicationController
  skip_before_action :negotiate_jsonapi_request

  def schema
    document = YAML.safe_load_file(Rails.root.join("swagger/v1/swagger.yaml"), aliases: true)
    render json: document
  end
end
