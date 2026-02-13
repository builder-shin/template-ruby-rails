# frozen_string_literal: true

class RecruitmentRequestSerializer < ApplicationSerializer
  attributes :id, :company_name, :contact_name, :email, :phone, :message,
             :status, :created_at, :updated_at
end
