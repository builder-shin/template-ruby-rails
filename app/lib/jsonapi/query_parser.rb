# frozen_string_literal: true

require "time"
require "set"

module Jsonapi
  QueryResult = Data.define(:scope, :includes, :total_count, :links, :include_requested)

  # JSON:API 조회 파라미터를 파싱해 scope에 적용한다.
  #
  # 무엇을 질의할 수 있는지는 컨트롤러의 `query_contract`가 정하고, 이 클래스는
  # 그 선언을 해석만 한다. 사용자가 보낸 문자열은 선언의 키를 찾는 데만 쓰이고
  # SQL에 들어가는 것은 선언이 들고 있는 컬럼 이름이다.
  class QueryParser
    FILTER_PARAMETER = /\Afilter\[([^\[\]]+)\](?:\[([^\[\]]+)\])?\z/
    INTEGER = /\A[+-]?[0-9]+\z/
    UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i
    DATETIME_WITH_OFFSET = /\A\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})\z/
    INT4_MAX = (2**31) - 1
    INT8_MAX = (2**63) - 1

    FilterClause = Data.define(:name, :operator, :value)
    SortTerm = Data.define(:name, :descending)
    private_constant :FilterClause, :SortTerm

    def initialize(scope:, request:, action_params:, contract:, model:)
      @scope = scope
      @request = request
      @action_params = action_params
      @model = model
      @filters = normalize_filters(contract.fetch(:filters))
      @sorts = normalize_sorts(contract.fetch(:sorts))
      @include_contract = contract.fetch(:includes).map(&:to_s).freeze
      @default_sort = contract.fetch(:default_sort).freeze
      @tie_breaker = contract.fetch(:tie_breaker).freeze
      @parsed_filters = []
      @seen_filters = Set.new
      @sort_terms = nil
      @includes = nil
      @page_number = 1
      @page_size = contract.fetch(:default_page_size)
      @seen_page_parameters = Set.new
      @totals = false
      @cursor_raw = nil
      @cursor_before = false
    end

    def call
      @raw_pairs = parse_raw_pairs
      if (conflict = Jsonapi::RawQuery.shape_conflict(@raw_pairs))
        invalid_query!(*conflict)
      end
      @raw_pairs.each { |parameter, value| parse_parameter(parameter, value) }
      validate_action_controller_parameters!
      validate_cursor_mode!
      validate_page_offset! if @cursor_raw.nil?

      filtered = apply_filters(@scope)
      total_count = @totals ? filtered.unscope(:order).count : nil

      if @cursor_raw.nil?
        page_records, has_more = offset_page(apply_sort(filtered))
        links = Pagination.links(
          request: @request,
          raw_pairs: @raw_pairs,
          page_number: @page_number,
          page_size: @page_size,
          has_more: has_more,
          total_count: total_count,
          totals: @totals
        )
      else
        page_records, has_more = cursor_page(filtered)
        links = Pagination.cursor_links(
          request: @request,
          raw_pairs: @raw_pairs,
          page_size: @page_size,
          totals: @totals,
          records: page_records,
          terms: effective_sort_terms,
          attributes: sort_attributes,
          has_more: has_more,
          before: @cursor_before,
          raw_cursor: @cursor_raw
        )
      end

      requested_includes = @includes || []
      page_records = preload_includes(page_records, requested_includes) if requested_includes.any?

      QueryResult.new(
        scope: page_records,
        includes: requested_includes,
        total_count: total_count,
        links: links,
        include_requested: !@includes.nil?
      )
    end

    private

    def normalize_filters(declarations)
      declarations.to_h do |name, declaration|
        [
          name.to_s,
          {
            attribute: declaration.fetch(:attribute),
            type: declaration.fetch(:type),
            operators: declaration.fetch(:operators).map(&:to_s).freeze
          }.freeze
        ]
      end.freeze
    end

    def normalize_sorts(declarations)
      declarations.to_h do |name, declaration|
        [
          name.to_s,
          { attribute: declaration.fetch(:attribute), nullable: declaration.fetch(:nullable) }.freeze
        ]
      end.freeze
    end

    def parse_raw_pairs
      Jsonapi::RawQuery.decode(@request.query_string)
    rescue ArgumentError
      invalid_query!("INVALID_QUERY_PARAMETER", @request.query_string)
    end

    def parse_parameter(parameter, value)
      return parse_filter(parameter, value) if parameter.start_with?("filter")
      return parse_sort(parameter, value) if parameter.start_with?("sort")
      return parse_include(parameter, value) if parameter.start_with?("include")
      return parse_page(parameter, value) if parameter.start_with?("page")

      invalid_query!("INVALID_QUERY_PARAMETER", parameter)
    end

    def parse_filter(parameter, raw_value)
      match = FILTER_PARAMETER.match(parameter)
      invalid_query!("INVALID_FILTER", parameter) unless match

      name, requested_operator = match.captures
      operator = requested_operator || "exact"
      declaration = @filters[name]
      invalid_query!("INVALID_FILTER", parameter) unless declaration&.fetch(:operators)&.include?(operator)

      key = [ name, operator ]
      invalid_query!("INVALID_FILTER", parameter) if @seen_filters.include?(key)

      @seen_filters << key
      @parsed_filters << FilterClause.new(name, operator, parse_filter_value(name, operator, raw_value, parameter))
    end

    def parse_filter_value(name, operator, raw_value, parameter)
      invalid_query!("INVALID_FILTER", parameter) if raw_value.empty?

      if operator == "isNull"
        return true if raw_value == "true"
        return false if raw_value == "false"

        invalid_query!("INVALID_FILTER", parameter)
      end

      if operator == "in"
        values = raw_value.split(",", -1)
        invalid_query!("INVALID_FILTER", parameter) if values.empty? || values.any?(&:empty?)

        return values.map { |value| parse_scalar(name, value, parameter) }
      end

      parse_scalar(name, raw_value, parameter)
    end

    def parse_scalar(name, raw_value, parameter)
      @current_filter_name = name
      case @filters.fetch(name).fetch(:type)
      when :string then raw_value
      when :enum then parse_enum(raw_value, parameter)
      when :integer then parse_bounded_integer(raw_value, parameter, INT4_MAX)
      when :bigint then parse_bounded_integer(raw_value, parameter, INT8_MAX)
      when :uuid then parse_uuid(raw_value, parameter)
      when :datetime then parse_datetime(raw_value, parameter)
      else
        raise ArgumentError, "unsupported JSON:API filter type"
      end
    end

    def parse_enum(raw_value, parameter)
      enum_name = @filters.fetch(@current_filter_name).fetch(:attribute).to_s
      return raw_value if @model.defined_enums.fetch(enum_name, {}).key?(raw_value)

      invalid_query!("INVALID_FILTER", parameter)
    end

    def parse_bounded_integer(raw_value, parameter, maximum)
      invalid_query!("INVALID_FILTER", parameter) unless INTEGER.match?(raw_value)

      value = Integer(raw_value, 10)
      return value if (-maximum - 1..maximum).cover?(value)

      invalid_query!("INVALID_FILTER", parameter)
    rescue ArgumentError
      invalid_query!("INVALID_FILTER", parameter)
    end

    def parse_uuid(raw_value, parameter)
      return raw_value.downcase if UUID.match?(raw_value)

      invalid_query!("INVALID_FILTER", parameter)
    end

    def parse_datetime(raw_value, parameter)
      invalid_query!("INVALID_FILTER", parameter) unless DATETIME_WITH_OFFSET.match?(raw_value)

      Time.iso8601(raw_value)
    rescue ArgumentError
      invalid_query!("INVALID_FILTER", parameter)
    end

    def parse_sort(parameter, raw_value)
      invalid_query!("INVALID_SORT", parameter) unless parameter == "sort" && @sort_terms.nil?

      tokens = raw_value.split(",", -1)
      invalid_query!("INVALID_SORT", parameter) if tokens.empty? || tokens.any?(&:empty?)

      names = Set.new
      @sort_terms = tokens.map do |token|
        descending = token.start_with?("-")
        name = descending ? token.delete_prefix("-") : token
        invalid_query!("INVALID_SORT", parameter) unless @sorts.key?(name)
        invalid_query!("INVALID_SORT", parameter) if names.include?(name)

        names << name
        SortTerm.new(name, descending)
      end
    end

    def parse_include(parameter, raw_value)
      invalid_query!("INVALID_INCLUDE", parameter) unless parameter == "include" && @includes.nil?

      @includes = []
      return if raw_value.empty?

      tokens = raw_value.split(",", -1)
      invalid_query!("INVALID_INCLUDE", parameter) if tokens.empty? || tokens.any?(&:empty?)

      tokens.each do |path|
        invalid_query!("INVALID_INCLUDE", parameter) unless @include_contract.include?(path)

        @includes << path unless @includes.include?(path)
      end
    end

    def parse_page(parameter, raw_value)
      unless %w[page[number] page[size] page[totals] page[after] page[before]].include?(parameter) &&
             !@seen_page_parameters.include?(parameter)
        invalid_query!("INVALID_PAGE", parameter)
      end

      @seen_page_parameters << parameter

      case parameter
      when "page[totals]"
        @totals = parse_boolean(raw_value, parameter)
        return
      when "page[after]", "page[before]"
        # page[after]와 page[before]는 이름이 다르므로 위의 @seen_page_parameters
        # 검사가 "둘 다 왔다"를 잡지 못한다 — 커서 슬롯 자체가 이미 찼는지를 따로 본다.
        invalid_query!("INVALID_PAGE", parameter) unless @cursor_raw.nil?

        @cursor_raw = raw_value
        @cursor_before = parameter == "page[before]"
        return
      end

      value = parse_positive_integer(raw_value, parameter)
      if parameter == "page[number]"
        @page_number = value
      else
        @page_size = [ value, Pagination::MAX_PAGE_SIZE ].min
      end
    end

    def parse_boolean(raw_value, parameter)
      return true if raw_value == "true"
      return false if raw_value == "false"

      invalid_query!("INVALID_PAGE", parameter)
    end

    def parse_positive_integer(raw_value, parameter)
      value = Pagination.parse_positive_integer(raw_value)
      return value if value

      invalid_query!("INVALID_PAGE", parameter)
    end

    def validate_page_offset!
      return if (@page_number - 1) * @page_size <= Pagination::MAX_SQL_INTEGER

      invalid_query!("INVALID_PAGE", "page[number]")
    end

    # 커서 모드에서 막는 것 둘. 이유가 서로 다르다.
    #
    # 1. page[number]와의 동시 사용 — 두 페이지 개념이 한 요청에 있으면 어느 쪽을
    #    따를지 정할 수 없다.
    # 2. nullable 정렬 — keyset 비교에 NULL이 섞이면 비교가 unknown이 되어 행을
    #    조용히 건너뛴다.
    #
    # 왕복 불가 타입(세 번째 이유)은 여기서 정적으로 판정하지 않는다 — 경계 행을
    # 실제로 만날 때(`Pagination.boundary_cursor`) 그 값으로 판정한다.
    def validate_cursor_mode!
      return if @cursor_raw.nil?

      invalid_query!("INVALID_PAGE", "page[number]") if @seen_page_parameters.include?("page[number]")

      effective_sort_terms.each do |term|
        declaration = @sorts[term.name]
        next if declaration.nil? # tie breaker는 sorts에 없을 수 있다. id는 NOT NULL이다.

        invalid_query!("INVALID_PAGE", cursor_parameter) if declaration.fetch(:nullable)
      end
    end

    def cursor_parameter
      @cursor_before ? "page[before]" : "page[after]"
    end

    def validate_action_controller_parameters!
      families = @raw_pairs.map(&:first)
      validate_parameter_family!(families, "filter", ActionController::Parameters, "INVALID_FILTER")
      validate_parameter_family!(families, "page", ActionController::Parameters, "INVALID_PAGE")
      validate_parameter_family!(families, "sort", String, "INVALID_SORT")
      validate_parameter_family!(families, "include", String, "INVALID_INCLUDE")
    end

    def validate_parameter_family!(parameters, family, expected_class, code)
      return unless parameters.any? { |parameter| parameter == family || parameter.start_with?("#{family}[") }
      return if @action_params.call[family].is_a?(expected_class)

      invalid_query!(code, family)
    end

    def apply_filters(scope)
      @parsed_filters.reduce(scope) do |relation, filter|
        column = @model.arel_table[@filters.fetch(filter.name).fetch(:attribute)]
        relation.where(filter_predicate(column, filter))
      end
    end

    def filter_predicate(column, filter)
      case filter.operator
      when "exact"
        column.eq(filter.value)
      when "contains"
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(filter.value)}%"
        column.matches(pattern, "\\", true)
      when "gt"
        column.gt(filter.value)
      when "gte"
        column.gteq(filter.value)
      when "lt"
        column.lt(filter.value)
      when "lte"
        column.lteq(filter.value)
      when "in"
        column.in(filter.value)
      when "isNull"
        filter.value ? column.eq(nil) : column.not_eq(nil)
      else
        raise ArgumentError, "unsupported JSON:API filter operator"
      end
    end

    def apply_sort(scope)
      scope.reorder(*effective_sort_terms.map { |term| order_expression(term) })
    end

    # 사용자 정렬(없으면 기본 정렬)에 tie breaker를 더한 최종 정렬 term 목록.
    # offset 모드의 `apply_sort`와 커서 모드의 keyset 술어·링크 조립이 같은
    # 정렬을 봐야 하므로 하나로 뽑아 둔다 — 따로 계산하면 둘이 갈릴 수 있다.
    def effective_sort_terms
      terms = @sort_terms || default_sort_terms
      return terms if terms.any? { |term| term.name == @tie_breaker.fetch(:field) }

      [ *terms, tie_breaker_term ]
    end

    def default_sort_terms
      @default_sort.map { |entry| SortTerm.new(entry.fetch(:field), entry.fetch(:direction) == :desc) }
    end

    def tie_breaker_term
      SortTerm.new(@tie_breaker.fetch(:field), @tie_breaker.fetch(:direction) == :desc)
    end

    # tie breaker는 공개 `sorts` 표에 없어도 된다 — `id`가 그 경우다. 표에 없으면
    # 공개 이름을 그대로 컬럼 이름으로 쓴다. 그 값은 사용자 입력이 아니라 컨트롤러의
    # 선언이므로 SQL 식별자 자리에 그대로 들어가도 안전하다.
    def order_expression(term)
      attribute = @sorts.dig(term.name, :attribute) || term.name.to_sym
      column = @model.arel_table[attribute]
      term.descending ? column.desc : column.asc
    end

    # offset 모드: 요청 크기 +1행을 읽어 next 유무를 판정하고 그 한 행은 응답에서
    # 버린다. COUNT 없이 "다음 페이지가 있는가"에 답하는 방법이다.
    #
    # `limit`에만 +1을 얹는다 — page_size 쪽에 얹으면 offset 계산(`(page_number - 1)
    # * page_size`)까지 부풀어 2페이지부터 창이 밀린다.
    def offset_page(sorted)
      probed = Pagination.apply(sorted, page_number: @page_number, page_size: @page_size, limit: @page_size + 1).to_a
      has_more = probed.length > @page_size
      [ has_more ? probed.first(@page_size) : probed, has_more ]
    end

    # 커서 모드: OFFSET 없이 커서 위치 다음(또는 이전) 행을 keyset 술어로 직접 자른다.
    #
    # `page[before]`는 컬렉션을 거꾸로 걸어야 하므로 DB에는 역방향으로 정렬해
    # LIMIT으로 자르고, 응답 직전에 표시 순서로 되돌린다 — 정본의 `models.reverse()`와
    # 같은 자리다.
    def cursor_page(filtered)
      terms = effective_sort_terms
      attributes = sort_attributes
      scope = filtered

      unless @cursor_raw.empty?
        values = Cursor.decode(@cursor_raw, Cursor.signature(terms), cursor_parameter)
        scope = scope.where(
          Cursor.keyset_predicate(@model.arel_table, terms, attributes, values, before: @cursor_before)
        )
      end

      order = @cursor_before ? reversed_order(terms, attributes) : forward_order(terms, attributes)
      probed = scope.reorder(*order).limit(@page_size + 1).to_a
      has_more = probed.length > @page_size
      records = has_more ? probed.first(@page_size) : probed
      records = records.reverse if @cursor_before
      [ records, has_more ]
    end

    def sort_attributes
      effective_sort_terms.to_h do |term|
        [ term.name, @sorts.dig(term.name, :attribute) || term.name.to_sym ]
      end
    end

    def forward_order(terms, attributes)
      terms.map do |term|
        column = @model.arel_table[attributes.fetch(term.name)]
        term.descending ? column.desc : column.asc
      end
    end

    def reversed_order(terms, attributes)
      terms.map do |term|
        column = @model.arel_table[attributes.fetch(term.name)]
        term.descending ? column.asc : column.desc
      end
    end

    # probe가 relation을 배열로 만들었으므로 `includes`를 relation에 걸 수 없다.
    # 이미 가져온 레코드에 preloader를 직접 물린다 — N+1을 막는 것이 목적이고
    # 그 목적은 relation이든 배열이든 같다.
    def preload_includes(records, paths)
      ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: paths.map(&:to_sym)
      ).call
      records
    end

    def invalid_query!(code, parameter)
      raise JsonApiError.new(
        status: 400,
        code: code,
        source: { parameter: parameter }
      )
    end
  end
end
