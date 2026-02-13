# frozen_string_literal: true

module Api
  module V1
    class JobApplicationsController < ApiController

      before_action :user_check!
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [:job_post_id, :profile_id, :status]
      end

      def index_scope
        return klass.where(job_post_id: JobPost.where(workspace_id: user_info.workspace_id).select(:id)) if user_info.workspace_kind == "enterprise"

        profile = Profile.find_by(user_id: user_info.id)
        return klass.none unless profile

        klass.where(profile_id: profile.id)
      end

      def model_params_options
        return { only: [:status, :reviewed_at, :processed_at, :profile_viewed_at, :rejection_reason] } if user_info&.workspace_kind == "enterprise"

        { only: [:job_post_id, :email, :phone] }
      end

      def allowed_includes
        [:job_post, :profile]
      end

      private

      def create_after_init
        profile = Profile.find_by!(user_id: user_info.id)
        @model.profile_id = profile.id
        @model.submitted_at = Time.current

        # 프로필 스냅샷 자동 생성
        @model.profile_snapshot = {
          name: profile.name,
          introduction: profile.introduction,
          skills: profile.skills,
          job_category_id: profile.job_category_id,
          employment_type: profile.employment_type,
          work_type: profile.work_type,
          total_years_of_experience: profile.total_years_of_experience,
          expertise: profile.expertise,
          practical_strength: profile.practical_strength
        }
      end

      def create_after_save(success)
        return unless success
        SendNotificationJob.perform_later("notify_application_submitted", @model.id)
        SendNotificationJob.perform_later("notify_application_received", @model.id)
      end

      def update_after_assign
        # 취소 시 지원자 본인만 가능
        return unless @model.status_changed? && @model.status == "canceled"
        return if user_info.workspace_kind != "enterprise"

        raise JsonApiError.new("Forbidden", "지원자만 지원을 취소할 수 있습니다.", 403)
      end

      def update_after_save(success)
        return unless success
        return unless @model.saved_change_to_status?

        new_status = @model.status
        old_int = @model.saved_changes["status"]&.first
        old_status = old_int.present? ? JobApplication.statuses.key(old_int) : nil

        case new_status
        when "document_passed"
          SendNotificationJob.perform_later("notify_screening_passed", @model.id)
        when "final_passed"
          SendNotificationJob.perform_later("notify_final_passed", @model.id)
        when "rejected"
          SendNotificationJob.perform_later("notify_rejected", @model.id, old_status)
        end
      end

      def verify_ownership!
        return verify_enterprise_ownership! if user_info.workspace_kind == "enterprise"

        profile = Profile.find_by(user_id: user_info.id)
        return if profile && @model.profile_id == profile.id

        raise JsonApiError.new("Forbidden", "자신의 지원서만 수정할 수 있습니다.", 403)
      end

      def verify_enterprise_ownership!
        return if JobPost.exists?(id: @model.job_post_id, workspace_id: user_info.workspace_id)

        raise JsonApiError.new("Forbidden", "자신의 워크스페이스 지원서만 수정할 수 있습니다.", 403)
      end
    end
  end
end
