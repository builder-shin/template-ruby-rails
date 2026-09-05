# frozen_string_literal: true

module JsonapiRelationships
  extend ActiveSupport::Concern

  def category_relationship
    render_relationship_linkage(:category)
  end

  def replace_category_relationship
    mutate_relationship(:category, :replace)
  end

  def related_category
    render_related_resource(:category)
  end

  def tags_relationship
    render_relationship_linkage(:tags)
  end

  def add_tags_relationship
    mutate_relationship(:tags, :add)
  end

  def replace_tags_relationship
    mutate_relationship(:tags, :replace)
  end

  def remove_tags_relationship
    mutate_relationship(:tags, :remove)
  end

  def related_tags
    render_related_resource(:tags)
  end

  def relationship_after_save(_success); end

  private

  def render_relationship_linkage(name)
    policy = relationship_policy(name)
    model = relationship_parent
    related = model.public_send(policy.fetch(:association))

    render_jsonapi_payload(
      {
        data: relationship_data(policy, related),
        links: {
          self: relationship_url(model, name),
          related: related_url(model, name)
        }
      },
      status: :ok
    )
  end

  def render_related_resource(name)
    policy = relationship_policy(name)
    model = relationship_parent
    related = model.public_send(policy.fetch(:association))

    payload =
      if policy.fetch(:cardinality) == :many
        related_collection_payload(policy, related)
      else
        policy.fetch(:serializer).new(related).serializable_hash
      end

    render_jsonapi_payload(payload, status: :ok)
  end

  # to-many related-resource URL의 페이지네이션.
  #
  # `validate_related_collection_query!`(jsonapi_query.rb)가 before_action에서 이미
  # 파싱해 둔 page[number]/page[size]를 그대로 쓴다 — 같은 쿼리 문자열을 여기서
  # 다시 파싱하지 않는다.
  #
  # 이미 로드된 배열을 자르는 대신 질의한다: `association`은 ActiveRecord relation이라
  # `.order(:id).offset(...).limit(...)`이 배열 슬라이스보다 싸고 코드도 짧다. 정렬은
  # 대상의 기본키 오름차순으로 고정한다 — 그렇지 않으면 페이지 경계가 요청마다
  # 흔들릴 수 있다.
  #
  # `render_jsonapi_payload`는 `jsonapi.rb`의 렌더러를 거치지 않고 이 해시를 그대로
  # JSON으로 직렬화하므로(`jsonapi_meta` 백필이 적용되지 않으므로), links·meta를
  # 여기서 직접 채운다. `meta.totalCount`는 이 라우트에서 항상 낸다 — 정본과 같이
  # `page[totals]`를 받지 않고도 총 개수를 낸다.
  def related_collection_payload(policy, association)
    page_number = @related_collection_page_number
    page_size = @related_collection_page_size
    total_count = association.count
    paged = Jsonapi::Pagination.apply(association.order(:id), page_number: page_number, page_size: page_size)
    has_more = page_number * page_size < total_count

    payload = policy.fetch(:serializer).new(paged).serializable_hash
    payload[:links] = Jsonapi::Pagination.links(
      request: request,
      raw_pairs: [],
      page_number: page_number,
      page_size: page_size,
      has_more: has_more,
      total_count: total_count,
      # 이 라우트는 page[totals]를 받지 않으므로 링크에도 echo하지 않는다 —
      # totals: true로 두면 이 라우트가 거부하는 자신의 self/next 링크를 만들게 된다.
      totals: false
    )
    payload[:meta] = { totalCount: total_count }
    payload
  end

  def mutate_relationship(name, mutation)
    policy = relationship_policy(name)
    raw_linkage = relationship_linkage!(policy)

    ActiveRecord::Base.transaction do
      model = relationship_parent(lock: true)
      related = resolve_relationship_resources!(policy, raw_linkage)
      apply_relationship_mutation(model, policy, mutation, related)
      relationship_after_save(true)
      serialize_jsonapi(model.reload)
    end

    head :no_content
  end

  def relationship_policy(name)
    allowed_relationships.fetch(name)
  end

  def relationship_parent(lock: false)
    scope = lock ? klass.lock : klass
    model = scope.find_by(id: normalized_resource_id(params[:id]))
    return model if model

    raise JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
  end

  def relationship_linkage!(policy)
    unless params.key?(:data)
      raise_invalid_relationship_document("/data")
    end

    linkage = params[:data]
    if policy.fetch(:cardinality) == :many
      raise_invalid_relationship_document("/data") unless linkage.is_a?(Array)
    elsif !linkage.nil? && !linkage.is_a?(ActionController::Parameters)
      raise_invalid_relationship_document("/data")
    end
    linkage
  end

  def resolve_relationship_resources!(policy, linkage, pointer_prefix: "/data")
    return nil if linkage.nil?

    identifiers = policy.fetch(:cardinality) == :many ? linkage : [ linkage ]
    normalized_ids = identifiers.each_with_index.map do |identifier, index|
      pointer = policy.fetch(:cardinality) == :many ? "#{pointer_prefix}/#{index}" : pointer_prefix
      normalize_relationship_identifier!(policy, identifier, pointer)
    end
    seen_ids = {}
    normalized_ids.each_with_index do |identifier, index|
      next seen_ids[identifier] = true unless seen_ids.key?(identifier)

      pointer = policy.fetch(:cardinality) == :many ? "#{pointer_prefix}/#{index}/id" : "#{pointer_prefix}/id"
      raise_invalid_relationship_document(pointer)
    end
    found = policy.fetch(:model).where(id: normalized_ids).index_by { |record| record.id.to_s.downcase }
    resources = normalized_ids.each_with_index.map do |identifier, index|
      resource = found[identifier]
      next resource if resource

      pointer = policy.fetch(:cardinality) == :many ? "#{pointer_prefix}/#{index}/id" : "#{pointer_prefix}/id"
      raise JsonApiError.new(
        status: 404,
        code: "RELATIONSHIP_RESOURCE_NOT_FOUND",
        source: { pointer: pointer }
      )
    end

    policy.fetch(:cardinality) == :many ? resources : resources.first
  end

  def normalize_relationship_identifier!(policy, identifier, pointer)
    raise_invalid_relationship_document(pointer) unless identifier.is_a?(ActionController::Parameters)

    unsupported = identifier.keys.map(&:to_s).find { |member| !%w[type id].include?(member) }
    raise_invalid_relationship_document("#{pointer}/#{unsupported}") if unsupported
    missing = %w[type id].find { |member| !identifier.key?(member) }
    raise_invalid_relationship_document("#{pointer}/#{missing}") if missing

    if identifier[:type] != policy.fetch(:type)
      raise JsonApiError.new(
        status: 409,
        code: "TYPE_MISMATCH",
        source: { pointer: "#{pointer}/type" }
      )
    end

    value = identifier[:id].to_s
    begin
      normalized_resource_id(value)
    rescue JsonApiError
      raise JsonApiError.new(
        status: 404,
        code: "RELATIONSHIP_RESOURCE_NOT_FOUND",
        source: { pointer: "#{pointer}/id" }
      )
    end
  end

  def apply_relationship_mutation(model, policy, mutation, related)
    association = policy.fetch(:association)
    if policy.fetch(:cardinality) == :one
      model.update!(association => related)
    elsif mutation == :add
      insert_relationship_rows(model, association, related)
    elsif mutation == :replace
      model.public_send("#{association}=", related)
    else
      model.public_send(association).delete(*related)
    end
  end

  def insert_relationship_rows(model, association, related)
    reflection = model.class.reflect_on_association(association)
    join_reflection = reflection.through_reflection
    rows = related.map do |record|
      {
        join_reflection.foreign_key => model.id,
        reflection.source_reflection.foreign_key => record.id
      }
    end
    join_reflection.klass.insert_all(rows) if rows.any?
    model.association(association).reset
  end

  def relationship_identifier(policy, record)
    { type: policy.fetch(:type), id: record.id.to_s.downcase }
  end

  def relationship_data(policy, related)
    return related.map { |record| relationship_identifier(policy, record) } if policy.fetch(:cardinality) == :many
    return relationship_identifier(policy, related) if related

    nil
  end

  def relationship_url(model, name)
    "/api/v1/examples/#{model.id.to_s.downcase}/relationships/#{name}"
  end

  def related_url(model, name)
    "/api/v1/examples/#{model.id.to_s.downcase}/#{name}"
  end

  def raise_invalid_relationship_document(pointer)
    raise JsonApiError.new(
      status: 400,
      code: "INVALID_JSONAPI_DOCUMENT",
      source: { pointer: pointer }
    )
  end
end
