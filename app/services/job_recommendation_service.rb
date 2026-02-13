# frozen_string_literal: true

class JobRecommendationService
  MAX_RECOMMENDATIONS = 3
  MIN_RECOMMENDATIONS = 1
  TEMPLATE_KEY = "job_recommendation"

  def initialize
    @sendgrid = SendgridEmailService.new
  end

  def send_job_recommendations
    # 1단계: FDW에서 마케팅 동의 user_id 목록 조회
    consented_user_ids = Auth::UserConsent
      .agreed
      .for_type("position_recommend_email")
      .active
      .pluck(:user_id)

    # 2단계: 로컬 Profile에서 해당 user_id + job_category_id 있는 프로필 조회
    profiles = Profile.includes(:job_category, :user)
      .where(user_id: consented_user_ids)
      .where.not(job_category_id: nil)

    # 3단계: 모집중 채용공고 조회
    job_posts = JobPost.where(status: :recruiting)
      .includes(:job_post_categories)

    sent_count = 0
    skipped_count = 0

    profiles.find_each do |profile|
      if process_profile(profile, job_posts)
        sent_count += 1
      else
        skipped_count += 1
      end
    end

    { total_profiles: profiles.size, sent_count: sent_count, skipped_count: skipped_count }
  end

  private

  def process_profile(profile, job_posts)
    return false unless profile.user&.email

    # 이미 발송한 공고 ID
    sent_ids = RecommendationNotificationHistory
      .where(type: "job_recommendation", recipient_id: profile.user_id)
      .pluck(:sender_id)
      .to_set

    # 매칭 + 필터 + 정렬
    matched = JobCategoryMatchingService.match(profile, job_posts)
    filtered = matched.reject { |r| sent_ids.include?(r[:job_post].id) }
    recommendations = filtered.first(MAX_RECOMMENDATIONS)

    return false if recommendations.size < MIN_RECOMMENDATIONS

    send_recommendation_email(profile, recommendations) &&
      save_history(profile, recommendations)
  rescue => e
    Rails.logger.error "[JobRecommendationService] Profile #{profile.id} error: #{e.message}"
    false
  end

  def send_recommendation_email(profile, recommendations)
    template = EmailTemplate.enabled.find_by(key: TEMPLATE_KEY)
    return false unless template&.sendgrid_template_id

    # Pre-fetch workspaces to avoid N+1 FDW queries in build_job_cards_html
    workspace_ids = recommendations.map { |r| r[:job_post].workspace_id }.uniq
    @workspaces_cache = Auth::Workspace.where(id: workspace_ids).index_by(&:id)

    dynamic_data = {
      "recipientName" => profile.name || "회원",
      "jobCards" => build_job_cards_html(recommendations),
      "moreUrl" => "#{JobNotificationService::FRONTEND_URL}/jobs"
    }

    subject = (template.subject || "#{profile.name}님을 위한 맞춤 채용공고 추천").gsub(/\{\{(\w+)\}\}/) do
      dynamic_data[$1] || $&
    end

    result = @sendgrid.send_template_email(
      to: profile.user.email,
      subject: subject,
      template_id: template.sendgrid_template_id,
      dynamic_data: dynamic_data
    )
    result[:success]
  end

  def save_history(profile, recommendations)
    now = Time.current
    records = recommendations.map do |r|
      {
        type: "job_recommendation",
        sender_id: r[:job_post].id,
        recipient_id: profile.user_id,
        recipient_email: profile.user.email,
        job_post_id: r[:job_post].id,
        sent_at: now,
        created_at: now,
        updated_at: now
      }
    end
    RecommendationNotificationHistory.insert_all(records)
    true
  end

  def build_job_cards_html(recommendations)
    recommendations.map do |r|
      jp = r[:job_post]
      title = jp.title || "채용공고"
      company = @workspaces_cache[jp.workspace_id]&.name || "기업"
      employment = { "freelancer" => "프리랜서", "contract" => "계약직", "full_time" => "정규직" }[jp.employment_type] || "-"
      deadline = jp.deadline_type == "until_filled" ? "채용시까지" : (jp.deadline&.strftime("%Y.%m.%d") || "-")
      url = "#{JobNotificationService::FRONTEND_URL}/jobs/#{jp.id}"

      <<~HTML
        <table cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color: #f8fafc; border-radius: 8px; margin: 0 0 15px 0;">
          <tr><td style="padding: 20px;">
            <p style="color: #333333; font-size: 16px; font-weight: 600; margin: 0 0 12px 0;">#{ERB::Util.html_escape(title)}</p>
            <p style="color: #555555; font-size: 14px; line-height: 22px; margin: 0;">
              &bull; 기업: #{ERB::Util.html_escape(company)}<br>
              &bull; 고용형태: #{employment}<br>
              &bull; 마감일: #{deadline}
            </p>
            <a href="#{url}" style="color: #4962c7; font-size: 14px; font-weight: 600; text-decoration: none; display: inline-block; margin-top: 12px;">공고 바로 보기</a>
          </td></tr>
        </table>
      HTML
    end.join
  end
end
