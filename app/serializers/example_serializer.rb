# frozen_string_literal: true

#
# ============================================================
# [참고용 예시 파일] - REFERENCE ONLY
# 이 파일은 프로젝트의 시리얼라이저 작성 패턴을 보여주기 위한 예시입니다.
# 실제 사용 시 이 파일을 삭제하고 새로운 시리얼라이저를 생성하세요.
# ============================================================
#

class ExampleSerializer < ApplicationSerializer
  # ============================================================
  # Basic Configuration (기본 설정)
  # ============================================================

  # 리소스 타입 명시 (JSONAPI 스펙)
  # set_type :example  # 기본값은 모델명의 복수형이므로 생략 가능

  # ============================================================
  # Attributes (속성)
  # ============================================================

  # 기본 속성: 모델의 속성을 그대로 노출
  attributes :id, :title, :content, :view_count, :created_at, :updated_at

  # Enum 속성: status는 정수이지만 문자열로 변환하여 노출
  attribute :status do |object|
    object.status
  end

  # 날짜/시간 속성: ISO8601 형식으로 변환
  attribute :published_at do |object|
    object.published_at&.iso8601
  end

  # ============================================================
  # Custom Attributes (커스텀 속성)
  # ============================================================

  # 계산된 속성: 게시된 지 며칠 지났는지
  attribute :days_since_published do |object|
    object.days_since_published
  end

  # 메서드 호출 결과를 속성으로 노출
  attribute :summary do |object|
    object.summary(150)
  end

  # 작성자 이름 (연관관계 데이터 포함)
  attribute :author_name do |object|
    object.author_name
  end

  # 상태 라벨 (한글)
  attribute :status_label do |object|
    case object.status
    when 'draft'
      '초안'
    when 'published'
      '게시됨'
    when 'archived'
      '보관됨'
    else
      '알 수 없음'
    end
  end

  # 게시 가능 여부
  attribute :is_publishable do |object|
    object.publishable?
  end

  # ============================================================
  # Conditional Attributes (조건부 속성)
  # ============================================================

  # 특정 조건에서만 노출되는 속성
  attribute :edit_url, if: proc { |record, params|
    # params[:current_user]가 작성자인 경우에만 노출
    params[:current_user]&.id == record.user_id
  } do |object, params|
    # 실제 URL 생성 로직
    "/examples/#{object.id}/edit"
  end

  # 관리자에게만 노출되는 속성
  attribute :internal_notes, if: proc { |_record, params|
    params[:current_user]&.admin?
  } do |object|
    object.metadata&.internal_notes
  end

  # ============================================================
  # Associations (연관관계)
  # ============================================================

  # belongs_to 관계: 작성자 정보
  belongs_to :user do |object|
    # 커스텀 시리얼라이저 지정 가능
    # UserSerializer.new(object.user)
    object.user
  end

  # has_many 관계: 댓글 목록
  has_many :comments do |object|
    # 최근 댓글만 포함
    object.comments.order(created_at: :desc).limit(5)
  end

  # has_many through 관계: 태그 목록
  has_many :tags

  # 조건부 연관관계: 게시된 상태일 때만 댓글 포함
  has_many :published_comments, if: proc { |record|
    record.status_published?
  } do |object|
    object.comments.where(published: true)
  end

  # ============================================================
  # Links (링크)
  # ============================================================

  # 리소스 관련 링크 제공
  link :self do |object|
    "/api/v1/examples/#{object.id}"
  end

  # 관련 리소스 링크
  link :comments do |object|
    "/api/v1/examples/#{object.id}/comments"
  end

  # 조건부 링크: 게시된 경우에만 공개 URL 제공
  link :public_url, if: proc { |record|
    record.status_published?
  } do |object|
    "https://example.com/posts/#{object.id}"
  end

  # ============================================================
  # Meta (메타데이터)
  # ============================================================

  # 리소스 레벨 메타데이터
  meta do |object, params|
    data = {
      copyright: '© 2026 Example Inc.',
      version: '1.0'
    }

    # 조건부 메타데이터 추가
    if params[:include_stats]
      data[:statistics] = {
        total_views: object.view_count,
        total_comments: object.comments.count,
        total_tags: object.tags.count
      }
    end

    data
  end

  # ============================================================
  # Class Methods (클래스 메서드)
  # ============================================================

  # 컬렉션용 시리얼라이저 옵션
  class << self
    # 컬렉션 메타데이터 생성
    def collection_meta(records, params = {})
      {
        total_count: records.size,
        published_count: records.count(&:status_published?),
        draft_count: records.count(&:status_draft?),
        generated_at: Time.current.iso8601
      }
    end

    # 페이지네이션 메타데이터 생성
    def pagination_meta(paginated_records)
      {
        current_page: paginated_records.current_page,
        next_page: paginated_records.next_page,
        prev_page: paginated_records.prev_page,
        total_pages: paginated_records.total_pages,
        total_count: paginated_records.total_count
      }
    end
  end

  # ============================================================
  # Usage Examples (사용 예시)
  # ============================================================
  #
  # 단일 리소스:
  #   ExampleSerializer.new(example).serializable_hash
  #
  # 컬렉션:
  #   ExampleSerializer.new(examples).serializable_hash
  #
  # 파라미터 전달:
  #   ExampleSerializer.new(example, params: { current_user: user }).serializable_hash
  #
  # 관계 포함:
  #   ExampleSerializer.new(example, include: [:user, :comments]).serializable_hash
  #
  # 메타데이터 포함:
  #   ExampleSerializer.new(
  #     examples,
  #     meta: ExampleSerializer.collection_meta(examples)
  #   ).serializable_hash
  #
  # 링크 포함:
  #   ExampleSerializer.new(
  #     examples,
  #     links: {
  #       self: '/api/v1/examples',
  #       next: '/api/v1/examples?page=2'
  #     }
  #   ).serializable_hash
  #
end
