# frozen_string_literal: true

class JobPostCategorySerializer < ApplicationSerializer
  attributes :job_post_id, :job_category_id

  belongs_to :job_post
  belongs_to :job_category
end
