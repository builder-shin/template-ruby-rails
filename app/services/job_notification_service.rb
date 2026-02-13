# frozen_string_literal: true

class JobNotificationService
  FRONTEND_URL = ENV.fetch("FRONTEND_URL", "http://localhost:3000")

  def initialize
    @notification = NotificationService.new
  end

  # === 채용공고 알림 ===

  def notify_job_post_pending(job_post_id, workspace_id)
    job_post = JobPost.find(job_post_id)
    owners = get_workspace_owners(workspace_id)
    return if owners.empty?

    workspace = Auth::Workspace.find_by(id: workspace_id)
    period = format_period(job_post.scheduled_publish_date || job_post.published_at, job_post.deadline)

    owners.each do |owner|
      @notification.send_notification(
        template_key: "job_post_pending",
        data: {
          recipient_email: owner.email,
          recipient_name: owner.name,
          company_name: workspace&.name || "기업",
          job_post_title: job_post.title,
          period: period,
          detail_url: build_job_post_url(job_post.id)
        }
      )
    end
  end

  def notify_job_post_published(job_post_id)
    job_post = JobPost.find(job_post_id)
    owners = get_workspace_owners(job_post.workspace_id)
    return if owners.empty?

    workspace = Auth::Workspace.find_by(id: job_post.workspace_id)

    owners.each do |owner|
      @notification.send_notification(
        template_key: "job_post_published",
        data: {
          recipient_email: owner.email,
          recipient_name: owner.name,
          company_name: workspace&.name || "기업",
          job_post_title: job_post.title,
          created_at: format_datetime(job_post.created_at),
          published_at: format_datetime(job_post.published_at),
          detail_url: build_job_post_url(job_post.id)
        }
      )
    end
  end

  def notify_job_post_closed(job_post_id)
    job_post = JobPost.find(job_post_id)
    owners = get_workspace_owners(job_post.workspace_id)
    return if owners.empty?

    workspace = Auth::Workspace.find_by(id: job_post.workspace_id)

    owners.each do |owner|
      @notification.send_notification(
        template_key: "job_post_closed",
        data: {
          recipient_email: owner.email,
          recipient_name: owner.name,
          company_name: workspace&.name || "기업",
          job_post_title: job_post.title,
          period: format_period(job_post.published_at, job_post.deadline),
          detail_url: build_job_post_url(job_post.id)
        }
      )
    end
  end

  # === 지원 알림 ===

  def notify_application_submitted(application_id)
    application = JobApplication.includes(:job_post, profile: :user).find(application_id)
    job_post = application.job_post
    profile = application.profile

    email = application.email || profile.user&.email
    return unless email

    workspace = Auth::Workspace.find_by(id: job_post.workspace_id)

    @notification.send_notification(
      template_key: "job_application_submitted",
      data: {
        recipient_email: email,
        recipient_name: profile.name || profile.user&.name,
        company_name: workspace&.name || "기업",
        job_post_title: job_post.title
      }
    )
  end

  def notify_application_received(application_id)
    application = JobApplication.includes(:job_post, profile: [:profile_experiences]).find(application_id)
    job_post = application.job_post
    profile = application.profile

    owners = get_workspace_owners(job_post.workspace_id)
    workspace = Auth::Workspace.find_by(id: job_post.workspace_id)
    detail_url = "#{FRONTEND_URL}/enterprise/mypage/job-posts/#{job_post.id}/applications"

    if owners.any?
      owners.each do |owner|
        send_application_received_to(owner.email, owner.name, workspace, job_post, profile, detail_url)
      end
    else
      # Fallback 이메일
      fallback = ENV.fetch("FALLBACK_APPLICATION_NOTIFICATION_EMAILS", "")
      fallback.split(",").map(&:strip).reject(&:blank?).each do |email|
        send_application_received_to(email, "관리자", workspace, job_post, profile, detail_url)
      end
    end
  end

  # === 전형 결과 알림 ===

  def notify_screening_passed(application_id)
    send_result_notification(application_id, "screening_passed")
  end

  def notify_final_passed(application_id)
    send_result_notification(application_id, "final_passed")
  end

  # previous_status가 nil인 경우 screening_failed로 기본 처리 (의도된 동작)
  def notify_rejected(application_id, previous_status)
    template_key = previous_status == "document_passed" ? "final_failed" : "screening_failed"
    send_result_notification(application_id, template_key)
  end

  private

  def send_result_notification(application_id, template_key)
    application = JobApplication.includes(:job_post, profile: :user).find(application_id)
    job_post = application.job_post
    profile = application.profile
    email = application.email || profile.user&.email
    return unless email

    workspace = Auth::Workspace.find_by(id: job_post.workspace_id)

    @notification.send_notification(
      template_key: template_key,
      data: {
        recipient_email: email,
        applicant_name: profile.name || profile.user&.name,
        company_name: workspace&.name || "기업",
        job_post_title: job_post.title
      }
    )
  end

  def send_application_received_to(email, name, workspace, job_post, profile, detail_url)
    @notification.send_notification(
      template_key: "job_application_received",
      data: {
        recipient_email: email,
        recipient_name: name,
        company_name: workspace&.name || "기업",
        job_post_title: job_post.title,
        applicant_name: profile.name || "지원자",
        applicant_experience: format_experience(profile),
        preferred_work_type: format_employment_type(profile),
        preferred_work_style: format_work_type(profile),
        detail_url: detail_url
      }
    )
  end

  # === Workspace Owner 조회 ===

  def get_workspace_owners(workspace_id)
    Auth::WorkspaceMember
      .owners
      .approved
      .where(workspace_id: workspace_id)
      .includes(:user)
      .filter_map(&:user)
      .select { |u| u.email.present? }
  end

  # === 포맷팅 헬퍼 ===

  def build_job_post_url(job_post_id)
    "#{FRONTEND_URL}/jobs/#{job_post_id}"
  end

  def format_period(start_date, end_date)
    fmt = ->(d) { d.in_time_zone("Asia/Seoul").strftime("%Y.%m.%d") }
    return "기간 미정" if start_date.nil? && end_date.nil?
    return "#{fmt.call(start_date)} ~ 채용시까지" if start_date && end_date.nil?
    return "~ #{fmt.call(end_date)}" if start_date.nil?
    "#{fmt.call(start_date)} ~ #{fmt.call(end_date)}"
  end

  def format_datetime(date)
    return "-" if date.nil?
    date.in_time_zone("Asia/Seoul").strftime("%Y.%m.%d %H:%M")
  end

  def format_experience(profile)
    experiences = profile.profile_experiences
    return "신입" if experiences.blank?

    total_months = experiences.sum do |exp|
      start_date = exp.start_date
      end_date = exp.current ? Time.current : exp.end_date
      next 0 unless start_date && end_date
      [((end_date.year - start_date.year) * 12 + (end_date.month - start_date.month)), 0].max
    end

    return "신입" if total_months == 0
    years, months = total_months.divmod(12)
    return "#{months}개월" if years == 0
    return "#{years}년" if months == 0
    "#{years}년 #{months}개월"
  end

  def format_employment_type(profile)
    et = profile.employment_type
    return "미정" unless et.is_a?(Hash)
    types = []
    types << "정규직" if et.dig("regular", "fullTime", "value") || et.dig("regular", "partTime", "value")
    types << "계약직" if et.dig("contract", "fullTime", "value") || et.dig("contract", "partTime", "value")
    types << "프리랜서" if et.dig("freelancer", "fullTime", "value") || et.dig("freelancer", "partTime", "value")
    types.any? ? types.join(", ") : "미정"
  end

  def format_work_type(profile)
    work_types = profile.work_type
    return "미정" if work_types.blank?
    labels = { "ON_SITE" => "오피스 근무", "REMOTE" => "원격 근무", "HYBRID" => "원격+오피스 근무" }
    work_types.map { |t| labels[t] || t }.join(", ")
  end
end
