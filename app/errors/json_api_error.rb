# frozen_string_literal: true

class JsonApiError < StandardError
  ERROR_CODES = %w[
    NOT_ACCEPTABLE
    UNSUPPORTED_MEDIA_TYPE
    INVALID_JSONAPI_DOCUMENT
    INVALID_QUERY_PARAMETER
    INVALID_FILTER
    INVALID_SORT
    INVALID_INCLUDE
    INVALID_PAGE
    RESOURCE_NOT_FOUND
    RELATIONSHIP_RESOURCE_NOT_FOUND
    TYPE_MISMATCH
    ID_MISMATCH
    CLIENT_GENERATED_ID_UNSUPPORTED
    RESOURCE_CONFLICT
    VALIDATION_ERROR
    INTERNAL_SERVER_ERROR
    HTTP_ERROR
    AUTHENTICATION_REQUIRED
    INVALID_TOKEN
    TOKEN_EXPIRED
    USER_INACTIVE
    EMAIL_ALREADY_REGISTERED
    INVALID_CREDENTIALS
    TOKEN_REVOKED
  ].freeze

  attr_reader :status, :code, :source, :context

  def initialize(status:, code:, source: nil, context: {})
    @status = Integer(status)
    @code = code.to_s
    # :header가 빠져 있으면 정본 가드가 모든 인증 오류에 싣는
    # source_header="Authorization"이 조용히 사라진다 — source.header는 JSON:API
    # 1.1이 정의한 멤버다(spec/errors/json_api_error_spec.rb가 이 슬라이스를 고정한다).
    @source = source&.to_h&.symbolize_keys&.slice(:pointer, :parameter, :header)&.freeze
    @context = context.to_h.symbolize_keys.freeze

    raise ArgumentError, "status must be an HTTP error status" unless (400..599).cover?(@status)
    raise ArgumentError, "unknown JSON:API error code" unless ERROR_CODES.include?(@code)

    @code.freeze
    super(@code)
  end
end
