# frozen_string_literal: true

#
# ============================================================
# [참고용 예시 파일] - REFERENCE ONLY
# 이 파일은 프로젝트의 모델 작성 패턴을 보여주기 위한 예시입니다.
# 실제 사용 시 이 파일을 삭제하고 새로운 모델을 생성하세요.
# ============================================================
#

# == Schema Information
#
# Table name: examples
#
#  id           :bigint           not null, primary key
#  title        :string           not null
#  content      :text
#  view_count   :integer          default(0), not null
#  status       :integer          default("draft"), not null
#  published_at :datetime
#  user_id      :bigint           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_examples_on_status   (status)
#  index_examples_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

class Example < ApplicationRecord
  # ============================================================
  # Associations (연관관계)
  # ============================================================

  # 필수 관계: 게시글은 반드시 작성자가 있어야 함
  belongs_to :user

  # 일대다 관계: 게시글은 여러 개의 댓글을 가질 수 있음
  has_many :comments, dependent: :destroy

  # 일대다 관계: 게시글은 여러 개의 태그를 가질 수 있음 (중간 테이블 사용)
  has_many :example_tags, dependent: :destroy
  has_many :tags, through: :example_tags

  # 일대일 관계: 게시글은 하나의 메타데이터를 가질 수 있음
  has_one :metadata, class_name: 'ExampleMetadata', dependent: :destroy

  # ============================================================
  # Enums (열거형)
  # ============================================================

  # 게시글 상태: draft(초안), published(게시됨), archived(보관됨)
  # prefix를 사용하여 메서드명 충돌 방지 (status_draft?, status_published? 등)
  enum :status, { draft: 0, published: 1, archived: 2 }, prefix: :status

  # ============================================================
  # Validations (유효성 검증)
  # ============================================================

  # 필수 필드 검증
  validates :title, presence: { message: '제목은 필수입니다' }
  validates :user, presence: true

  # 길이 검증
  validates :title, length: {
    minimum: 2,
    maximum: 200,
    too_short: '제목은 최소 %{count}자 이상이어야 합니다',
    too_long: '제목은 최대 %{count}자를 초과할 수 없습니다'
  }

  # 고유성 검증
  validates :title, uniqueness: {
    scope: :user_id,
    message: '이미 같은 제목의 게시글이 있습니다',
    case_sensitive: false
  }

  # 숫자 검증
  validates :view_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    message: '조회수는 0 이상의 정수여야 합니다'
  }

  # 커스텀 검증
  validate :published_at_cannot_be_in_the_future, if: :status_published?
  validate :content_must_exist_when_published

  # ============================================================
  # Scopes (스코프)
  # ============================================================

  # 기본 스코프: 최신순 정렬
  scope :recent, -> { order(created_at: :desc) }

  # 조건부 스코프: 게시된 게시글만
  scope :published_only, -> { where(status: :published) }

  # 조건부 스코프: 보관된 게시글 제외
  scope :active, -> { where.not(status: :archived) }

  # 파라미터를 받는 스코프: 특정 사용자의 게시글
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # 파라미터를 받는 스코프: 제목으로 검색
  scope :search_by_title, ->(keyword) {
    where('title ILIKE ?', "%#{keyword}%") if keyword.present?
  }

  # 복합 스코프: 인기 게시글 (조회수 100 이상)
  scope :popular, -> { where('view_count >= ?', 100) }

  # 날짜 범위 스코프
  scope :created_between, ->(start_date, end_date) {
    where(created_at: start_date.beginning_of_day..end_date.end_of_day)
  }

  # ============================================================
  # Callbacks (콜백)
  # ============================================================

  # 유효성 검증 전 실행: 제목 공백 제거
  before_validation :strip_title

  # 생성 전 실행: 게시 시간 설정
  before_create :set_published_at_if_published

  # 생성 후 실행: 통계 업데이트
  after_create :update_user_statistics

  # 업데이트 후 실행: 캐시 무효화
  after_update :invalidate_cache, if: :saved_change_to_status?

  # ============================================================
  # Class Methods (클래스 메서드)
  # ============================================================

  # 오늘 작성된 게시글 개수
  def self.today_count
    where('created_at >= ?', Time.zone.now.beginning_of_day).count
  end

  # 가장 인기 있는 게시글 N개
  def self.most_popular(limit = 10)
    published_only.order(view_count: :desc).limit(limit)
  end

  # 통계 데이터 반환
  def self.statistics
    {
      total: count,
      published: status_published.count,
      draft: status_draft.count,
      archived: status_archived.count,
      average_views: average(:view_count).to_f.round(2)
    }
  end

  # ============================================================
  # Instance Methods (인스턴스 메서드)
  # ============================================================

  # 조회수 증가
  def increment_view_count!
    increment!(:view_count)
  end

  # 게시 가능 여부 확인
  def publishable?
    content.present? && title.present? && status_draft?
  end

  # 게시글 게시
  def publish!
    return false unless publishable?

    update!(
      status: :published,
      published_at: Time.current
    )
  end

  # 게시글 보관
  def archive!
    update!(status: :archived)
  end

  # 게시된 지 며칠 지났는지
  def days_since_published
    return nil unless published_at

    (Time.current - published_at).to_i / 1.day
  end

  # 짧은 요약 텍스트
  def summary(length = 100)
    return '' if content.blank?

    content.truncate(length, separator: ' ')
  end

  # 작성자 이름
  def author_name
    user&.name || 'Unknown'
  end

  private

  # ============================================================
  # Private Methods (비공개 메서드)
  # ============================================================

  # 제목 공백 제거
  def strip_title
    self.title = title&.strip
  end

  # 게시 상태일 때 게시 시간 설정
  def set_published_at_if_published
    self.published_at = Time.current if status_published? && published_at.blank?
  end

  # 사용자 통계 업데이트
  def update_user_statistics
    # 실제 구현에서는 비동기 작업으로 처리 권장
    user.increment!(:posts_count) if user
  end

  # 캐시 무효화
  def invalidate_cache
    Rails.cache.delete(['example', id])
  end

  # 커스텀 유효성 검증: 미래 날짜 금지
  def published_at_cannot_be_in_the_future
    if published_at.present? && published_at > Time.current
      errors.add(:published_at, '미래 날짜로 설정할 수 없습니다')
    end
  end

  # 커스텀 유효성 검증: 게시 상태일 때 내용 필수
  def content_must_exist_when_published
    if status_published? && content.blank?
      errors.add(:content, '게시 상태에서는 내용이 필수입니다')
    end
  end
end
