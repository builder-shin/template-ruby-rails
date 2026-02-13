class CreateRecruitmentRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :recruitment_requests do |t|
      t.string :company_name, null: false
      t.string :contact_name, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.text :message, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :recruitment_requests, :status
    add_index :recruitment_requests, :email
    add_index :recruitment_requests, :created_at
  end
end
