# frozen_string_literal: true

module Api
  module V1
    class CareerHubCommunityFeedsController < ApiController

      before_action :user_check!, except: [:index, :show]
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [:community_id, :author_id, :parent_id, :root_id, :status, :pinned]
      end

      def model_params_options
        {
          only: [
            :community_id, :content,
            :parent_id, :root_id
          ]
        }
      end

      def allowed_includes
        [:career_hub_community, :parent, :root]
      end

      private

      def create_after_init
        @model.author_id = user_info.id
        @model.likes_count ||= 0
        @model.replies_count ||= 0
      end

      def update_after_init
        pinned_param = params.dig(:data, :attributes, :pinned)
        return unless pinned_param.present?

        community_leader_check!(@model.community_id)
        @model.pinned = ActiveModel::Type::Boolean.new.cast(pinned_param)
        @model.pinned_at = @model.pinned ? Time.current : nil
      end

      def update_after_assign
        @model.content_edited_at = Time.current if @model.content_changed?
      end

      # Soft delete: set status to 'deleted' instead of actual destroy
      def destroy
        destroy_after_init
        return if performed?

        ActiveRecord::Base.transaction do
          # 대댓글도 soft delete
          if @model.replies.visible.exists?
            @model.replies.visible.update_all(status: :deleted)
          end

          # Soft delete 시 replies_count 수동 감소
          if @model.parent_id.present?
            CareerHubCommunityFeed.update_counters(@model.parent_id, replies_count: -1)
          end

          @model.update!(status: :deleted, replies_count: 0)
        end

        head :no_content
      end

      def verify_ownership!
        return if @model.author_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 피드만 수정할 수 있습니다.", 403)
      end
    end
  end
end
