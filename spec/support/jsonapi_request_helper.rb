# frozen_string_literal: true

module JsonapiRequestHelper
  JSONAPI_MEDIA_TYPE = "application/vnd.api+json"

  def jsonapi_headers(language: "ko")
    {
      "ACCEPT" => JSONAPI_MEDIA_TYPE,
      "CONTENT_TYPE" => JSONAPI_MEDIA_TYPE,
      "ACCEPT_LANGUAGE" => language
    }
  end

  def parsed_body
    JSON.parse(response.body)
  end
end
