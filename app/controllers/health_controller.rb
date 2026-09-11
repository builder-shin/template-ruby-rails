# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :negotiate_jsonapi_request

  def live
    render_health_document
  end

  def ready
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render_health_document
  rescue ActiveRecord::ActiveRecordError, PG::Error
    raise JsonApiError.new(status: 503, code: "INTERNAL_SERVER_ERROR")
  end

  private

  def render_health_document
    response.status = 200
    response.headers["Content-Type"] = JsonapiErrors::JSONAPI_MEDIA_TYPE
    self.response_body = JSON.generate(
      data: nil,
      meta: { status: "ok" },
      jsonapi: { version: "1.1" }
    )
  end
end
