# frozen_string_literal: true

# Profile 하위 리소스(experience, education, link, project 등) 컨트롤러의
# 소유권 검증을 공유한다.
#
# - create: 생성하려는 리소스의 profile 이 현재 사용자 소유인지 확인
# - update/destroy: 기존 리소스의 profile 이 현재 사용자 소유인지 확인
#
# create 시 부가 처리(예: 첨부 blob 연결)가 필요한 컨트롤러는
# create_after_init 를 직접 오버라이드하면 된다.
module ProfileOwnership
  extend ActiveSupport::Concern

  included do
    before_action :personal_check!, only: [ :create, :update, :destroy ]
    before_action :verify_ownership!, only: [ :update, :destroy ]
  end

  private

  def create_after_init
    return if @model.profile&.user_id == user_info.id

    raise CrudActions::JsonApiError.new("Forbidden", "자신의 프로필에만 추가할 수 있습니다.", 403)
  end

  def verify_ownership!
    return if @model.profile&.user_id == user_info.id

    raise CrudActions::JsonApiError.new("Forbidden", "자신의 리소스만 수정할 수 있습니다.", 403)
  end
end
