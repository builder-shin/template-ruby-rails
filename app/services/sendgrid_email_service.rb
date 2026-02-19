# frozen_string_literal: true

class SendgridEmailService
  def initialize
    @api_key = Rails.application.config.x.sendgrid.api_key
    @from_email = Rails.application.config.x.sendgrid.from_email
    @from_name = Rails.application.config.x.sendgrid.from_name
  end

  def enabled?
    @api_key.present? && @from_email.present?
  end

  # 단건 템플릿 이메일 발송
  def send_template_email(to:, subject:, template_id:, dynamic_data: {})
    return { success: false, error: "SendGrid disabled" } unless enabled?

    mail = SendGrid::Mail.new
    mail.from = SendGrid::Email.new(email: @from_email, name: @from_name)
    mail.subject = subject
    mail.template_id = template_id

    personalization = SendGrid::Personalization.new
    personalization.add_to(SendGrid::Email.new(email: to))
    dynamic_data.each { |k, v| personalization.add_dynamic_template_data(k => v) }
    mail.add_personalization(personalization)

    response = client.mail._("send").post(request_body: mail.to_json)

    if response.status_code.to_i.between?(200, 299)
      { success: true, status_code: response.status_code.to_i }
    else
      Rails.logger.error "[SendGrid] Failed to send email: #{response.status_code}"
      { success: false, error: "SendGrid error: #{response.status_code}" }
    end
  rescue => e
    Rails.logger.error "[SendGrid] Exception sending email: #{e.message}"
    { success: false, error: e.message }
  end

  # 배치 템플릿 이메일 발송 (최대 1000건/배치)
  def send_batch_template_emails(template_id:, subject:, requests:)
    return { success: false, total: requests.size, sent: 0, failed: requests.size } unless enabled?

    total = requests.size
    sent = 0
    failed = 0

    requests.each_slice(1000) do |batch|
      mail = SendGrid::Mail.new
      mail.from = SendGrid::Email.new(email: @from_email, name: @from_name)
      mail.subject = subject
      mail.template_id = template_id

      batch.each do |req|
        personalization = SendGrid::Personalization.new
        personalization.add_to(SendGrid::Email.new(email: req[:to]))
        (req[:dynamic_data] || {}).each { |k, v| personalization.add_dynamic_template_data(k => v) }
        mail.add_personalization(personalization)
      end

      response = client.mail._("send").post(request_body: mail.to_json)

      if response.status_code.to_i.between?(200, 299)
        sent += batch.size
      else
        Rails.logger.error "[SendGrid] Batch send failed: #{response.status_code} #{response.body}"
        failed += batch.size
      end
    end

    { success: failed == 0, total: total, sent: sent, failed: failed }
  rescue => e
    Rails.logger.error "[SendGrid] Batch exception after #{sent} sent, #{failed} failed: #{e.message}"
    raise
  end

  private

  def client
    @client ||= SendGrid::API.new(api_key: @api_key).client
  end
end
