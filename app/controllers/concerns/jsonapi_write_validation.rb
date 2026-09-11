# frozen_string_literal: true

# Validate original JSON values before ActiveRecord can coerce their types.
module JsonapiWriteValidation
  extend ActiveSupport::Concern

  private

  def pointer_segment(value)
    value.to_s.gsub("~", "~0").gsub("/", "~1")
  end

  def write_attribute_rules
    {}
  end

  def write_document_errors(body, require_id:, require_attributes:, required_attributes:)
    return [ nil ] unless body.is_a?(Hash)

    errors = []
    data = body["data"]
    unless data.is_a?(Hash)
      errors << "/data"
      return errors + body.keys.reject { |key| key == "data" }.map { |key| "/#{pointer_segment(key)}" }
    end
    errors << "/data/type" unless data["type"].is_a?(String)
    errors << "/data/id" if (require_id || data.key?("id")) && !data["id"].is_a?(String)
    attributes = data["attributes"]
    if data.key?("attributes") || require_attributes
      if !attributes.is_a?(Hash)
        errors << "/data/attributes"
      else
        required_attributes.each { |name| errors << "/data/attributes/#{name}" unless attributes.key?(name.to_s) }
        allowed = Array(model_params_options[:only]).map(&:to_s) & klass.column_names
        attributes.each do |name, value|
          rule = write_attribute_rules[name.to_sym]
          errors << "/data/attributes/#{pointer_segment(name)}" if !allowed.include?(name) || (rule && !valid_write_attribute?(value, rule))
        end
      end
    end
    if data.key?("relationships")
      relationships = data["relationships"]
      if !relationships.is_a?(Hash) || relationships.empty?
        errors << "/data/relationships"
      else
        relationships.each do |name, relationship|
          pointer = "/data/relationships/#{pointer_segment(name)}"
          policy = allowed_relationships[name.to_sym]
          if !policy || !relationship.is_a?(Hash)
            errors << pointer
            next
          end
          if !relationship.key?("data")
            errors << "#{pointer}/data"
          else
            errors.concat(linkage_validation_errors(relationship["data"], policy, "#{pointer}/data"))
          end
          relationship.keys.reject { |key| key == "data" }.each { |key| errors << "#{pointer}/#{pointer_segment(key)}" }
        end
      end
    end
    data.keys.reject { |key| %w[type id attributes relationships].include?(key) }.each { |key| errors << "/data/#{pointer_segment(key)}" }
    body.keys.reject { |key| key == "data" }.each { |key| errors << "/#{pointer_segment(key)}" }
    errors
  end

  def valid_write_attribute?(value, rule)
    return rule[:nullable] == true if value.nil?

    case rule.fetch(:type)
    when :string
      value.is_a?(String) && (!rule[:min] || value.length >= rule[:min]) && (!rule[:max] || value.length <= rule[:max]) && (!rule[:values] || rule[:values].include?(value))
    when :integer
      value.is_a?(Numeric) && value.finite? && value == value.to_i && value >= rule.fetch(:min) && value <= rule.fetch(:max)
    end
  end

  def linkage_validation_errors(linkage, policy, pointer)
    if policy.fetch(:cardinality) == :many
      return [ pointer ] unless linkage.is_a?(Array)

      return linkage.each_with_index.flat_map { |identifier, index| identifier_validation_errors(identifier, "#{pointer}/#{index}") }
    end
    linkage.nil? ? [] : identifier_validation_errors(linkage, pointer)
  end

  def identifier_validation_errors(identifier, pointer)
    return [ pointer ] unless identifier.is_a?(Hash)

    errors = %w[type id].reject { |key| identifier[key].is_a?(String) }.map { |key| "#{pointer}/#{key}" }
    errors << "#{pointer}/meta" if identifier.key?("meta") && !identifier["meta"].is_a?(Hash)
    errors + identifier.keys.reject { |key| %w[type id meta].include?(key) }.map { |key| "#{pointer}/#{pointer_segment(key)}" }
  end

  def raise_write_validation_errors!(pointers)
    return if pointers.empty?

    raise JsonApiError.new(status: 422, code: "VALIDATION_ERROR", sources: pointers.map { |pointer| pointer && { pointer: pointer } })
  end

  def raw_write_document
    JSON.parse(request.raw_post)
  rescue JSON::ParserError
    raise JsonApiError.new(status: 422, code: "VALIDATION_ERROR")
  end
end
