# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject(:user) { build(:user) }

    it "rejects a blank email" do
      user.email = " "

      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    # Task 5: 모델은 더 이상 uniqueness를 사전 조회로 검증하지 않는다(app/models/user.rb의
    # 주석 참고) — 그래서 `valid?`는 중복 이메일이어도 true를 반환한다. 유니크는
    # DB 유니크 인덱스(index_users_on_email)가 강제하고, AuthController#register가
    # 그 위반(ActiveRecord::RecordNotUnique)을 409 EMAIL_ALREADY_REGISTERED로
    # 옮긴다(spec/requests/api/v1/auth_spec.rb). 여기서는 그 DB 계약만 고정한다:
    # 모델 검증을 우회해도(validate: false) 유니크 인덱스 자체는 살아 있다.
    it "does not validate uniqueness at the model layer -- the database unique index is the only enforcement" do
      create(:user, email: "duplicate@example.com")
      user.email = "duplicate@example.com"

      expect(user).to be_valid

      expect { user.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a blank password_hash" do
      user.password_hash = " "

      expect(user).not_to be_valid
      expect(user.errors[:password_hash]).to be_present
    end
  end

  describe "associations" do
    it "destroys dependent refresh sessions when the user is destroyed" do
      user = create(:user)
      create(:refresh_session, user: user)

      expect { user.destroy }.to change(RefreshSession, :count).by(-1)
    end
  end

  describe "factory" do
    it "creates a valid UUID-backed record with defaults" do
      user = create(:user)

      expect(user).to be_valid
      expect(user.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
      expect(user.is_active).to be(true)
      expect(user.refresh_sessions).to be_empty
    end
  end
end
