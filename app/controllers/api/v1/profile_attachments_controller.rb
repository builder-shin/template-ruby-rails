# frozen_string_literal: true

module Api
  module V1
    class ProfileAttachmentsController < ApiController

      before_action :user_check!
      include ProfileOwnership

      def filter_attributes
        [:profile_id, :mime_type]
      end

      def model_params_options
        # url is optional now - can use signed_blob_id instead
        { only: [:profile_id, :url, :sort_order] }
      end

      def allowed_includes
        [:profile]
      end

      private

      def create_after_init
        raise JsonApiError.new("Forbidden", "자신의 프로필에만 추가할 수 있습니다.", 403) unless @model.profile&.user_id == user_info.id

        attach_blob_from_signed_id if signed_blob_id.present?
      end

      def update_after_assign
        # Handle blob replacement on update if signed_blob_id provided
        attach_blob_from_signed_id if signed_blob_id.present?
      end

      def signed_blob_id
        params.dig(:data, :attributes, :"signed-blob-id") ||
          params.dig(:data, :attributes, :signed_blob_id)
      end

      def attach_blob_from_signed_id
        blob = ActiveStorage::Blob.find_signed!(signed_blob_id)

        @model.file.attach(blob)
        @model.original_file_name = blob.filename.to_s
        @model.mime_type = blob.content_type
        @model.file_size = blob.byte_size
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        raise JsonApiError.new("BadRequest", "유효하지 않은 파일 서명입니다.", 400)
      end
    end
  end
end
