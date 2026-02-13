# frozen_string_literal: true

class ApplicationContextReferenceSerializer < ApplicationSerializer
  attributes :id, :job_category_id, :reference, :created_at, :updated_at

  belongs_to :job_category
end
