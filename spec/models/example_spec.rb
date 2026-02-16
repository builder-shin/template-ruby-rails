# frozen_string_literal: true

#
# ============================================================
# [참고용 예시 파일] - REFERENCE ONLY
# 이 파일은 프로젝트의 모델 스펙 작성 패턴을 보여주기 위한 예시입니다.
# 실제 사용 시 이 파일을 삭제하고 새로운 스펙을 생성하세요.
# ============================================================
#

require 'rails_helper'

RSpec.describe Example, type: :model do
  # ==================== Factory 설정 ====================
  # let: 지연 평가 (lazy evaluation) - 사용할 때 생성
  # let!: 즉시 평가 (eager evaluation) - 정의 시점에 생성
  # build: DB에 저장하지 않고 객체만 생성
  # create: DB에 저장
  let(:user) { create(:user) }
  let(:category) { create(:category) }
  let(:example) { build(:example, user: user, category: category) }
  let!(:persisted_example) { create(:example, user: user) }

  # ==================== Association 테스트 (shoulda-matchers) ====================
  describe 'associations' do
    # belongs_to 관계 테스트
    it { should belong_to(:user) }
    it { should belong_to(:category).optional }

    # has_many 관계 테스트
    it { should have_many(:comments).dependent(:destroy) }
    it { should have_many(:tags).through(:example_tags) }

    # has_one 관계 테스트
    it { should have_one(:setting).dependent(:destroy) }

    # has_and_belongs_to_many 관계 테스트
    it { should have_and_belong_to_many(:authors) }
  end

  # ==================== Validation 테스트 (shoulda-matchers) ====================
  describe 'validations' do
    # presence 검증
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:status) }

    # uniqueness 검증 (scope 포함)
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }

    # length 검증
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:description).is_at_least(10).is_at_most(1000) }

    # numericality 검증
    it { should validate_numericality_of(:priority).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:count).only_integer }

    # inclusion 검증
    it { should validate_inclusion_of(:status).in_array(%w[draft published archived]) }

    # format 검증
    it { should allow_value('test@example.com').for(:email) }
    it { should_not allow_value('invalid-email').for(:email) }

    # custom validation 테스트
    context 'when validating custom rules' do
      it 'is invalid if name contains special characters' do
        example.name = 'test@#$'
        expect(example).not_to be_valid
        expect(example.errors[:name]).to include('cannot contain special characters')
      end
    end
  end

  # ==================== Enum 테스트 (shoulda-matchers) ====================
  describe 'enums' do
    it { should define_enum_for(:status).with_values(draft: 0, published: 1, archived: 2) }
    it { should define_enum_for(:visibility).with_values(%i[private public unlisted]).backed_by_column_of_type(:integer) }
  end

  # ==================== Scope 테스트 ====================
  describe 'scopes' do
    let!(:published_example) { create(:example, status: 'published') }
    let!(:draft_example) { create(:example, status: 'draft') }
    let!(:archived_example) { create(:example, status: 'archived') }

    describe '.published' do
      it 'returns only published examples' do
        expect(Example.published).to include(published_example)
        expect(Example.published).not_to include(draft_example, archived_example)
      end
    end

    describe '.recent' do
      it 'returns examples ordered by created_at desc' do
        older = create(:example, created_at: 2.days.ago)
        newer = create(:example, created_at: 1.day.ago)

        expect(Example.recent.first).to eq(newer)
        expect(Example.recent.last).to eq(older)
      end
    end

    describe '.by_user' do
      it 'returns examples for specific user' do
        other_user = create(:user)
        other_example = create(:example, user: other_user)

        expect(Example.by_user(user)).to include(persisted_example)
        expect(Example.by_user(user)).not_to include(other_example)
      end
    end
  end

  # ==================== 인스턴스 메서드 테스트 ====================
  describe '#publish!' do
    context 'when example is in draft status' do
      before { example.status = 'draft' }

      it 'changes status to published' do
        example.publish!
        expect(example.status).to eq('published')
      end

      it 'sets published_at timestamp' do
        expect { example.publish! }.to change { example.published_at }.from(nil)
      end
    end

    context 'when example is already published' do
      before { example.status = 'published' }

      it 'raises an error' do
        expect { example.publish! }.to raise_error(StandardError, 'Already published')
      end
    end
  end

  describe '#can_edit?' do
    let(:owner) { user }
    let(:other_user) { create(:user) }

    it 'returns true for the owner' do
      expect(example.can_edit?(owner)).to be true
    end

    it 'returns false for other users' do
      expect(example.can_edit?(other_user)).to be false
    end

    context 'when example is published' do
      before { example.status = 'published' }

      it 'returns false even for owner' do
        expect(example.can_edit?(owner)).to be false
      end
    end
  end

  # ==================== 클래스 메서드 테스트 ====================
  describe '.search' do
    let!(:matching_example) { create(:example, name: 'Rails Tutorial', description: 'Learn Rails') }
    let!(:non_matching_example) { create(:example, name: 'Django Guide', description: 'Learn Django') }

    it 'finds examples by name' do
      results = Example.search('Rails')
      expect(results).to include(matching_example)
      expect(results).not_to include(non_matching_example)
    end

    it 'finds examples by description' do
      results = Example.search('Learn Rails')
      expect(results).to include(matching_example)
    end

    it 'is case-insensitive' do
      results = Example.search('rails')
      expect(results).to include(matching_example)
    end
  end

  # ==================== Callback 테스트 ====================
  describe 'callbacks' do
    describe 'before_save' do
      it 'normalizes name before saving' do
        example.name = '  Test Example  '
        example.save
        expect(example.name).to eq('Test Example')
      end
    end

    describe 'after_create' do
      it 'sends notification after creation' do
        expect(NotificationService).to receive(:notify).with(kind_of(Example))
        create(:example)
      end
    end

    describe 'before_destroy' do
      it 'archives instead of destroying if published' do
        published = create(:example, status: 'published')
        published.destroy

        expect(published.reload.status).to eq('archived')
        expect(Example.exists?(published.id)).to be true
      end
    end
  end

  # ==================== 조건부 테스트 (context/describe) ====================
  describe 'complex business logic' do
    context 'when example has tags' do
      let(:tag1) { create(:tag, name: 'ruby') }
      let(:tag2) { create(:tag, name: 'rails') }

      before do
        example.tags << [tag1, tag2]
        example.save
      end

      it 'returns tag names' do
        expect(example.tag_names).to match_array(%w[ruby rails])
      end

      it 'allows searching by tags' do
        expect(Example.tagged_with('ruby')).to include(example)
      end
    end

    context 'when example has no tags' do
      it 'returns empty array' do
        expect(example.tag_names).to be_empty
      end
    end
  end

  # ==================== Database 제약 조건 테스트 ====================
  describe 'database constraints' do
    it 'enforces NOT NULL on name' do
      expect { create(:example, name: nil) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'enforces foreign key on user_id' do
      expect { create(:example, user_id: 99999) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
