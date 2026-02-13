class AddMissingFilterIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :job_posts, :status
    add_index :job_posts, :employment_type
    add_index :profiles, :job_seeking_status
    add_index :career_hub_community_events, :status
    add_index :career_hub_community_events, :community_id
  end
end
