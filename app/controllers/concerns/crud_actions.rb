module CrudActions
  extend ActiveSupport::Concern

  # 페이지네이션 최대 크기. 클라이언트가 과도한 page[size] 로 풀스캔을 유발하는 것을 방지
  MAX_PAGE_SIZE = 100

  # 임의의 Error 를 나타냅니다.
  class JsonApiError < StandardError
    attr_reader :status, :title

    def initialize(title, msg, status = "500")
      @title = title
      @status = status
      super(msg)
    end
  end

  included do
    include JSONAPI::Deserialization
    include JSONAPI::Fetching
    include JSONAPI::Filtering
    include JSONAPI::Pagination
    include JSONAPI::Errors

    before_action :_set_model, only: [ :show, :update, :destroy ]

    # Override JSONAPI::Fetching#jsonapi_include to add filtering
    define_method(:jsonapi_include) do
      return @_jsonapi_include if defined?(@_jsonapi_include)
      return @_jsonapi_include = [] unless allowed_includes.present?

      requested = params["include"].to_s.split(",").filter_map(&:strip)
      allowed = allowed_includes.map(&:to_s)

      # 중첩 경로(user.consents)는 top-level(user)이 허용 목록에 있으면 통과
      @_jsonapi_include = requested.select do |path|
        allowed.include?(path.split(".").first)
      end
    end

    # Override JSONAPI::Pagination#jsonapi_page_size to clamp the requested size
    define_method(:jsonapi_page_size) do |pagination_params|
      [ super(pagination_params), MAX_PAGE_SIZE ].min
    end

    def render_jsonapi_internal_server_error(exception)
      unless exception.is_a?(JsonApiError)
        Sentry.capture_exception(exception) if defined?(Sentry)
        Rails.logger.error exception.message
        Rails.logger.error exception.backtrace.join("\n")
        return super
      end

      render jsonapi_errors: [ {
        status: exception.status,
        title: exception.title || exception.class.name.demodulize,
        detail: exception.message
      } ], status: exception.status
    end
  end

  def klass
    @_klass ||= controller_name.classify.constantize
  end

  def index
    scope = respond_to?(:index_scope, true) ? index_scope : klass.all
    scope = scope.includes(includes_for_active_record) if jsonapi_include.present?

    # Enum 필터 값을 integer로 변환
    transform_enum_filters!

    # 필터·정렬을 먼저 적용한 뒤 페이지네이션 (total-count/페이지 링크가 필터된 집합 기준)
    filtered = jsonapi_filter(scope, filter_attributes)
    paginated = jsonapi_paginate(filtered.result)

    # Explicitly pass include option to jsonapi-serializer
    render jsonapi: paginated.load, include: jsonapi_include.map(&:to_sym)
  end

  # Ransack enum 필터 문제 해결: 문자열 enum 값을 integer로 변환
  def transform_enum_filters!
    return unless params[:filter].present?

    enums = klass.defined_enums
    return if enums.empty?

    params[:filter].to_unsafe_h.each do |key, value|
      # _eq, _in 등 Ransack predicate 분리
      attr_name = key.to_s.sub(/_(eq|not_eq|in|not_in|lt|lteq|gt|gteq|cont|matches)$/, "")

      enum_mapping = enums[attr_name]
      next if enum_mapping.nil?

      if value.is_a?(Array)
        # _in 필터: 배열의 각 값을 integer로 변환
        params[:filter][key] = value.map { |v| convert_enum_value(attr_name, enum_mapping, v) }
        next
      end

      # _eq 필터: 단일 값을 integer로 변환 (정수 0 포함)
      params[:filter][key] = convert_enum_value(attr_name, enum_mapping, value)
    end
  end

  def filter_attributes
    []
  end

  # 허용된 include 목록 (컨트롤러에서 오버라이드)
  def allowed_includes
    []
  end

  # Convert JSON:API dot notation to ActiveRecord nested hash format
  # e.g., [:user, :"user.user_consents"] => [:user, { user: :user_consents }]
  def includes_for_active_record
    return @_includes_for_active_record if defined?(@_includes_for_active_record)
    return @_includes_for_active_record = [] unless jsonapi_include.present?

    result = []
    nested = {}

    jsonapi_include.each do |include_path|
      parts = include_path.to_s.split(".")
      if parts.length == 1
        result << parts.first.to_sym
        next
      end

      # Build nested hash: user.user_consents => { user: :user_consents }
      # user.workspace.members => { user: { workspace: :members } }
      current = nested
      parts[0..-2].each do |part|
        current[part.to_sym] ||= {}
        current = current[part.to_sym]
      end
      current[parts.last.to_sym] = nil  # Mark as leaf
    end

    @_includes_for_active_record = result + convert_nested(nested)
  end

  def jsonapi_meta(resources)
    total = jsonapi_pagination_meta(resources)[:records]
    { "total-count" => total }
  end

  def show_after_init; end

  def show
    show_after_init
    return if performed?

    ActiveRecord::Base.transaction do
      include_symbols = jsonapi_include.map(&:to_sym)
      render jsonapi: @model, include: include_symbols
    end
  end

  def new_after_init; end

  def new
    @model = klass.new
    new_after_init
    return if performed?

    render jsonapi: @model
  end

  def create_after_init; end
  def create_after_save(success); end

  def create
    @model = klass.new(model_params)
    create_after_init
    return if performed?

    unless @model.save
      create_after_save(false)
      return if performed?

      return render jsonapi_errors: @model.errors, status: :unprocessable_entity
    end

    create_after_save(true)
    return if performed?

    render jsonapi: @model
  end

  def update_after_init; end
  def update_after_assign; end
  def update_after_save(success); end

  def update
    update_after_init
    return if performed?

    @model.assign_attributes(model_params)
    update_after_assign
    return if performed?

    unless @model.save
      update_after_save(false)
      return if performed?

      return render jsonapi_errors: @model.errors, status: :unprocessable_entity
    end

    update_after_save(true)
    return if performed?

    render jsonapi: @model
  end

  def destroy_after_init; end
  def destroy_after_save(success); end

  def destroy
    destroy_after_init
    return if performed?

    unless @model.destroy
      destroy_after_save(false)
      return if performed?

      return render jsonapi_errors: @model.errors, status: :unprocessable_entity
    end

    destroy_after_save(true)
    return if performed?

    head :no_content
  end

  def model_params_options
    {}
  end

  def set_model
    _set_model
  end

  def _set_model
    scope = klass
    # destroy 는 관계를 직렬화하지 않으므로 eager load 생략 (낭비 쿼리 방지)
    scope = scope.includes(includes_for_active_record) if jsonapi_include.present? && action_name != "destroy"
    @model = scope.find_by(id: params[:id])
    return unless @model.nil?

    raise NotFound.new("You cannot found the resource with given id", "404")
  end

  private

  def model_params
    jsonapi_deserialize(params, model_params_options)
  end

  # Convert nested include hash to ActiveRecord format
  # e.g. { user: { workspace: :members } }
  def convert_nested(hash)
    hash.map do |key, value|
      next key if value.nil? || value.empty?

      { key => convert_nested(value) }
    end
  end

  # enum 라벨을 integer로 변환. 이미 숫자면 그대로 두고, 매핑 불가한 라벨은 400.
  def convert_enum_value(attr_name, enum_mapping, value)
    str = value.to_s.downcase
    converted = enum_mapping[str]
    return converted unless converted.nil?
    return value if str.match?(/\A\d+\z/)

    raise JsonApiError.new("잘못된 필터 값", "#{attr_name}의 유효하지 않은 값입니다: #{value}", "400")
  end

  class NotFound < JsonApiError; end
end
