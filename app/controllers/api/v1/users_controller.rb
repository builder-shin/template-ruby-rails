# frozen_string_literal: true

module Api
  module V1
    # 인증된 본인의 프로필. ApiController가 아니라 ApplicationController를 직접
    # 물려받는다 — ApiController는 CrudActions(색인·필터·페이지네이션 등 이
    # 단일 액션에는 필요 없는 것들)와, 이 태스크가 대체하는 레거시
    # set_current_user/AuthServiceClient 흐름(before_action)을 함께 물려준다.
    # 후자를 물려받고 skip_before_action으로 다시 걷어내는 것보다, 애초에 필요
    # 없는 걸 물려받지 않는 편이 더 정직하다.
    #
    # 정본에서 확인한 사실: /users/me는 get_current_user를 쓴다(get_current_active_user가
    # 아니다) — 비활성 사용자도 자기 계정이 비활성 상태라는 것 자체는 볼 수
    # 있어야 한다는 뜻이다. JsonapiAuthentication#authenticate_user!가 그 갈래다.
    class UsersController < ApplicationController
      include JsonapiAuthentication

      before_action :authenticate_user!, only: :me

      def me
        render jsonapi: Current.user
      end
    end
  end
end
