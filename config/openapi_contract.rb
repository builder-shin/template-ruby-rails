# frozen_string_literal: true

# Native Swagger schema enrichment from the controllers' actual query/write rules.
module OpenapiContract
  MEDIA = "application/vnd.api+json"
  STRING = { type: "string" }.freeze
  COLLECTIONS = {
    "/api/v1/examples" => Api::V1::ExamplesController,
    "/api/v1/categories" => Api::V1::ExampleCategoriesController,
    "/api/v1/tags" => Api::V1::ExampleTagsController
  }.freeze

  module_function

  def object(properties, required = properties.keys.map(&:to_s))
    { type: "object", properties: properties, required: required }
  end

  def reference(name)
    { "$ref" => "#/components/schemas/#{name}" }
  end

  def parameter(name, schema, description = "")
    { name: name, in: "query", required: false, schema: schema, description: description }
  end

  def page_parameters(related = false)
    parameters = [
      parameter("page[number]", { type: "integer", minimum: 1, maximum: 2**53 }, "Offset mode only. (number - 1) * clamped size must not exceed 9007199254740991."),
      parameter("page[size]", { type: "integer", minimum: 1, format: "int64", default: 20 }, "Positive int64, clamped to 100 before computing the offset.")
    ]
    unless related
      parameters << parameter("page[totals]", { type: "boolean", default: false }, "Include totalCount and the last offset page.")
      %w[after before].each do |direction|
        parameters << parameter("page[#{direction}]", { type: "string", maxLength: 4096 }, "Opaque cursor; empty starts at the boundary. Cannot combine with number or the other cursor direction.")
      end
    end
    parameters
  end

  def include_parameter(contract)
    parameter("include", STRING, "Comma-separated relationships: #{contract.fetch(:includes).join(', ')}. Empty requests included: [].")
  end

  def query_parameters(contract)
    parameters = page_parameters
    default = contract.fetch(:default_sort).map { |term| "#{term[:direction] == :desc ? '-' : ''}#{term[:field]}" }.join(",")
    parameters << parameter("sort", STRING, "Comma-separated fields; prefix - for descending: #{contract.fetch(:sorts).keys.join(', ')}. Default: #{default}.")
    parameters << include_parameter(contract)
    contract.fetch(:filters).each do |name, field|
      schema = case field.fetch(:type)
      when :integer then { type: "integer", minimum: -2**31, maximum: 2**31 - 1 }
      when :uuid then { type: "string", format: "uuid" }
      when :datetime then { type: "string", format: "date-time" }
      when :enum then { type: "string", enum: Example.defined_enums.fetch(field.fetch(:attribute).to_s).keys }
      else STRING
      end
      field.fetch(:operators).each do |operator|
        value = operator == "in" ? STRING : operator == "isNull" ? { type: "boolean" } : schema
        description = operator == "contains" ? "Case-sensitive literal substring." : operator == "in" ? "Comma-separated values." : operator
        parameters << parameter("filter[#{name}][#{operator}]", value, description)
        parameters << parameter("filter[#{name}]", value, "Alias of exact.") if operator == "exact"
      end
    end
    parameters
  end

  def normalize_nulls!(value)
    case value
    when Array then value.each { |entry| normalize_nulls!(entry) }
    when Hash
      if value.delete(:nullable)
        if value.key?(:type)
          value[:type] = [ value[:type], "null" ]
        else
          original = value.dup
          value.clear
          value[:anyOf] = [ original, { type: "null" } ]
        end
      end
      value.each_value { |entry| normalize_nulls!(entry) }
    end
  end

  def write_attributes(rules, required)
    properties = rules.to_h do |name, rule|
      schema = { type: rule[:nullable] ? [ rule.fetch(:type).to_s, "null" ] : rule.fetch(:type).to_s }
      schema[:enum] = rule[:values] if rule[:values]
      schema[rule[:type] == :string ? :minLength : :minimum] = rule[:min] if rule[:min]
      schema[rule[:type] == :string ? :maxLength : :maximum] = rule[:max] if rule[:max]
      [ name, schema ]
    end
    object(properties, required.map(&:to_s)).merge(additionalProperties: false)
  end

  def enrich!(document)
    normalize_nulls!(document)
    schemas = document.dig(:components, :schemas)
    examples = Api::V1::ExamplesController.new
    rules = examples.send(:write_attribute_rules)
    schemas[:ExampleCreateAttributes] = write_attributes(rules, examples.send(:required_create_attributes))
    schemas[:ExampleReplaceAttributes] = write_attributes(rules, examples.send(:required_replace_attributes))
    schemas[:ExamplePatchAttributes] = write_attributes(rules, [])
    schemas[:ExampleAttributes][:properties].merge!(schemas[:ExampleCreateAttributes][:properties])
    schemas[:AuthCredentialsAttributes][:additionalProperties] = false
    schemas[:AuthCredentialsAttributes][:properties][:password][:writeOnly] = true
    schemas[:RefreshTokenAttributes][:additionalProperties] = false
    schemas[:UserAttributes][:properties][:email][:maxLength] = User.columns_hash.fetch("email").limit

    write_names = %i[ExampleCreateDocument ExamplePatchDocument ExampleReplaceDocument AuthRegisterDocument AuthLoginDocument RefreshTokenDocument]
    write_names.each do |name|
      schema = schemas.fetch(name)
      schema[:additionalProperties] = false
      schema.dig(:properties, :data)[:additionalProperties] = false
    end
    schemas[:ExampleWriteRelationships][:additionalProperties] = false
    schemas[:ExampleWriteRelationships][:minProperties] = 1
    schemas[:ExampleWriteRelationships][:properties].each_value { |schema| schema[:additionalProperties] = false }

    %i[ExampleCategoryIdentifier ExampleTagIdentifier UserIdentifier ExampleIdentifier AuthTokenIdentifier].each do |name|
      schemas.fetch(name)[:properties][:meta] = { type: "object" }
    end
    examples.send(:allowed_relationships).each do |name, definition|
      identifier = object({ type: { type: "string", enum: [ definition.fetch(:type) ] }, id: STRING, meta: { type: "object" } }, %w[type id]).merge(additionalProperties: false)
      data = definition[:cardinality] == :many ? { type: "array", uniqueItems: true, items: identifier } : { anyOf: [ identifier, { type: "null" } ] }
      schemas[:ExampleWriteRelationships][:properties][name][:properties][:data] = data
      write_name = name == :category ? :CategoryRelationshipWriteDocument : :TagsRelationshipWriteDocument
      schemas[write_name] = object({ data: data }).merge(additionalProperties: false)
      path = "/api/v1/examples/{id}/relationships/#{name}"
      %i[post patch delete].each do |method|
        operation = document[:paths][path][method]
        operation[:requestBody][:content][MEDIA][:schema] = reference(write_name) if operation
      end
    end

    links = object(%i[self first prev next last].to_h { |name| [ name, { type: %w[string null] } ] })
    schemas.each do |name, schema|
      next unless name.to_s.end_with?("Document") && !write_names.include?(name) && !name.to_s.include?("WriteDocument")

      schema[:properties][:jsonapi] = reference(:JsonApiVersion)
      schema[:required] = [ *schema.fetch(:required, []), "jsonapi" ].uniq
      if name.to_s.include?("CollectionDocument")
        schema[:properties][:links] = links
      elsif name.to_s.include?("RelationshipDocument")
        schema[:properties][:links] = object({ self: STRING, related: STRING })
        schema[:required] |= [ "links" ]
      end
    end
    schemas[:ErrorDocument][:properties][:errors][:items] = object({ status: STRING, code: { type: "string", enum: JsonApiError::ERROR_CODES }, title: STRING, detail: STRING, source: object({ pointer: STRING, parameter: STRING, header: STRING }, []), meta: { type: "object" } }, %w[status code title detail])
    %i[ExampleResource UserResource ExampleCategoryResource ExampleTagResource].each do |name|
      schemas[name][:allOf][1][:properties][:links] = object({ self: STRING })
    end
    schemas[:ExampleRelationships][:properties].each_value do |relationship|
      relationship[:properties][:links] = object({ self: STRING, related: STRING })
    end

    COLLECTIONS.each do |path, controller|
      contract = controller.new.send(:query_contract)
      document[:paths][path][:get][:parameters] = query_parameters(contract)
      document[:paths]["#{path}/{id}"][:get][:parameters] = [ include_parameter(contract) ]
    end
    document[:paths]["/api/v1/examples/{id}/tags"][:get][:parameters] = page_parameters(true)
    document[:paths].each do |path, methods|
      next unless path.start_with?("/api/v1/", "/health/")

      methods.each do |method, operation|
        next unless %i[get post patch put delete].include?(method)

        statuses = if path.start_with?("/health/")
          path.end_with?("/ready") ? [ 503 ] : []
        elsif path == "/api/v1/users/me"
          [ 401, 406, 422, 500 ]
        elsif path.start_with?("/api/v1/auth/")
          if path.end_with?("/register")
            [ 406, 409, 415, 422, 500 ]
          elsif path.end_with?("/logout")
            [ 401, 406, 415, 422, 500 ]
          else
            [ 401, 403, 406, 415, 422, 500 ]
          end
        elsif method == :get
          path.include?("{id}") ? [ 400, 404, 406, 422, 500 ] : [ 400, 406, 422, 500 ]
        elsif method == :delete && !path.include?("/relationships/")
          [ 400, 401, 403, 404, 406, 422, 500 ]
        else
          [ 400, 401, 403, *(path.include?("{id}") ? [ 404 ] : []), 406, 409, 415, 422, 500 ]
        end
        statuses.each do |status|
          operation[:responses][status.to_s] = { description: "JSON:API error", content: { MEDIA => { schema: reference(:ErrorDocument) } } }
        end
      end
    end
    registration = document[:paths]["/api/v1/auth/register"][:post][:responses]["201"]
    registration[:headers] = { "Location" => { schema: { type: "string", enum: [ "/api/v1/users/me" ] } } }
    [ document[:paths]["/api/v1/examples"][:post], document[:paths]["/api/v1/examples/{id}"][:put] ].each do |operation|
      operation[:responses]["201"][:headers] = { "Location" => { schema: STRING, description: "Canonical URL of the created example." } }
    end
  end
end
