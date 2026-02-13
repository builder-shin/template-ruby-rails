# frozen_string_literal: true

module Api
  module V1
    class ProfilesController < ApiController

      # 모든 액션에 인증 필요 (user_check! = 로그인 필수)
      before_action :user_check!
      # 공개 프로필 조회는 인증 없이 허용
      skip_before_action :user_check!, only: [:show]
      # 프로필 생성/수정/삭제는 개인회원만 가능
      before_action :personal_check!, only: [:create, :update, :destroy]
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [:user_id, :job_category_id, :nationality_id, :job_seeking_status, :start_work, :email_public, :domicile]
      end

      def model_params_options
        {
          only: [
            :name, :phone, :email_public, :profile_image, :introduction, :about,
            :job_category_id, :nationality_id, :domicile, :job_seeking_status, :start_work,
            :expertise, :practical_strength, :collaboration_and_communication,
            :problem_solving_and_execution, :total_years_of_experience,
            :skills, :employment_type, :work_type
          ]
        }
      end

      def allowed_includes
        [
          :user,
          :job_category,
          :jobs,
          :profile_highlights,
          :profile_experiences,
          :profile_freelance_experiences,
          :profile_projects,
          :profile_educations,
          :profile_languages,
          :profile_links,
          :profile_attachments
        ]
      end

      private

      def create_after_init
        @model.user_id = user_info.id
      end

      def verify_ownership!
        return if @model.user_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 프로필만 수정할 수 있습니다.", 403)
      end
    end
  end
end
