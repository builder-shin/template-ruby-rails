class CleanupIncompleteProfilesJob < ApplicationJob
  queue_as :default

  def perform
    # 30일 이상 전에 생성되었고, required_completeness가 0이며,
    # 이름도 없는 "고아" 프로필 정리
    cutoff = 30.days.ago

    orphan_profiles = Profile
      .where("created_at < ?", cutoff)
      .where(required_completeness: 0)
      .where(name: [nil, ""])
      .left_joins(:profile_experiences, :profile_educations, :profile_highlights)
      .group("profiles.id")
      .having("COUNT(profile_experiences.id) = 0 AND COUNT(profile_educations.id) = 0 AND COUNT(profile_highlights.id) = 0")

    count = orphan_profiles.count.size # count returns hash from group
    orphan_profiles.destroy_all

    Rails.logger.info("[CleanupIncompleteProfilesJob] #{count}개 미완성 프로필 정리 완료")
  end
end
