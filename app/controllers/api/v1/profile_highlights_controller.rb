# frozen_string_literal: true

module Api
  module V1
    class ProfileHighlightsController < ApiController

      before_action :user_check!
      include ProfileOwnership

      def filter_attributes
        [:profile_id, :title]
      end

      def model_params_options
        {
          only: [:profile_id, :title, :after, :details, :before, :action]
        }
      end

      def allowed_includes
        [:profile]
      end
    end
  end
end
