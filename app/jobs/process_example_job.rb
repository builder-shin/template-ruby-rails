# frozen_string_literal: true

class ProcessExampleJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(example_id)
    normalized_id = normalize_uuid(example_id)
    unless normalized_id
      Rails.logger.warn("Skipping Example job with malformed identifier (example_id=#{example_id})")
      return
    end

    example = Example.find_by(id: normalized_id)
    unless example
      Rails.logger.warn("Skipping Example job because the resource does not exist (example_id=#{normalized_id})")
      return
    end

    Rails.logger.info("Processed Example job (example_id=#{normalized_id})")
    nil
  end

  private

  def normalize_uuid(value)
    return unless value.is_a?(String)

    Jsonapi::ScalarGrammar.uuid(value)
  rescue ArgumentError
    nil
  end
end
