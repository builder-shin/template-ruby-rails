# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshSession, type: :model do
  describe "validations" do
    subject(:refresh_session) { build(:refresh_session) }

    it "rejects a blank token_hash" do
      refresh_session.token_hash = " "

      expect(refresh_session).not_to be_valid
      expect(refresh_session.errors[:token_hash]).to be_present
    end

    # `User#email`과 같은 계약이다(spec/models/user_spec.rb의 짝 예제 참고):
    # 모델 검증은 유니크를 보지 않고, DB 유니크 인덱스
    # (`index_refresh_sessions_on_token_hash`)만이 강제 수단이다.
    it "does not validate uniqueness at the model layer -- the database unique index is the only enforcement" do
      create(:refresh_session, token_hash: "duplicate-hash")
      refresh_session.token_hash = "duplicate-hash"

      expect(refresh_session).to be_valid

      expect { refresh_session.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    # 검증기를 되살리는 뮤테이션을 잡는 가드. 위 예제만으로는 부족하다 —
    # `uniqueness: true`를 되돌려 놓으면 위 예제는 실패하지만 "왜 안 되는가"가
    # 남지 않는다. 지운 진짜 이유는 **로그인마다·회전마다 왕복이 하나 더 나간다**는
    # 것이므로 그 사실을 직접 고정한다.
    it "issues no pre-insert SELECT against refresh_sessions when a session is created" do
      user = create(:user)
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        next if payload[:name].in?([ "SCHEMA", "TRANSACTION" ])

        statements << payload[:sql]
      end

      begin
        described_class.create!(
          id: SecureRandom.uuid,
          user: user,
          token_hash: SecureRandom.hex(32),
          expires_at: 30.days.from_now
        )
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      preflight = statements.select { |sql| sql.start_with?("SELECT") && sql.include?("refresh_sessions") }
      expect(preflight).to eq([])
    end

    it "rejects a blank expires_at" do
      refresh_session.expires_at = nil

      expect(refresh_session).not_to be_valid
      expect(refresh_session.errors[:expires_at]).to be_present
    end

    it "requires a user" do
      refresh_session.user = nil

      expect(refresh_session).not_to be_valid
      expect(refresh_session.errors[:user]).to be_present
    end

    it "allows a nil replaced_by" do
      refresh_session.replaced_by = nil

      expect(refresh_session).to be_valid
    end
  end

  describe "associations" do
    it "allows referencing the session that replaced it" do
      original = create(:refresh_session)
      replacement = create(:refresh_session, user: original.user)
      original.update!(replaced_by: replacement)

      expect(original.reload.replaced_by).to eq(replacement)
    end
  end

  describe "factory" do
    it "creates a valid UUID-backed record with defaults" do
      refresh_session = create(:refresh_session)

      expect(refresh_session).to be_valid
      expect(refresh_session.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
      expect(refresh_session.revoked_at).to be_nil
      expect(refresh_session.replaced_by).to be_nil
    end
  end
end
