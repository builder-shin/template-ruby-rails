# frozen_string_literal: true

class SendNotificationJob < ApplicationJob
  queue_as :mailers
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  ALLOWED_METHODS = %w[
    notify_job_post_pending
    notify_job_post_published
    notify_job_post_closed
    notify_application_submitted
    notify_application_received
    notify_screening_passed
    notify_final_passed
    notify_rejected
  ].freeze

  def perform(method_name, *args)
    unless ALLOWED_METHODS.include?(method_name)
      raise ArgumentError, "Unknown notification method: #{method_name}"
    end

    JobNotificationService.new.public_send(method_name, *args)
  end
end
