# frozen_string_literal: true

require "rails_helper"

# string 컬럼 + CHECK 제약과 enum 선언의 정합성을 보장하는 회귀 가드.
# (string 컬럼에 정수 enum 을 선언하면 저장 시 CHECK 제약 위반으로 깨진다)
RSpec.describe BlogPost, type: :model do
  def build_post(attrs = {})
    BlogPost.new({
      author_id: SecureRandom.uuid,
      author_type: :personal,
      title: "제목",
      slug: "slug-#{SecureRandom.hex(6)}",
      content: "본문",
      status: :draft,
      views: 0,
      main_image_size: 0
    }.merge(attrs))
  end

  it "모든 status enum 값이 DB 에 저장/조회된다 (CHECK 제약 통과)" do
    BlogPost.statuses.each_key do |status|
      post = build_post(status: status)
      expect(post.save).to be(true), "status=#{status} 저장 실패: #{post.errors.full_messages}"
      expect(post.reload.status).to eq(status.to_s)
    end
  end

  it "모든 author_type enum 값이 DB 에 저장/조회된다 (CHECK 제약 통과)" do
    BlogPost.author_types.each_key do |type|
      post = build_post(author_type: type)
      expect(post.save).to be(true), "author_type=#{type} 저장 실패: #{post.errors.full_messages}"
      expect(post.reload.author_type).to eq(type.to_s)
    end
  end
end
