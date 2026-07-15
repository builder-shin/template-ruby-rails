class ApplicationController < ActionController::API
  include JsonapiErrors
  include JsonapiNegotiation

  def route_not_found
    raise JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
  end
end
