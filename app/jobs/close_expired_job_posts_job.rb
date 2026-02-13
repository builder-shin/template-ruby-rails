# frozen_string_literal: true

class CloseExpiredJobPostsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform
    today = Time.current.in_time_zone("Asia/Seoul").beginning_of_day
    job_posts = JobPost.where(status: :recruiting)
                       .where.not(deadline: nil)
                       .where("deadline < ?", today)

    closed = 0
    job_posts.find_each do |job_post|
      job_post.update!(status: :closed)

      SendNotificationJob.perform_later("notify_job_post_closed", job_post.id)
      closed += 1
    rescue => e
      Rails.logger.error "[CloseExpiredJobPostsJob] Failed for #{job_post.id}: #{e.message}"
    end

    Rails.logger.info "[CloseExpiredJobPostsJob] Closed #{closed} expired job posts"
  end
end
