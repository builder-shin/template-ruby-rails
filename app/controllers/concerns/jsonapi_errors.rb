# frozen_string_literal: true

module JsonapiErrors
  extend ActiveSupport::Concern

  JSONAPI_MEDIA_TYPE = "application/vnd.api+json"
  INTERNAL_ERROR_TEXT = {
    ko: {
      title: "서버 내부 오류",
      detail: "요청을 처리하는 중 서버 오류가 발생했습니다."
    },
    en: {
      title: "Internal server error",
      detail: "The server encountered an error while processing the request."
    }
  }.freeze

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
    object = jsonapi_error_object(error)
    render_jsonapi_errors([ object ], status: object.fetch(:status).to_i)
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
    render_jsonapi_errors(errors, status: errors.first.fetch(:status).to_i)
  end

  def render_unexpected_jsonapi_error(error)
    Rails.logger.error(error.full_message)
    render_jsonapi_error(JsonApiError.new(status: 500, code: "INTERNAL_SERVER_ERROR"))
  end

  def render_jsonapi_errors(errors, status:)
    append_vary_header("Accept-Language")
    response.status = status
    response.headers["Content-Type"] = JSONAPI_MEDIA_TYPE
    self.response_body = JSON.generate(errors: errors)
  end

  def jsonapi_error_object(error)
    I18n.with_locale(jsonapi_locale) do
      translation_key = "jsonapi.errors.#{error.code}"
      title = I18n.t("#{translation_key}.title", default: nil, **error.context)
      detail = I18n.t("#{translation_key}.detail", default: nil, **error.context)
      return internal_error_object unless title.present? && detail.present?

      object = {
        status: error.status.to_s,
        code: error.code,
        title: title,
        detail: detail
      }
      object[:source] = error.source if error.source.present?
      object
    end
  end

  def internal_error_object
    locale = jsonapi_locale
    fallback = INTERNAL_ERROR_TEXT.fetch(locale)
    translation_key = "jsonapi.errors.INTERNAL_SERVER_ERROR"

    {
      status: "500",
      code: "INTERNAL_SERVER_ERROR",
      title: I18n.t("#{translation_key}.title", locale: locale, default: fallback.fetch(:title)),
      detail: I18n.t("#{translation_key}.detail", locale: locale, default: fallback.fetch(:detail))
    }
  end

  def append_vary_header(token)
    tokens = response.headers["Vary"].to_s.split(",").map(&:strip).reject(&:empty?)
    return if tokens.include?("*")

    tokens << token unless tokens.any? { |existing| existing.casecmp?(token) }
    response.headers["Vary"] = tokens.join(", ")
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
