# frozen_string_literal: true

class NormalizeEmailIdentities < ActiveRecord::Migration[8.1]
  def up
    connection.transaction do
      execute "LOCK TABLE users IN ACCESS EXCLUSIVE MODE"
      users = select_all("SELECT id,email FROM users ORDER BY id")
      seen = Set.new
      changed = users.filter_map do |user|
        begin
          canonical = Auth::EmailIdentity.normalize(user.fetch("email"))
        rescue ArgumentError
          raise "Email identity migration requires explicit correction of an address rejected by login validation"
        end
        raise "Email normalization collision requires explicit account correction" unless seen.add?(canonical)
        user.merge("canonical" => canonical) if canonical != user.fetch("email")
      end
      execute 'CREATE TABLE email_identity_backups (user_id uuid NOT NULL, original_email varchar(254) NOT NULL, canonical_email varchar(254) NOT NULL, CONSTRAINT "PK_email_identity_backups" PRIMARY KEY (user_id))'
      changed.each do |user|
        execute "INSERT INTO email_identity_backups VALUES (#{quote(user['id'])},#{quote(user['email'])},#{quote(user['canonical'])})"
        execute "UPDATE users SET email=#{quote(user['canonical'])} WHERE id=#{quote(user['id'])}"
      end
    end
  end

  def down
    connection.transaction do
      execute "LOCK TABLE users, email_identity_backups IN ACCESS EXCLUSIVE MODE"
      users = select_all("SELECT u.id,u.email,b.original_email,b.canonical_email FROM users u LEFT JOIN email_identity_backups b ON b.user_id=u.id ORDER BY u.id")
      seen = Set.new
      users.each do |user|
        target = user['email'] == user['canonical_email'] ? user['original_email'] : user['email']
        raise "Email rollback collision requires explicit account correction" unless seen.add?(target)
      end
      users.each do |user|
        next unless user['email'] == user['canonical_email']
        execute "UPDATE users SET email=#{quote(user['original_email'])} WHERE id=#{quote(user['id'])}"
      end
      drop_table :email_identity_backups
    end
  end

  private

  def quote(value)
    connection.quote(value)
  end
end
