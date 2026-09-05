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

    it "rejects a duplicate email" do
      create(:user, email: "duplicate@example.com")
      user.email = "duplicate@example.com"

      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
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
