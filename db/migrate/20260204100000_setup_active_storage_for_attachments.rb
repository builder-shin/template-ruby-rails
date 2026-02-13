# frozen_string_literal: true

class SetupActiveStorageForAttachments < ActiveRecord::Migration[8.1]
  def change
    # Make url nullable to support Active Storage attachments
    # New attachments will use Active Storage, legacy ones keep url field
    change_column_null :profile_attachments, :url, true
  end
end
