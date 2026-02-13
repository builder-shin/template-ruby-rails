module CrudActions
  extend ActiveSupport::Concern

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
      return [] unless allowed_includes.present?

      requested = params['include'].to_s.split(',').filter_map(&:strip)
      allowed = allowed_includes.map(&:to_s)

      # 중첩 경로(user.consents)는 top-level(user)이 허용 목록에 있으면 통과
      requested.select do |path|
        top_level = path.split(".").first
        allowed.include?(top_level)
      end
    end

    def render_jsonapi_internal_server_error(exception)
      unless exception.is_a?(JsonApiError)
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
    controller_name.classify.constantize
  end

  def index
    scope = respond_to?(:index_scope, true) ? index_scope : klass.all
    scope = scope.includes(includes_for_active_record) if jsonapi_include.present?
    paginated = jsonapi_paginate(scope)

    # Enum 필터 값을 integer로 변환
    transform_enum_filters!

    filtered = jsonapi_filter(paginated, filter_attributes)

    # Convert include paths to symbols for jsonapi-serializer
    include_symbols = jsonapi_include.map(&:to_sym)

    # Explicitly pass include option to jsonapi-serializer
    render jsonapi: filtered.result.load, include: include_symbols
  end

  # Ransack enum 필터 문제 해결: 문자열 enum 값을 integer로 변환
  def transform_enum_filters!
    return unless params[:filter].present?

    filter_params = params[:filter].to_unsafe_h
    filter_params.each do |key, value|
      # _eq, _in 등 Ransack predicate 분리
      attr_name = key.to_s.sub(/_(eq|not_eq|in|not_in|lt|lteq|gt|gteq|cont|matches)$/, '')

      # 해당 속성이 enum인지 확인
      if klass.defined_enums.key?(attr_name)
        enum_mapping = klass.defined_enums[attr_name]

        if value.is_a?(Array)
          # _in 필터: 배열의 각 값을 integer로 변환
          params[:filter][key] = value.map { |v| enum_mapping[v.to_s.downcase] || v }
          next
        end

        # _eq 필터: 단일 값을 integer로 변환
        converted = enum_mapping[value.to_s.downcase]
        params[:filter][key] = converted if converted.present?
      end
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
    return [] unless jsonapi_include.present?

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

    # Convert nested hash to ActiveRecord format
    def convert_nested(hash)
      hash.map do |key, value|
        next key if value.nil? || value.empty?

        { key => convert_nested(value) }
      end
    end

    result + convert_nested(nested)
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
    scope = scope.includes(includes_for_active_record) if jsonapi_include.present?
    @model = scope.find_by(id: params[:id])
    return unless @model.nil?

    raise NotFound.new("You cannot found the resource with given id", "404")
  end

  private

  def model_params
    jsonapi_deserialize(params, model_params_options)
  end

  class NotFound < JsonApiError; end
end
