# frozen_string_literal: true

module Api
  module V1
    class DirectUploadsController < ApiController
      before_action :user_check!
      before_action :validate_upload_params
      before_action :validate_ownership

      # Extended content types for Career Hub (adds SVG)
      ALLOWED_CONTENT_TYPES = (ProfileAttachment::ALLOWED_CONTENT_TYPES + %w[image/svg+xml]).freeze
      MAX_FILE_SIZE = ProfileAttachment::MAX_FILE_SIZE

      DEFAULT_PREFIX = "uploads"

      # Valid upload contexts
      UPLOAD_CONTEXTS = %w[profile community event leader feed general].freeze

      # UUID format pattern
      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      def create
        blob = ActiveStorage::Blob.create_before_direct_upload!(
          key: generate_unique_key,
          filename: upload_params[:filename],
          byte_size: upload_params[:byte_size],
          checksum: upload_params[:checksum],
          content_type: upload_params[:content_type],
          service_name: Rails.configuration.active_storage.service
        )

        render json: {
          data: {
            id: blob.signed_id,
            type: "direct-uploads",
            attributes: {
              "signed-id": blob.signed_id,
              "key": blob.key,
              "direct-upload-url": blob.service_url_for_direct_upload,
              "headers": headers_for_direct_upload(blob)
            }
          }
        }, status: :created
      end

      private

      def upload_params
        @upload_params ||= begin
          attrs = params.dig(:data, :attributes) || {}
          {
            filename: attrs[:filename] || attrs[:"filename"],
            content_type: attrs[:"content-type"] || attrs[:content_type],
            byte_size: (attrs[:"byte-size"] || attrs[:byte_size]).to_i,
            checksum: attrs[:checksum],
            prefix: sanitize_prefix(attrs[:prefix] || attrs[:"prefix"]),
            profile_id: attrs[:"profile-id"] || attrs[:profile_id],
            image_type: attrs[:"image-type"] || attrs[:image_type],
            upload_context: attrs[:"upload-context"] || attrs[:upload_context] || "general",
            context_id: attrs[:"context-id"] || attrs[:context_id]
          }
        end
      end

      # Generate unique S3 key based on upload context
      def generate_unique_key
        uuid = SecureRandom.hex(8)
        sanitized_filename = sanitize_filename(upload_params[:filename])

        case upload_params[:upload_context]
        when "profile"
          generate_profile_key(uuid, sanitized_filename)
        when "community"
          "career-hub/communities/#{upload_params[:context_id]}/#{uuid}_#{sanitized_filename}"
        when "event"
          "career-hub/events/#{upload_params[:context_id]}/#{uuid}_#{sanitized_filename}"
        when "leader"
          "career-hub/leaders/#{upload_params[:context_id]}/#{uuid}_#{sanitized_filename}"
        when "feed"
          "career-hub/feeds/#{upload_params[:context_id]}/#{uuid}_#{sanitized_filename}"
        else
          prefix = upload_params[:prefix]
          "#{prefix}/#{uuid}_#{sanitized_filename}"
        end
      end

      def generate_profile_key(uuid, sanitized_filename)
        return "#{upload_params[:prefix]}/#{uuid}_#{sanitized_filename}" if upload_params[:profile_id].blank?

        subfolder = upload_params[:image_type] == "profile" ? "images" : "attachments"
        "profiles/#{upload_params[:profile_id]}/#{subfolder}/#{uuid}_#{sanitized_filename}"
      end

      # Sanitize filename for S3 key compatibility
      def sanitize_filename(filename)
        basename = File.basename(filename.to_s)
        ext = File.extname(basename)
        name = File.basename(basename, ext)

        sanitized_name = name
          .gsub(/[^\w\-\u{AC00}-\u{D7AF}]/, "_")
          .gsub(/_+/, "_")
          .gsub(/^_|_$/, "")
          .presence || "file"

        sanitized_ext = ext.gsub(/[^\w.]/, "")
        "#{sanitized_name}#{sanitized_ext}"
      end

      # Sanitize prefix - allow any path but prevent traversal attacks
      def sanitize_prefix(prefix)
        return DEFAULT_PREFIX if prefix.blank?

        prefix
          .to_s
          .gsub(/\.\./, "")
          .gsub(/\/+/, "/")
          .gsub(/^\/|\/+$/, "")
          .gsub(/[^\w\/\-]/, "_")
          .presence || DEFAULT_PREFIX
      end

      # Context-aware ownership validation
      def validate_ownership
        context = upload_params[:upload_context]
        return if context == "general"
        return validate_profile_ownership if context == "profile"

        validate_context_ownership
      end

      def validate_profile_ownership
        return if upload_params[:profile_id].blank?

        profile_id = upload_params[:profile_id].to_s
        validate_uuid_format!(profile_id, "프로필")

        profile = Profile.find_by(id: profile_id)
        raise JsonApiError.new("NotFound", "프로필을 찾을 수 없습니다.", 404) if profile.nil?
        return if profile.user_id == user_info.id

        raise JsonApiError.new("Forbidden", "자신의 프로필에만 파일을 업로드할 수 있습니다.", 403)
      end

      def validate_context_ownership
        context = upload_params[:upload_context]
        context_id = upload_params[:context_id]

        raise JsonApiError.new("BadRequest", "#{context} 업로드에는 context-id가 필요합니다.", 400) if context_id.blank?

        validate_uuid_format!(context_id.to_s, context)

        case context
        when "community"
          validate_community_ownership(context_id)
        when "event"
          validate_event_ownership(context_id)
        when "leader"
          validate_leader_ownership(context_id)
        when "feed"
          validate_feed_ownership(context_id)
        end
      end

      def validate_community_ownership(community_id)
        community = CareerHubCommunity.find_by(id: community_id)
        raise JsonApiError.new("NotFound", "커뮤니티를 찾을 수 없습니다.", 404) if community.nil?

        leader = CareerHubCommunityLeader.find_by(user_id: user_info.id, status: :approved)
        return if leader && community.leader_id == leader.id

        raise JsonApiError.new("Forbidden", "커뮤니티 리더만 파일을 업로드할 수 있습니다.", 403)
      end

      def validate_event_ownership(event_id)
        event = CareerHubCommunityEvent.find_by(id: event_id)
        raise JsonApiError.new("NotFound", "이벤트를 찾을 수 없습니다.", 404) if event.nil?

        # Event ownership is through community leader
        community = event.career_hub_community
        return if community.nil?

        leader = CareerHubCommunityLeader.find_by(user_id: user_info.id, status: :approved)
        return if leader && community.leader_id == leader.id

        raise JsonApiError.new("Forbidden", "커뮤니티 리더만 이벤트 파일을 업로드할 수 있습니다.", 403)
      end

      def validate_leader_ownership(leader_id)
        leader = CareerHubCommunityLeader.find_by(id: leader_id)
        raise JsonApiError.new("NotFound", "리더 프로필을 찾을 수 없습니다.", 404) if leader.nil?
        return if leader.user_id == user_info.id

        raise JsonApiError.new("Forbidden", "자신의 리더 프로필에만 파일을 업로드할 수 있습니다.", 403)
      end

      def validate_feed_ownership(community_id)
        community = CareerHubCommunity.find_by(id: community_id)
        raise JsonApiError.new("NotFound", "커뮤니티를 찾을 수 없습니다.", 404) if community.nil?

        # Feed uploads allowed for community members
        member = CareerHubCommunityMember.find_by(community_id: community_id, user_id: user_info.id, status: :active)
        return if member

        # Also allow community leader
        leader = CareerHubCommunityLeader.find_by(user_id: user_info.id, status: :approved)
        return if leader && community.leader_id == leader.id

        raise JsonApiError.new("Forbidden", "커뮤니티 멤버만 피드에 파일을 업로드할 수 있습니다.", 403)
      end

      def validate_uuid_format!(id, label)
        return if id.match?(UUID_PATTERN)

        raise JsonApiError.new("BadRequest", "유효하지 않은 #{label} ID 형식입니다.", 400)
      end

      def validate_upload_params
        validate_required_params
        validate_upload_context
        validate_content_type
        validate_file_size
      end

      def validate_required_params
        missing = []
        missing << "filename" if upload_params[:filename].blank?
        missing << "content-type" if upload_params[:content_type].blank?
        missing << "byte-size" if upload_params[:byte_size].zero?
        missing << "checksum" if upload_params[:checksum].blank?

        return if missing.empty?

        raise JsonApiError.new(
          "BadRequest",
          "필수 파라미터가 누락되었습니다: #{missing.join(', ')}",
          400
        )
      end

      def validate_upload_context
        return if UPLOAD_CONTEXTS.include?(upload_params[:upload_context])

        raise JsonApiError.new(
          "BadRequest",
          "유효하지 않은 업로드 컨텍스트입니다. 허용: #{UPLOAD_CONTEXTS.join(', ')}",
          400
        )
      end

      def validate_content_type
        return if ALLOWED_CONTENT_TYPES.include?(upload_params[:content_type])

        raise JsonApiError.new(
          "BadRequest",
          "허용되지 않는 파일 형식입니다. 허용 형식: PDF, Word, JPEG, PNG, GIF, WebP, SVG",
          422
        )
      end

      def validate_file_size
        return if upload_params[:byte_size] <= MAX_FILE_SIZE

        raise JsonApiError.new(
          "BadRequest",
          "파일 크기가 #{MAX_FILE_SIZE / 1.megabyte}MB를 초과합니다.",
          422
        )
      end

      def headers_for_direct_upload(blob)
        headers = {
          "Content-Type" => blob.content_type,
          "Content-MD5" => blob.checksum
        }

        if blob.content_type == "image/svg+xml"
          headers["Content-Disposition"] = "attachment; filename=\"#{blob.filename}\""
        end

        headers
      end
    end
  end
end
