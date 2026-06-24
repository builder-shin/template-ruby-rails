# frozen_string_literal: true

module Api
  module V1
    class ProfileLinksController < ApiController

      before_action :user_check!
      include ProfileOwnership

      def filter_attributes
        [:profile_id]
      end

      def model_params_options
        {
          only: [:profile_id, :url]
        }
      end

      def allowed_includes
        [:profile]
      end
    end
  end
end
