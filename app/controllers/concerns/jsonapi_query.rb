# frozen_string_literal: true

require "time"
require "uri"
require "set"

module JsonapiQuery
  extend ActiveSupport::Concern

  DEFAULT_PAGE_SIZE = 20
  MAX_PAGE_SIZE = 100
  MAX_SQL_INTEGER = (2**63) - 1
  MAX_SCORE_INTEGER = (2**31) - 1
  FILTER_PARAMETER = /\Afilter\[([^\[\]]+)\](?:\[([^\[\]]+)\])?\z/
  POSITIVE_INTEGER = /\A[0-9]+\z/
  INTEGER = /\A[+-]?[0-9]+\z/
  UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i
  DATETIME_WITH_OFFSET = /\A\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})\z/

  FILTER_FIELDS = {
    "title" => { attribute: :title, type: :string },
    "status" => { attribute: :status, type: :status },
    "score" => { attribute: :score, type: :integer },
    "category.id" => { attribute: :category_id, type: :uuid },
    "createdAt" => { attribute: :created_at, type: :datetime }
  }.freeze
  SORT_FIELDS = {
    "title" => :title,
    "status" => :status,
    "score" => :score,
    "createdAt" => :created_at,
    "updatedAt" => :updated_at,
    "id" => :id
  }.freeze

  Result = Data.define(:scope, :includes, :total_count, :links, :include_requested)
  FilterClause = Data.define(:name, :operator, :value)
  SortTerm = Data.define(:name, :descending)
  private_constant :FilterClause, :SortTerm

  private

  def process_action(*)
    super
  rescue ActionController::BadRequest
    conflict = jsonapi_raw_shape_conflict
    raise unless respond_to?(:query_contract, true) && conflict

    code, parameter = conflict
    render_jsonapi_error(
      JsonApiError.new(status: 400, code: code, source: { parameter: parameter })
    )
  end

  def jsonapi_query(scope)
    Parser.new(
      scope: scope,
      request: request,
      action_params: -> { params },
      contract: query_contract,
      model: klass
    ).call
  end

  def jsonapi_raw_shape_conflict
    RawQuery.shape_conflict(RawQuery.decode(request.query_string))
  rescue ArgumentError
    nil
  end

  class RawQuery
    ERROR_CODE_BY_FAMILY = {
      "filter" => "INVALID_FILTER",
      "sort" => "INVALID_SORT",
      "include" => "INVALID_INCLUDE",
      "page" => "INVALID_PAGE"
    }.freeze
    PARAMETER = /\A([^\[\]]+)((?:\[[^\[\]]*\])*)\z/
    SEGMENT = /\[([^\[\]]*)\]/

    class << self
      def decode(query_string)
        return [] if query_string.empty?

        pairs = URI.decode_www_form(query_string, Encoding::UTF_8)
        raise ArgumentError unless pairs.flatten.all?(&:valid_encoding?)

        pairs
      end

      def shape_conflict(pairs)
        seen = []
        pairs.each do |parameter, _|
          segments = parameter_segments(parameter)
          next unless segments && ERROR_CODE_BY_FAMILY.key?(segments.first)

          if seen.any? { |prior| strict_prefix?(prior, segments) || strict_prefix?(segments, prior) }
            return [ ERROR_CODE_BY_FAMILY.fetch(segments.first), parameter ]
          end
          seen << segments
        end
        nil
      end

      private

      def parameter_segments(parameter)
        match = PARAMETER.match(parameter)
        return unless match

        [ match[1], *match[2].scan(SEGMENT).flatten ]
      end

      def strict_prefix?(prefix, value)
        prefix.length < value.length && value.first(prefix.length) == prefix
      end
    end
  end
  private_constant :RawQuery

  class Parser
    def initialize(scope:, request:, action_params:, contract:, model:)
      @scope = scope
      @request = request
      @action_params = action_params
      @model = model
      @filter_contract = contract.fetch(:filters).to_h do |name, operators|
        [ name.to_s, operators.map(&:to_s).freeze ]
      end.freeze
      @sort_contract = contract.fetch(:sorts).map(&:to_s).freeze
      @include_contract = contract.fetch(:includes).map(&:to_s).freeze
      @parsed_filters = []
      @seen_filters = Set.new
      @sort_terms = nil
      @includes = nil
      @page_number = 1
      @page_size = DEFAULT_PAGE_SIZE
      @seen_page_parameters = Set.new
    end

    def call
      @raw_pairs = parse_raw_pairs
      if (conflict = RawQuery.shape_conflict(@raw_pairs))
        invalid_query!(*conflict)
      end
      @raw_pairs.each { |parameter, value| parse_parameter(parameter, value) }
      validate_action_controller_parameters!
      validate_page_offset!

      filtered = apply_filters(@scope)
      total_count = filtered.unscope(:order).count
      paginated = apply_pagination(apply_sort(filtered))
      requested_includes = @includes || []
      paginated = paginated.includes(*requested_includes.map(&:to_sym)) if requested_includes.any?

      Result.new(
        scope: paginated,
        includes: requested_includes,
        total_count: total_count,
        links: pagination_links(total_count),
        include_requested: !@includes.nil?
      )
    end

    private

    def parse_raw_pairs
      RawQuery.decode(@request.query_string)
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
      allowed_operators = @filter_contract[name]
      unless allowed_operators&.include?(operator) && FILTER_FIELDS.key?(name)
        invalid_query!("INVALID_FILTER", parameter)
      end

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
      type = FILTER_FIELDS.fetch(name).fetch(:type)

      case type
      when :string
        raw_value
      when :status
        parse_status(raw_value, parameter)
      when :integer
        parse_integer(raw_value, parameter)
      when :uuid
        parse_uuid(raw_value, parameter)
      when :datetime
        parse_datetime(raw_value, parameter)
      else
        raise ArgumentError, "unsupported JSON:API filter type"
      end
    end

    def parse_status(raw_value, parameter)
      return raw_value if @model.defined_enums.fetch("status", {}).key?(raw_value)

      invalid_query!("INVALID_FILTER", parameter)
    end

    def parse_integer(raw_value, parameter)
      invalid_query!("INVALID_FILTER", parameter) unless INTEGER.match?(raw_value)

      value = Integer(raw_value, 10)
      return value if (-MAX_SCORE_INTEGER - 1..MAX_SCORE_INTEGER).cover?(value)

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
        invalid_query!("INVALID_SORT", parameter) unless @sort_contract.include?(name)
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
      unless %w[page[number] page[size]].include?(parameter) && !@seen_page_parameters.include?(parameter)
        invalid_query!("INVALID_PAGE", parameter)
      end

      @seen_page_parameters << parameter
      value = parse_positive_integer(raw_value, parameter)
      if parameter == "page[number]"
        @page_number = value
      else
        @page_size = [ value, MAX_PAGE_SIZE ].min
      end
    end

    def parse_positive_integer(raw_value, parameter)
      if raw_value.length > MAX_SQL_INTEGER.to_s.length || !POSITIVE_INTEGER.match?(raw_value)
        invalid_query!("INVALID_PAGE", parameter)
      end

      value = Integer(raw_value, 10)
      return value if value.between?(1, MAX_SQL_INTEGER)

      invalid_query!("INVALID_PAGE", parameter)
    rescue ArgumentError
      invalid_query!("INVALID_PAGE", parameter)
    end

    def validate_page_offset!
      return if (@page_number - 1) * @page_size <= MAX_SQL_INTEGER

      invalid_query!("INVALID_PAGE", "page[number]")
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
        definition = FILTER_FIELDS.fetch(filter.name)
        column = @model.arel_table[definition.fetch(:attribute)]
        predicate = filter_predicate(column, filter)
        relation.where(predicate)
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
      terms = @sort_terms || [ SortTerm.new("createdAt", true) ]
      terms = [ *terms, SortTerm.new("id", false) ] unless terms.any? { |term| term.name == "id" }
      order = terms.map do |term|
        column = @model.arel_table[SORT_FIELDS.fetch(term.name)]
        term.descending ? column.desc : column.asc
      end

      scope.reorder(*order)
    end

    def apply_pagination(scope)
      scope.offset((@page_number - 1) * @page_size).limit(@page_size)
    end

    def pagination_links(total_count)
      last_page = [ 1, (total_count + @page_size - 1) / @page_size ].max
      {
        "self" => page_link(@page_number),
        "first" => page_link(1),
        "prev" => @page_number > 1 ? page_link(@page_number - 1) : nil,
        "next" => @page_number < last_page ? page_link(@page_number + 1) : nil,
        "last" => page_link(last_page)
      }
    end

    def page_link(number)
      preserved = @raw_pairs.reject { |parameter, _| parameter == "page" || parameter.start_with?("page[") }
      query = URI.encode_www_form(
        [ *preserved, [ "page[number]", number.to_s ], [ "page[size]", @page_size.to_s ] ]
      )
      "#{@request.path}?#{query}"
    end

    def invalid_query!(code, parameter)
      raise JsonApiError.new(
        status: 400,
        code: code,
        source: { parameter: parameter }
      )
    end
  end
  private_constant :Parser
end
