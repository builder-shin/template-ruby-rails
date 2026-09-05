# frozen_string_literal: true

require "uri"

# JSON:API 조회 파라미터의 concern 진입점.
#
# 파싱과 scope 적용은 `Jsonapi::QueryParser`가, 쿼리 문자열 디코딩과 형태 충돌
# 판정은 `Jsonapi::RawQuery`가, 페이지네이션(offset·cursor 링크 조립)은
# `Jsonapi::Pagination`이, keyset 커서의 인코딩·디코딩은 `Jsonapi::Cursor`가
# 소유한다. 여기 남은 것은 Rails 콜백에 붙는 진입점과 액션별 검증뿐이다.
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

    mode = jsonapi_query_mode
    pairs = Jsonapi::RawQuery.decode(request.query_string)

    # related_collection은 pairs가 비어도(기본 페이지) 돌려야 한다 — render_related_resource가
    # 쓸 page[number]/page[size] 기본값을 ivar에 남겨야 하기 때문이다. 다른 모드는
    # 빈 쿼리에서 할 일이 없어 여기서 바로 끝난다.
    if mode == :related_collection
      validate_related_collection_query!(pairs)
      return
    end

    return if pairs.empty? || mode == :collection

    if mode == :include_only
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
      unless parameter == "include" && !seen_include
        raise_jsonapi_family_error!(parameter)
      end

      seen_include = true
      next if value.empty?

      paths = value.split(",", -1)
      unless paths.any? && paths.none?(&:empty?) && (paths - query_contract.fetch(:includes)).empty?
        raise JsonApiError.new(status: 400, code: "INVALID_INCLUDE", source: { parameter: parameter })
      end
    end
  end

  # 정본(FastAPI `parse_page_query` / 스펙 8.2)과 같은 계약: to-many related-resource
  # URL은 page[number]·page[size]만 받는다. page[totals]도 여기서는 거부한다 —
  # 이 라우트는 총 개수를 항상 내므로 켜고 끌 것이 없다.
  #
  # before_action에서 한 번만 파싱해 ivar에 남긴다. render_related_resource가 같은
  # 쿼리 문자열을 다시 파싱하지 않게 하기 위해서다.
  def validate_related_collection_query!(pairs)
    page_number = 1
    page_size = Jsonapi::Pagination::DEFAULT_PAGE_SIZE
    seen_page_parameters = []

    pairs.each do |parameter, value|
      raise_jsonapi_family_error!(parameter) unless %w[page[number] page[size]].include?(parameter)

      if seen_page_parameters.include?(parameter)
        raise JsonApiError.new(status: 400, code: "INVALID_PAGE", source: { parameter: parameter })
      end
      seen_page_parameters << parameter

      parsed_value = parse_related_collection_page_integer!(value, parameter)
      if parameter == "page[number]"
        page_number = parsed_value
      else
        page_size = [ parsed_value, Jsonapi::Pagination::MAX_PAGE_SIZE ].min
      end
    end

    if (page_number - 1) * page_size > Jsonapi::Pagination::MAX_SQL_INTEGER
      raise JsonApiError.new(status: 400, code: "INVALID_PAGE", source: { parameter: "page[number]" })
    end

    @related_collection_page_number = page_number
    @related_collection_page_size = page_size
  end

  def parse_related_collection_page_integer!(raw_value, parameter)
    value = Jsonapi::Pagination.parse_positive_integer(raw_value)
    return value if value

    raise JsonApiError.new(status: 400, code: "INVALID_PAGE", source: { parameter: parameter })
  end

  # `validate_include_only_query!`와 `validate_related_collection_query!`가 같이 쓰는
  # 파라미터 패밀리 → 에러 코드 매핑. `Jsonapi::RawQuery`가 형태 충돌 판정에 쓰는 것과
  # 같은 매핑이라 여기서 새로 정의하지 않고 그대로 재사용한다.
  def raise_jsonapi_family_error!(parameter)
    family = parameter.split("[", 2).first
    code = Jsonapi::RawQuery::ERROR_CODE_BY_FAMILY.fetch(family, "INVALID_QUERY_PARAMETER")
    raise JsonApiError.new(status: 400, code: code, source: { parameter: parameter })
  end
end
