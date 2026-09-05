# frozen_string_literal: true

class RefreshSession < ApplicationRecord
  belongs_to :user
  belongs_to :replaced_by, class_name: "RefreshSession", optional: true

  validates :token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true
end
