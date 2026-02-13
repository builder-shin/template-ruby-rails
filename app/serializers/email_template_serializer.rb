# frozen_string_literal: true

class EmailTemplateSerializer < ApplicationSerializer
  attributes :key, :name, :description, :subject, :sendgrid_template_id,
             :is_enabled, :created_at, :updated_at
end
