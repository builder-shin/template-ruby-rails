# frozen_string_literal: true

require "uri"

module JsonapiNegotiation
  extend ActiveSupport::Concern

  JSONAPI_MEDIA_TYPE = "application/vnd.api+json"
  JSONAPI_VERSION = { "version" => "1.1" }.freeze
  WRITE_METHODS = %w[POST PUT PATCH DELETE].freeze
  TOKEN = /\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/
  QUALITY = /\A(?:0(?:\.\d{0,3})?|1(?:\.0{0,3})?)\z/
  URI_LIST = /\A[^\s"]+(?: [^\s"]+)*\z/

  included do
    before_action :negotiate_jsonapi_request
    after_action :strip_jsonapi_response_media_type_parameters
    after_action :append_jsonapi_version
  end

  private

  def process_action(*)
    unless jsonapi_request_body_expected?
      # Rails merges body parameters when filters first access params. Supply the
      # empty body promised by bodyless routes before that lazy parser runs.
      request.set_header("action_dispatch.request.request_parameters", {})
      request.delete_header("action_dispatch.request.parameters")
    end
    super
  end

  def jsonapi_request_body_expected?
    %w[POST PUT PATCH].include?(request.request_method) ||
      (request.delete? && request.path.include?("/relationships/"))
  end

  def append_jsonapi_version
    return if response.body.blank?
    return unless response.headers["Content-Type"].to_s.split(";").first.casecmp?(JSONAPI_MEDIA_TYPE)

    document = JSON.parse(response.body)
    return unless document.is_a?(Hash)

    document["jsonapi"] ||= JSONAPI_VERSION
    self.response_body = JSON.generate(document)
    response.headers.delete("Content-Length")
  rescue JSON::ParserError
    nil
  end

  def negotiate_jsonapi_request
    if jsonapi_request_body_expected?
      validate_jsonapi_content_type!
      validate_jsonapi_document!
    end
    validate_jsonapi_accept!
  end

  # JSON:API 1.1 §5.1은 응답의 미디어 타입에 파라미터를 붙이는 것을 금지한다.
  # 그런데 `render jsonapi:`(jsonapi-rails 렌더러)는 Rails의 표준 `content_type=`
  # setter를 타고, 그 setter는 charset이 비어 있으면 기본값을 채워 넣는다 —
  # 결과가 `application/vnd.api+json; charset=utf-8`이다. **같은 문자열을 요청에
  # 실으면 바로 위의 `validate_jsonapi_content_type!`이 415로 거절한다.** 즉 읽기
  # 응답이 자기 API가 받지 않는 값을 광고하고, 받은 Content-Type을 그대로 되돌려
  # 보내는 클라이언트나 SDK 생성기가 그 값을 쓰면 쓰기가 415로 막힌다.
  #
  # 쓰기·오류 경로(`CrudActions#render_jsonapi_payload`,
  # `AuthController#render_jsonapi_document`, `JsonapiErrors#render_jsonapi_errors`,
  # `CrudActions#render_jsonapi_query_index`)는 헤더 문자열을 직접 대입해 이 setter를
  # 우회한다. 읽기 경로는 렌더러가 응답을 조립하므로 우회할 자리가 없다.
  #
  # 대입을 자리마다 되풀이하지 않고 여기서 한 번에 정규화하는 이유: `render jsonapi:`를
  # 쓰면서 헤더를 다시 대입하지 않는 자리가 **네 곳**이었다(실측) —
  # `CrudActions#index`의 레거시(query_contract 없는) 경로 · `#show` · `#new` ·
  # `UsersController#me`. 자리마다 고치면 다음에 추가되는 `render jsonapi:`에서
  # 그대로 다시 갈린다. 미디어 타입 정책을 소유한 이 concern이 그 갈림을 구조적으로
  # 없앤다.
  #
  # 정본도 같은 값을 강제한다 — `app/jsonapi/responses.py:13,92`가 파라미터 없는
  # `JSONAPI_MEDIA_TYPE`을 응답 헤더에 직접 대입하고, 정본 테스트는 `==`로 단언한다.
  #
  # 204처럼 본문이 없는 응답은 Content-Type 자체가 없으므로 그대로 둔다.
  def strip_jsonapi_response_media_type_parameters
    header = response.headers["Content-Type"]
    return if header.blank?
    return unless header.split(";").first.to_s.strip.casecmp?(JSONAPI_MEDIA_TYPE)

    response.headers["Content-Type"] = JSONAPI_MEDIA_TYPE
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
        quality = jsonapi_accept_quality(parameters)
        qualities[specificity] << quality unless quality.nil?
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
      source: { header: "Accept" }
    )
  end

  def validate_jsonapi_content_type!
    parsed = parse_parameterized_value(request.headers["Content-Type"].to_s.strip)
    valid = parsed && parsed.first == JSONAPI_MEDIA_TYPE && valid_content_type_parameters?(parsed.last)
    return if valid

    raise JsonApiError.new(
      status: 415,
      code: "UNSUPPORTED_MEDIA_TYPE",
      source: { header: "Content-Type" }
    )
  end

  def validate_jsonapi_document!
    JSON.parse(jsonapi_body)
  rescue JSON::ParserError
    raise JsonApiError.new(status: 422, code: "VALIDATION_ERROR")
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
    quality = parameters.fetch("q", "1")
    return unless QUALITY.match?(quality)

    return 0.0 unless (parameters.keys - %w[ext profile q]).empty?
    return 0.0 if parameters.key?("ext")
    quality.to_f
  end

  def valid_content_type_parameters?(parameters)
    return false unless (parameters.keys - %w[ext profile]).empty?
    return false if parameters.key?("ext")

    true
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
