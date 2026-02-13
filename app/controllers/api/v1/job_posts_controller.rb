# frozen_string_literal: true

module Api
  module V1
    class JobPostsController < ApiController

      before_action :user_check!, except: [:index, :show]
      before_action :enterprise_check!, only: [:create, :update, :destroy]
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [:workspace_id, :status, :employment_type, :deadline_type, :publication_type, :experience_level, :title, :priority, :language_required]
      end

      def model_params_options
        { only: [:title, :description, :priority, :language_required, :skills, :contract_conditions, :deadline, :scheduled_publish_date, :employment_type, :deadline_type, :publication_type, :experience_level] }
      end

      def allowed_includes
        [:job_applications, :job_post_categories, :job_post_jobs, :jobs, :job_post_languages, :job_post_status_logs]
      end

      private

      def show_after_init
        # 공고 소유자가 아닌 경우 조회수 증가
        return unless user_info.present?
        return if @model.workspace_id == user_info.workspace_id

        JobPost.update_counters(@model.id, view_count: 1)
        @model.reload
      end

      def create_after_init
        @model.workspace_id = user_info.workspace_id
      end

      def update_after_save(success)
        return unless success
        return unless @model.saved_change_to_status?

        new_status = @model.status
        case new_status
        when "pending_review"
          SendNotificationJob.perform_later("notify_job_post_pending", @model.id, @model.workspace_id)
        when "recruiting"
          SendNotificationJob.perform_later("notify_job_post_published", @model.id)
        end
      end

      def verify_ownership!
        return if @model.workspace_id == user_info.workspace_id
        raise JsonApiError.new("Forbidden", "자신의 워크스페이스 공고만 수정할 수 있습니다.", 403)
      end
    end
  end
end
