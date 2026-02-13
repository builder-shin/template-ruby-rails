# frozen_string_literal: true

module Api
  module V1
    class JobPostStatusLogsController < ApiController

      before_action :user_check!
      before_action :enterprise_check!

      def filter_attributes
        [:job_post_id, :changed_by, :changed_by_type, :from_status, :to_status, :changed_at]
      end

      def allowed_includes
        [:job_post]
      end

      private

      def index_scope
        klass.where(job_post_id: JobPost.where(workspace_id: user_info.workspace_id).select(:id))
      end
    end
  end
end
