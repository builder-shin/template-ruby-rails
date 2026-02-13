# frozen_string_literal: true

class HighlightReferenceSerializer < ApplicationSerializer
  attributes :id, :job_category_id, :reference, :highlight_type, :created_at, :updated_at

  belongs_to :job_category
end
