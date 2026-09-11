class ApplicationController < ActionController::API
  include JsonapiErrors
  include JsonapiNegotiation

  skip_before_action :negotiate_jsonapi_request, only: :method_not_allowed

  ALLOWED_METHODS = [
    [ %r{\A/health/(?:live|ready)\z}, "GET" ],
    [ %r{\A/api/schema\z}, "GET" ],
    [ %r{\A/api/v1/auth/(?:register|login|refresh|logout)\z}, "POST" ],
    [ %r{\A/api/v1/examples\z}, "GET, POST" ],
    [ %r{\A/api/v1/examples/[^/]+\z}, "GET, PATCH, PUT, DELETE" ],
    [ %r{\A/api/v1/examples/[^/]+/relationships/category\z}, "GET, PATCH" ],
    [ %r{\A/api/v1/examples/[^/]+/category\z}, "GET" ],
    [ %r{\A/api/v1/examples/[^/]+/relationships/tags\z}, "GET, POST, PATCH, DELETE" ],
    [ %r{\A/api/v1/examples/[^/]+/tags\z}, "GET" ],
    [ %r{\A/api/v1/users/me\z}, "GET" ],
    [ %r{\A/api/v1/(?:categories|tags)\z}, "GET" ],
    [ %r{\A/api/v1/(?:categories|tags)/[^/]+\z}, "GET" ]
  ].freeze
  private_constant :ALLOWED_METHODS

  def route_not_found
    raise JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
  end

  def method_not_allowed
    response.headers["Allow"] = ALLOWED_METHODS.find { |pattern, _| pattern.match?(request.path) }&.last
    raise JsonApiError.new(status: 405, code: "HTTP_ERROR")
  end
end
