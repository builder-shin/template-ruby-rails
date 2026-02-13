# frozen_string_literal: true

module Api
  module V1
    class RecruitmentRequestsController < ApiController

      def model_params_options
        { only: [:company_name, :contact_name, :email, :phone, :message] }
      end
    end
  end
end
