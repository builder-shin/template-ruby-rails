# frozen_string_literal: true

require "uri"

module JsonapiNegotiation
  extend ActiveSupport::Concern

  JSONAPI_MEDIA_TYPE = "application/vnd.api+json"
  WRITE_METHODS = %w[POST PUT PATCH DELETE].freeze
  TOKEN = /\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/
  QUALITY = /\A(?:0(?:\.\d{0,3})?|1(?:\.0{0,3})?)\z/
  URI_LIST = /\A[^\s"]+(?: [^\s"]+)*\z/

  included do
    before_action :negotiate_jsonapi_request
  end

  private

  def negotiate_jsonapi_request
    validate_jsonapi_accept!
    return unless WRITE_METHODS.include?(request.request_method) && jsonapi_body.bytesize.positive?

    validate_jsonapi_content_type!
    validate_jsonapi_document!
  end

  def validate_jsonapi_accept!
    accept = request.headers["Accept"].to_s
    return if accept.strip.empty?

    qualities = Hash.new { |hash, key| hash[key] = [] }
    entries = split_quoted(accept, ",")
    entries&.each do |entry|
      parsed = parse_parameterized_value(entry)
      next unless parsed

      media_range, parameters = parsed
      specificity = { JSONAPI_MEDIA_TYPE => 2, "application/*" => 1, "*/*" => 0 }[media_range]
      next unless specificity

      if media_range == JSONAPI_MEDIA_TYPE
        qualities[specificity] << jsonapi_accept_quality(parameters)
      else
        quality = parameters.fetch("q", "1")
        qualities[specificity] << quality.to_f if parameters.keys.all? { |name| name == "q" } && QUALITY.match?(quality)
      end
    end

    accepted = [ 2, 1, 0 ].find { |specificity| qualities.key?(specificity) }
    return if accepted && qualities[accepted].max.positive?

    raise JsonApiError.new(
      status: 406,
      code: "NOT_ACCEPTABLE",
      source: { parameter: "Accept" }
    )
  end

  def validate_jsonapi_content_type!
    parsed = parse_parameterized_value(request.headers["Content-Type"].to_s.strip)
    valid = parsed && parsed.first == JSONAPI_MEDIA_TYPE && valid_content_type_parameters?(parsed.last)
    return if valid

    raise JsonApiError.new(
      status: 415,
      code: "UNSUPPORTED_MEDIA_TYPE",
      source: { parameter: "Content-Type" }
    )
  end

  def validate_jsonapi_document!
    document = JSON.parse(jsonapi_body)
    return if document.is_a?(Hash) && document.key?("data")

    raise JsonApiError.new(
      status: 400,
      code: "INVALID_JSONAPI_DOCUMENT",
      source: { pointer: "/data" }
    )
  rescue JSON::ParserError
    raise JsonApiError.new(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
  end

  def jsonapi_body
    @jsonapi_body ||= request.raw_post
  end

  def parse_parameterized_value(value)
    parts = split_quoted(value, ";")
    return unless parts&.any?

    media_type = parts.shift.strip.downcase
    return if media_type.empty?

    parameters = {}
    parts.each do |raw_parameter|
      parameter = raw_parameter.lstrip
      return unless parameter.include?("=")

      raw_name, raw_value = parameter.split("=", 2)
      return unless raw_name == raw_name.strip && raw_value == raw_value.strip

      name = raw_name.downcase
      return unless TOKEN.match?(name) && valid_parameter_value?(raw_value) && !parameters.key?(name)

      parameters[name] = raw_value
    end
    [ media_type, parameters ]
  end

  def valid_parameter_value?(value)
    TOKEN.match?(value) || (value.start_with?('"') && value.end_with?('"') && !value[1...-1].include?('"'))
  end

  def jsonapi_accept_quality(parameters)
    return 0.0 unless (parameters.keys - %w[ext profile q]).empty?
    return 0.0 if parameters.key?("ext")
    return 0.0 if parameters.key?("profile") && !valid_uri_list_parameter?(parameters.fetch("profile"))

    quality = parameters.fetch("q", "1")
    QUALITY.match?(quality) ? quality.to_f : 0.0
  end

  def valid_content_type_parameters?(parameters)
    return false unless (parameters.keys - %w[ext profile]).empty?
    return false if parameters.key?("ext")

    !parameters.key?("profile") || valid_uri_list_parameter?(parameters.fetch("profile"))
  end

  def valid_uri_list_parameter?(raw_value)
    return false unless raw_value.start_with?('"') && raw_value.end_with?('"')

    value = raw_value[1...-1]
    return false unless URI_LIST.match?(value)

    value.split(" ").all? { |uri| URI.parse(uri).absolute? }
  rescue URI::InvalidURIError
    false
  end

  def split_quoted(value, delimiter)
    parts = [ +"" ]
    quoted = false
    escaped = false

    value.each_char do |character|
      if escaped
        parts.last << character
        escaped = false
      elsif quoted && character == "\\"
        parts.last << character
        escaped = true
      elsif character == '"'
        parts.last << character
        quoted = !quoted
      elsif character == delimiter && !quoted
        parts << +""
      else
        parts.last << character
      end
    end

    parts unless quoted || escaped
  end
end
