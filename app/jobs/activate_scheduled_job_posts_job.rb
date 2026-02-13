# frozen_string_literal: true

class ActivateScheduledJobPostsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform
    now = Time.current
    job_posts = JobPost.where(status: :pending_publish)
                       .where("scheduled_publish_date <= ?", now)

    activated = 0
    job_posts.find_each do |job_post|
      job_post.update!(status: :recruiting)

      SendNotificationJob.perform_later("notify_job_post_published", job_post.id)
      activated += 1
    rescue => e
      Rails.logger.error "[ActivateScheduledJobPostsJob] Failed for #{job_post.id}: #{e.message}"
    end

    Rails.logger.info "[ActivateScheduledJobPostsJob] Activated #{activated} job posts"
  end
end
