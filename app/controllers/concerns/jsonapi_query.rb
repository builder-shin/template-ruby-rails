# frozen_string_literal: true

require "uri"

# JSON:API 조회 파라미터의 concern 진입점.
#
# 파싱과 scope 적용은 `Jsonapi::QueryParser`가, 쿼리 문자열 디코딩과 형태 충돌
# 판정은 `Jsonapi::RawQuery`가, 페이지네이션은 `Jsonapi::Pagination`이 소유한다.
# 여기 남은 것은 Rails 콜백에 붙는 진입점과 액션별 검증뿐이다.
module JsonapiQuery
  extend ActiveSupport::Concern

  included do
    before_action :raise_pending_jsonapi_query_shape_conflict
    before_action :validate_jsonapi_action_query!
  end

  private

  def process_action(*)
    prepare_jsonapi_query_shape_conflict
    super
  end

  def jsonapi_query(scope)
    Jsonapi::QueryParser.new(
      scope: scope,
      request: request,
      action_params: -> { params },
      contract: query_contract,
      model: klass
    ).call
  end

  def prepare_jsonapi_query_shape_conflict
    return unless respond_to?(:query_contract, true)

    conflict, sanitized_pairs = Jsonapi::RawQuery.sanitize_shape_conflicts(Jsonapi::RawQuery.decode(request.query_string))
    return unless conflict

    @pending_jsonapi_query_shape_conflict = conflict
    request.set_header("QUERY_STRING", URI.encode_www_form(sanitized_pairs))
    request.delete_header("action_dispatch.request.query_parameters")
    request.delete_header("action_dispatch.request.parameters")
    request.instance_variable_set(:@filtered_parameters, nil)
    request.instance_variable_set(:@filtered_path, nil)
  rescue ArgumentError
    nil
  end

  def raise_pending_jsonapi_query_shape_conflict
    return unless action_name == "index" && respond_to?(:query_contract, true)
    return unless @pending_jsonapi_query_shape_conflict

    code, parameter = @pending_jsonapi_query_shape_conflict
    raise JsonApiError.new(status: 400, code: code, source: { parameter: parameter })
  end

  def validate_jsonapi_action_query!
    return unless respond_to?(:jsonapi_query_mode, true)

    pairs = Jsonapi::RawQuery.decode(request.query_string)
    return if pairs.empty? || jsonapi_query_mode == :collection

    if jsonapi_query_mode == :include_only
      validate_include_only_query!(pairs)
      return
    end

    parameter = pairs.first.first
    raise JsonApiError.new(
      status: 400,
      code: "INVALID_QUERY_PARAMETER",
      source: { parameter: parameter }
    )
  rescue ArgumentError
    raise JsonApiError.new(
      status: 400,
      code: "INVALID_QUERY_PARAMETER",
      source: { parameter: request.query_string }
    )
  end

  def validate_include_only_query!(pairs)
    seen_include = false
    pairs.each do |parameter, value|
      family = parameter.split("[", 2).first
      unless parameter == "include" && !seen_include
        code = {
          "filter" => "INVALID_FILTER",
          "sort" => "INVALID_SORT",
          "include" => "INVALID_INCLUDE",
          "page" => "INVALID_PAGE"
        }.fetch(family, "INVALID_QUERY_PARAMETER")
        raise JsonApiError.new(status: 400, code: code, source: { parameter: parameter })
      end

      seen_include = true
      next if value.empty?

      paths = value.split(",", -1)
      unless paths.any? && paths.none?(&:empty?) && (paths - query_contract.fetch(:includes)).empty?
        raise JsonApiError.new(status: 400, code: "INVALID_INCLUDE", source: { parameter: parameter })
      end
    end
  end
end
