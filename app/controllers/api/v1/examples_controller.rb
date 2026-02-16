# frozen_string_literal: true

#
# ============================================================
# [참고용 예시 파일] - REFERENCE ONLY
# 이 파일은 프로젝트의 컨트롤러 작성 패턴을 보여주기 위한 예시입니다.
# 실제 사용 시 이 파일을 삭제하고 새로운 컨트롤러를 생성하세요.
# ============================================================
#

module Api
  module V1
    # Example 리소스에 대한 CRUD API 컨트롤러
    #
    # 이 컨트롤러는 다음 패턴들을 보여줍니다:
    # - ApiController 상속 (CrudActions concern 자동 포함)
    # - 인증 체크 (user_check!)
    # - Ransack 필터 설정
    # - JSONAPI include 허용 목록
    # - JSONAPI deserialization 파라미터 설정
    # - 커스텀 scope 설정
    # - CrudActions 훅 활용
    # - 커스텀 액션 추가
    class ExamplesController < ApiController
      # ==================== before_action ====================
      # 모든 액션 실행 전 사용자 인증 확인
      # user_check!: 일반 사용자 인증 (ApiController에서 제공)
      # enterprise_check!: 기업 사용자 인증
      # personal_check!: 개인 사용자 인증
      before_action :user_check!

      # 특정 액션에만 적용되는 before_action 예시
      before_action :set_example, only: [:custom_action]

      # ==================== Ransack 필터 설정 ====================
      # index 액션에서 사용 가능한 Ransack 필터 속성 정의
      # _eq, _cont, _gt, _lt 등의 조건자(predicate)를 사용할 수 있습니다
      # 예: GET /api/v1/examples?filter[name_cont]=test&filter[status_eq]=active
      def filter_attributes
        %w[
          name
          status
          created_at
          updated_at
          user_id
        ]
      end

      # ==================== JSONAPI include 허용 목록 ====================
      # include 파라미터로 요청할 수 있는 관계(association) 정의
      # 예: GET /api/v1/examples?include=user,category
      def allowed_includes
        %w[
          user
          category
          tags
        ]
      end

      # ==================== JSONAPI deserialization 설정 ====================
      # create/update 액션에서 허용할 파라미터 설정
      # only: 허용할 속성만 명시
      # except: 제외할 속성 명시
      def model_params_options
        {
          only: %i[
            name
            description
            status
            category_id
            metadata
          ]
          # 또는 except 사용:
          # except: %i[id created_at updated_at]
        }
      end

      # ==================== 커스텀 기본 scope ====================
      # index 액션의 기본 쿼리 scope 설정
      # 예: 현재 사용자의 레코드만 조회하거나, 특정 조건 추가
      def index_scope
        # current_user는 ApiController에서 제공
        klass.where(user_id: current_user.id).includes(:category)
      end

      # ==================== CrudActions 훅 ====================
      # create 액션에서 모델 초기화 직후 호출
      # 기본값 설정이나 추가 속성 할당에 사용
      def create_after_init
        @model.user = current_user
        @model.status ||= 'draft'
      end

      # create 액션에서 저장 성공 후 호출
      # 성공 여부(success)를 인자로 받음
      def create_after_save(success)
        if success
          # 알림 전송, 로그 기록 등
          Rails.logger.info "Example created: #{@model.id}"
        end
      end

      # update 액션에서 모델 조회 직후 호출
      def update_after_init
        # 권한 체크 등 추가 로직
        raise JsonApiError.new("Forbidden", "수정 권한이 없습니다.", 403) unless @model.user_id == current_user.id
      end

      # update 액션에서 속성 할당 직후, 저장 전 호출
      def update_after_assign
        # 변경사항에 따른 추가 처리
        @model.updated_by = current_user.id if @model.changed?
      end

      # update 액션에서 저장 성공 후 호출
      def update_after_save(success)
        if success
          Rails.logger.info "Example updated: #{@model.id}"
        end
      end

      # destroy 액션에서 모델 조회 직후 호출
      def destroy_after_init
        # 삭제 권한 체크
        raise JsonApiError.new("Forbidden", "삭제 권한이 없습니다.", 403) unless @model.user_id == current_user.id
      end

      # destroy 액션에서 삭제 성공 후 호출
      def destroy_after_save(success)
        if success
          Rails.logger.info "Example destroyed: #{@model.id}"
        end
      end

      # show 액션에서 모델 조회 직후 호출
      def show_after_init
        # 조회 권한 체크
        raise JsonApiError.new("Forbidden", "조회 권한이 없습니다.", 403) unless can_view?(@model)
      end

      # new 액션에서 모델 초기화 직후 호출
      def new_after_init
        @model.user = current_user
      end

      # ==================== Upsert 훅 ====================
      # upsert 액션에서 레코드를 찾기 위한 고유 키 반환
      # 반드시 해시를 반환해야 함 (find_or_initialize_by에 전달됨)
      # jsonapi_deserialize는 string key를 반환하므로 string key로 접근해야 합니다
      def upsert_find_params
        { external_id: model_params["external_id"] }
      end

      # upsert 액션에서 모델 초기화/조회 직후 호출
      def upsert_after_init
        @model.user = current_user if @model.new_record?
      end

      # upsert 액션에서 속성 할당 직후, 저장 전 호출
      def upsert_after_assign
        @model.updated_by = current_user.id if @model.changed?
      end

      # upsert 액션에서 저장 후 호출
      # success: 저장 성공 여부, created: 새로 생성된 레코드인지 여부
      def upsert_after_save(success, created)
        if success
          action = created ? 'created' : 'updated'
          Rails.logger.info "Example #{action}: #{@model.id}"
        end
      end

      # ==================== 커스텀 액션 ====================
      # CRUD 외 추가 액션 예시
      # POST /api/v1/examples/:id/publish
      def custom_action
        @example.update!(status: 'published', published_at: Time.current)

        render jsonapi: @example, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render jsonapi_errors: e.record.errors, status: :unprocessable_entity
      end

      private

      # ==================== Private 헬퍼 메서드 ====================

      # 특정 액션을 위한 레코드 조회
      def set_example
        @example = klass.find(params[:id])
      end

      # 권한 체크 헬퍼
      def can_view?(object)
        # 본인 레코드이거나 공개 상태인 경우
        object.user_id == current_user.id || object.status == 'published'
      end

      # 추가 비즈니스 로직 헬퍼 예시
      def notify_followers(object)
        # 팔로워에게 알림 전송 로직
      end
    end
  end
end
