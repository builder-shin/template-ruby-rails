module CrudActions
  extend ActiveSupport::Concern

  # 페이지네이션 최대 크기. 클라이언트가 과도한 page[size] 로 풀스캔을 유발하는 것을 방지
  MAX_PAGE_SIZE = 100

  included do
    include JSONAPI::Deserialization
    include JSONAPI::Fetching
    include JSONAPI::Filtering
    include JSONAPI::Pagination
    include JsonapiQuery
    include JsonapiRelationships

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
  end

  def klass
    @_klass ||= controller_name.classify.constantize
  end

  def index
    scope = respond_to?(:index_scope, true) ? index_scope : klass.all
    return render_jsonapi_query_index(scope) if respond_to?(:query_contract, true)

    scope = scope.includes(includes_for_active_record) if jsonapi_include.present?

    # Enum 필터 값을 integer로 변환
    transform_enum_filters!

    # 필터·정렬을 먼저 적용한 뒤 페이지네이션 (total-count/페이지 링크가 필터된 집합 기준)
    filtered = jsonapi_filter(scope, filter_attributes)
    paginated = jsonapi_paginate(filtered.result)

    # Explicitly pass include option to jsonapi-serializer
    render jsonapi: paginated.load, include: jsonapi_include.map(&:to_sym)
  end

  def render_jsonapi_query_index(scope)
    result = jsonapi_query(scope)
    render jsonapi: result.scope.load,
           include: result.includes.map(&:to_sym),
           meta: { totalCount: result.total_count },
           links: result.links

    ensure_included_array! if result.include_requested
    response.headers["Content-Type"] = JSONAPI::MEDIA_TYPE
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
    validate_jsonapi_write_document!(reject_client_id: true)

    payload = location = nil
    ActiveRecord::Base.transaction do
      @model = klass.new(model_params)
      create_after_init
      @model.save!
      create_after_save(true)
      payload = serialize_jsonapi(@model)
      location = jsonapi_self_link(payload)
    end

    render_jsonapi_payload(payload, status: :created, location: location)
  end

  def update_after_init; end
  def update_after_assign; end
  def update_after_save(success); end

  def update
    validate_jsonapi_write_document!(require_matching_id: true, require_update_members: true)

    payload = nil
    ActiveRecord::Base.transaction do
      _set_model unless @model
      update_after_init
      @model.assign_attributes(model_params)
      update_after_assign
      @model.save!
      update_after_save(true)
      payload = serialize_jsonapi(@model)
    end

    render_jsonapi_payload(payload, status: :ok)
  end

  def upsert_after_init; end
  def upsert_after_assign; end
  def upsert_after_save(success); end

  def upsert
    validate_jsonapi_write_document!(require_matching_id: true)
    normalized_id = normalized_resource_id(params[:id])

    payload = location = nil
    created = false
    ActiveRecord::Base.transaction do
      lock_upsert_id!(normalized_id)
      @model = klass.find_by(id: normalized_id)
      created = @model.nil?
      @model ||= klass.new(id: normalized_id)

      @model.assign_attributes(replacement_model_params)
      reset_write_relationships!(@model)
      @model.assign_attributes(model_params)
      upsert_after_init
      upsert_after_assign
      @model.save!
      upsert_after_save(true)
      payload = serialize_jsonapi(@model)
      location = jsonapi_self_link(payload) if created
    end

    render_jsonapi_payload(payload, status: created ? :created : :ok, location: location)
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
    @model = scope.find_by(id: normalized_resource_id(params[:id]))
    return unless @model.nil?

    raise ::JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
  end

  private

  def ensure_included_array!
    document = JSON.parse(response.body)
    return if document.key?("included")

    document["included"] = []
    self.response_body = JSON.generate(document)
  end

  def model_params
    jsonapi_deserialize(params, model_params_options)
  end

  def serializer_class
    "#{klass.name}Serializer".constantize
  end

  def jsonapi_resource_type
    klass.model_name.plural
  end

  def allowed_relationships
    {}
  end

  def normalized_resource_id(value)
    value.to_s
  end

  def validate_jsonapi_write_document!(reject_client_id: false, require_matching_id: false,
                                       require_update_members: false)
    data = params[:data]
    unless data.is_a?(ActionController::Parameters)
      raise JsonApiError.new(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
    end

    if data[:type] != jsonapi_resource_type
      raise JsonApiError.new(
        status: 409,
        code: "TYPE_MISMATCH",
        source: { pointer: "/data/type" }
      )
    end

    if reject_client_id && data.key?(:id)
      raise JsonApiError.new(
        status: 403,
        code: "CLIENT_GENERATED_ID_UNSUPPORTED",
        source: { pointer: "/data/id" }
      )
    end

    if require_matching_id && !matching_document_id?(data[:id], params[:id])
      raise JsonApiError.new(
        status: 409,
        code: "ID_MISMATCH",
        source: { pointer: "/data/id" }
      )
    end

    validate_write_member_shape!(data, :attributes)
    validate_write_member_shape!(data, :relationships)
    validate_allowed_relationships!(data[:relationships])
    return unless require_update_members && !data.key?(:attributes) && !data.key?(:relationships)

    raise JsonApiError.new(
      status: 422,
      code: "VALIDATION_ERROR",
      source: { pointer: "/data" }
    )
  end

  def validate_write_member_shape!(data, member)
    return unless data.key?(member)
    return if data[member].is_a?(ActionController::Parameters)

    raise JsonApiError.new(
      status: 400,
      code: "INVALID_JSONAPI_DOCUMENT",
      source: { pointer: "/data/#{member}" }
    )
  end

  def matching_document_id?(document_id, request_id)
    return false if document_id.blank?
    return true if document_id.to_s == request_id.to_s

    normalized_resource_id(document_id) == normalized_resource_id(request_id)
  rescue JsonApiError
    false
  end

  def replacement_model_params
    allowed_attributes = Array(model_params_options[:only]).map(&:to_s) & klass.column_names
    defaults = klass.column_defaults.slice(*allowed_attributes)
    defaults
  end

  def validate_allowed_relationships!(relationships)
    return unless relationships

    allowed = allowed_relationships.keys.map(&:to_s)
    unsupported = relationships.keys.map(&:to_s).find { |name| !allowed.include?(name) }
    return unless unsupported

    raise JsonApiError.new(
      status: 400,
      code: "INVALID_JSONAPI_DOCUMENT",
      source: { pointer: "/data/relationships/#{unsupported}" }
    )
  end

  def reset_write_relationships!(model)
    allowed_relationships.each do |association, policy|
      cardinality = policy.is_a?(Hash) ? policy.fetch(:cardinality) : policy
      value = cardinality == :many ? [] : nil
      model.public_send("#{association}=", value)
    end
  end

  def lock_upsert_id!(normalized_id)
    connection = ActiveRecord::Base.connection
    quoted_id = connection.quote(normalized_id)
    connection.select_value("SELECT 1 FROM pg_advisory_xact_lock(hashtextextended(#{quoted_id}, 0))")
  end

  def serialize_jsonapi(model)
    options = {}
    includes = jsonapi_include.map(&:to_sym)
    options[:include] = includes if includes.any?
    serializer_class.new(model, options).serializable_hash
  end

  def jsonapi_self_link(payload)
    payload.dig(:data, :links, :self) || payload.dig("data", "links", "self")
  end

  def render_jsonapi_payload(payload, status:, location: nil)
    response.status = Rack::Utils.status_code(status)
    response.headers["Content-Type"] = JSONAPI::MEDIA_TYPE
    response.headers["Location"] = location if location
    self.response_body = JSON.generate(payload)
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

    raise ::JsonApiError.new(
      status: 400,
      code: "INVALID_FILTER",
      source: { parameter: "filter[#{attr_name}]" }
    )
  end
end
