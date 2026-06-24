# frozen_string_literal: true

module Api
  module V1
    class ProfileLanguagesController < ApiController

      before_action :user_check!
      include ProfileOwnership

      def filter_attributes
        [:profile_id, :language, :proficiency]
      end

      def model_params_options
        {
          only: [:profile_id, :language, :proficiency]
        }
      end

      def allowed_includes
        [:profile]
      end
    end
  end
end
