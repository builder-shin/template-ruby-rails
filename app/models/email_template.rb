# == Schema Information
#
# Table name: email_templates
#
#  key                  :string(50)       not null, primary key
#  created_at           :timestamptz      not null
#  description          :text
#  is_enabled           :boolean          not null, default(true)
#  name                 :string(100)      not null
#  sendgrid_template_id :string(100)
#  subject              :string(255)
#  updated_at           :timestamptz      not null
#
# Indexes
#
#  IDX_email_templates_is_enabled  (is_enabled)
#

class EmailTemplate < ApplicationRecord
  self.primary_key = :key

  # Validations
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :is_enabled, inclusion: { in: [ true, false ] }

  # Scopes
  scope :enabled, -> { where(is_enabled: true) }
end
