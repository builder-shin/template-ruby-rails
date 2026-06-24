# frozen_string_literal: true

module Api
  module V1
    class BlogViewsController < ApiController
      def filter_attributes
        []
      end

      def model_params_options
        {
          only: [ :blog_post_id ]
        }
      end

      def allowed_includes
        [ :blog_post ]
      end

      private

      def create_after_init
        @model.user_id = user_info&.id
        @model.ip_address = request.remote_ip
      end
    end
  end
end
