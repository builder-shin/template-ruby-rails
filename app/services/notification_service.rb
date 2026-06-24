# frozen_string_literal: true

class NotificationService
  def initialize
    @sendgrid = SendgridEmailService.new
  end

  # 템플릿 키 기반 이메일 발송
  def send_notification(template_key:, data:)
    template = EmailTemplate.enabled.find_by(key: template_key)
    return { success: false, error: "Template not found: #{template_key}" } unless template
    return { success: false, error: "No SendGrid template ID" } unless template.sendgrid_template_id.present?

    recipient_email = data[:recipient_email]
    dynamic_data = data.except(:recipient_email).transform_keys(&:to_s).transform_values { |v| v&.to_s || "" }

    # subject 변수 치환: {{variable}} → dynamic_data[variable]
    subject = (template.subject || "알림").gsub(/\{\{(\w+)\}\}/) do
      dynamic_data[$1] || $&
    end
    dynamic_data["subject"] = subject

    @sendgrid.send_template_email(
      to: recipient_email,
      subject: subject,
      template_id: template.sendgrid_template_id,
      dynamic_data: dynamic_data
    )
  end
end
