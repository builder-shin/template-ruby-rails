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

    it "rejects a duplicate token_hash" do
      create(:refresh_session, token_hash: "duplicate-hash")
      refresh_session.token_hash = "duplicate-hash"

      expect(refresh_session).not_to be_valid
      expect(refresh_session.errors[:token_hash]).to be_present
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
