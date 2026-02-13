# == Schema Information
#
# Table name: event_notification_schedules
#
#  id                   :uuid             not null, primary key
#  created_at           :timestamptz      not null
#  email_subject        :string(255)      not null
#  enabled              :boolean          not null, default(true)
#  last_executed_at     :timestamptz
#  name                 :string(100)      not null
#  send_time            :time
#  sendgrid_template_id :string(100)      not null
#  target_type          :integer
#  trigger_type         :integer
#  trigger_value        :integer          not null
#  updated_at           :timestamptz      not null
#
# Indexes
#
#  IDX_event_notification_schedules_is_enabled  (enabled)
#

class EventNotificationSchedule < ApplicationRecord
  # Enums
  enum :target_type, {
    community_event: 0,
    job_post: 1
  }, prefix: true

  enum :trigger_type, {
    days_before: 0,
    hours_before: 1
  }, prefix: true

  # Validations
  validates :name, presence: true
  validates :email_subject, presence: true
  validates :sendgrid_template_id, presence: true
  validates :trigger_value, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :enabled, inclusion: { in: [true, false] }

  # Scopes
  scope :enabled, -> { where(enabled: true) }
end
