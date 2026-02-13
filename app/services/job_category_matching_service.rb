# frozen_string_literal: true

class JobCategoryMatchingService
  PRIORITY_BONUS = 100
  BASE_SCORE = 50

  # @return [Array<Hash>] [{ job_post:, score: }, ...] 점수 내림차순
  def self.match(profile, job_posts)
    return [] unless profile.job_category_id

    results = []
    job_posts.each do |jp|
      categories = jp.job_post_categories
      next if categories.blank?
      next unless categories.any? { |c| c.job_category_id == profile.job_category_id }
      next unless experience_in_range?(profile.total_years_of_experience || 0, jp.experience_level)

      results << { job_post: jp, score: calculate_score(jp) }
    end

    results.sort_by { |r| -r[:score] }
  end

  def self.experience_in_range?(years, level)
    case level
    when "under_5_years" then years < 5
    when "from_5_to_10_years" then years >= 5 && years < 10
    when "from_10_to_20_years" then years >= 10 && years < 20
    when "over_20_years" then years >= 20
    else false
    end
  end

  def self.calculate_score(job_post)
    score = BASE_SCORE
    score += PRIORITY_BONUS if job_post.priority
    if job_post.published_at
      days = ((Time.current - job_post.published_at) / 1.day).floor
      score += [30 - days, 0].max if days <= 30
    end
    score
  end
end
