# frozen_string_literal: true

class SendJobRecommendationsJob < ApplicationJob
  queue_as :mailers
  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform
    result = JobRecommendationService.new.send_job_recommendations
    Rails.logger.info "[SendJobRecommendationsJob] Sent: #{result[:sent_count]}/#{result[:total_profiles]}, Skipped: #{result[:skipped_count]}"
  end
end
