# frozen_string_literal: true

module JsonapiErrors
  extend ActiveSupport::Concern

  JSONAPI_MEDIA_TYPE = "application/vnd.api+json"

  included do
    rescue_from StandardError, with: :render_unexpected_jsonapi_error
    rescue_from ActiveRecord::RecordNotUnique, with: :render_record_conflict
    rescue_from ActiveRecord::RecordNotFound, with: :render_resource_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
    rescue_from ActionController::ParameterMissing, with: :render_invalid_jsonapi_document
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_invalid_jsonapi_document
    rescue_from JSON::ParserError, with: :render_invalid_jsonapi_document
    rescue_from JsonApiError, with: :render_jsonapi_error
  end

  private

  def render_jsonapi_error(error)
    render_jsonapi_errors([ jsonapi_error_object(error) ], status: error.status)
  end

  def render_invalid_jsonapi_document(_error)
    render_jsonapi_error(JsonApiError.new(status: 400, code: "INVALID_JSONAPI_DOCUMENT"))
  end

  def render_resource_not_found(_error)
    render_jsonapi_error(JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND"))
  end

  def render_record_conflict(_error)
    render_jsonapi_error(JsonApiError.new(status: 409, code: "RESOURCE_CONFLICT"))
  end

  def render_record_invalid(error)
    errors = error.record.errors.attribute_names.map do |attribute|
      pointer = attribute == :base ? nil : "/data/attributes/#{attribute.to_s.camelize(:lower)}"
      jsonapi_error_object(
        JsonApiError.new(
          status: 422,
          code: "VALIDATION_ERROR",
          source: pointer && { pointer: pointer }
        )
      )
    end

    errors << jsonapi_error_object(JsonApiError.new(status: 422, code: "VALIDATION_ERROR")) if errors.empty?
    render_jsonapi_errors(errors, status: 422)
  end

  def render_unexpected_jsonapi_error(error)
    Rails.logger.error(error.full_message)
    render_jsonapi_error(JsonApiError.new(status: 500, code: "INTERNAL_SERVER_ERROR"))
  end

  def render_jsonapi_errors(errors, status:)
    render(
      json: { errors: errors },
      status: status,
      content_type: JSONAPI_MEDIA_TYPE
    )
  end

  def jsonapi_error_object(error)
    I18n.with_locale(jsonapi_locale) do
      translation_key = "jsonapi.errors.#{error.code}"
      object = {
        status: error.status.to_s,
        code: error.code,
        title: I18n.t!("#{translation_key}.title", **error.context),
        detail: I18n.t!("#{translation_key}.detail", **error.context)
      }
      object[:source] = error.source if error.source.present?
      object
    end
  end

  def jsonapi_locale
    accept_language = request.headers["Accept-Language"].presence || request.headers["ACCEPT_LANGUAGE"]
    preferences = accept_language.to_s.split(",").each_with_index.filter_map do |entry, index|
      language_range, *parameters = entry.strip.split(";")
      language = language_range.to_s.downcase.split("-").first
      next unless %w[ko en].include?(language)

      quality_parameter = parameters.find { |parameter| parameter.strip.start_with?("q=") }
      quality = quality_parameter ? Float(quality_parameter.strip.delete_prefix("q="), exception: false) : 1.0
      next unless quality && quality.positive? && quality <= 1

      [ language.to_sym, quality, -index ]
    end

    preferences.max_by { |(_, quality, index)| [ quality, index ] }&.first || :ko
  end
end
