# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :negotiate_jsonapi_request

  def live
    head :ok
  end

  def ready
    ActiveRecord::Base.connection.select_value("SELECT 1")
    head :ok
  rescue ActiveRecord::ActiveRecordError, PG::Error
    head :service_unavailable
  end
end
