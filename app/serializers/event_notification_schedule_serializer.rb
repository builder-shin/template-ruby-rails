# frozen_string_literal: true

class EventNotificationScheduleSerializer < ApplicationSerializer
  attributes :id, :name, :email_subject, :sendgrid_template_id, :enabled,
             :target_type, :trigger_type, :trigger_value, :send_time,
             :last_executed_at, :created_at, :updated_at
end
