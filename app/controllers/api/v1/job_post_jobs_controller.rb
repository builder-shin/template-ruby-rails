# frozen_string_literal: true

module Api
  module V1
    class JobPostJobsController < ApiController
      before_action :user_check!, except: [:index, :show]
      before_action :enterprise_check!, only: [:create, :update, :destroy]
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [:job_post_id, :job_id]
      end

      def model_params_options
        { only: [:job_post_id, :job_id] }
      end

      def allowed_includes
        [:job_post, :job]
      end

      private

      def create_after_init
        job_post = JobPost.find_by(id: @model.job_post_id)
        return if job_post&.workspace_id == user_info.workspace_id
        raise JsonApiError.new("Forbidden", "자신의 워크스페이스 공고에만 추가할 수 있습니다.", 403)
      end

      def verify_ownership!
        return if @model.job_post&.workspace_id == user_info.workspace_id
        raise JsonApiError.new("Forbidden", "자신의 워크스페이스 리소스만 수정할 수 있습니다.", 403)
      end
    end
  end
end
