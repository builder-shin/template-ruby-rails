# frozen_string_literal: true

class ProcessEventNotificationsJob < ApplicationJob
  queue_as :mailers
  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform
    schedules = EventNotificationSchedule.enabled.where.not(sendgrid_template_id: nil)
    schedules.find_each do |schedule|
      process_schedule(schedule)
    end
  end

  private

  def process_schedule(schedule)
    return unless schedule.target_type_community_event?
    # 중복 발송 방지: 최근 1시간 내 실행된 스케줄은 스킵
    return if schedule.last_executed_at && schedule.last_executed_at > 1.hour.ago

    events_with_participants = find_matching_events(schedule)
    events_with_participants.each do |event, participants|
      next if participants.empty?
      send_notifications(schedule, event, participants)
    end

    schedule.update_column(:last_executed_at, Time.current)
  end

  def find_matching_events(schedule)
    now = Time.current
    kst_hour = now.in_time_zone("Asia/Seoul").hour

    events = case schedule.trigger_type
    when "days_before"
      if schedule.send_time
        schedule_hour = schedule.send_time.hour
        return [] unless kst_hour == schedule_hour
      end
      target = now + schedule.trigger_value.days
      CareerHubCommunityEvent.where(status: :active)
        .where(start_at: target.beginning_of_day..target.end_of_day)
    when "hours_before"
      target_start = now + schedule.trigger_value.hours
      CareerHubCommunityEvent.where(status: :active)
        .where(start_at: target_start.beginning_of_hour..target_start.end_of_hour)
    else
      return []
    end

    events.map do |event|
      participants = CareerHubCommunityEventParticipant.where(event_id: event.id, status: :registered)
      [event, participants]
    end
  end

  def send_notifications(schedule, event, participants)
    sendgrid = SendgridEmailService.new
    requests = participants.filter_map do |p|
      next unless p.email.present?
      {
        to: p.email,
        dynamic_data: {
          "userName" => p.name,
          "eventTitle" => event.title,
          "eventDate" => event.start_at&.in_time_zone("Asia/Seoul")&.strftime("%Y년 %m월 %d일 %A") || "날짜 미정",
          "eventTime" => event.start_at&.in_time_zone("Asia/Seoul")&.strftime("%H:%M") || "시간 미정",
          "eventLocation" => event.location || "장소 미정",
          "meetingLink" => event.meeting_link || ""
        }
      }
    end

    return if requests.empty?

    result = sendgrid.send_batch_template_emails(
      template_id: schedule.sendgrid_template_id,
      subject: schedule.email_subject,
      requests: requests
    )
    Rails.logger.info "[EventNotifications] #{event.title}: #{result[:sent]}/#{result[:total]} sent"
  end
end
