# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20260911110000_normalize_email_identities")

RSpec.describe NormalizeEmailIdentities do
  around do |example|
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      @connection = connection
      connection.transaction(requires_new: true) do
        connection.execute('CREATE SCHEMA email_identity_probe')
        connection.execute('SET LOCAL search_path TO email_identity_probe')
        connection.execute('CREATE TABLE users (id uuid PRIMARY KEY,email varchar(254) UNIQUE NOT NULL)')
        example.run
        raise ActiveRecord::Rollback
      end
    end
  end
  def insert(email)
    id = SecureRandom.uuid
    @connection.execute("INSERT INTO users VALUES (#{@connection.quote(id)},#{@connection.quote(email)})")
    id
  end
  def email_of(id)
    @connection.select_value("SELECT email FROM users WHERE id=#{@connection.quote(id)}")
  end
  def migrate(direction)
    described_class.new.suppress_messages { described_class.new.exec_migration(@connection, direction) }
  end
  it "normalizes and faithfully restores a legacy Unicode/IDNA identity" do
    original = "Cafe\u0301@XN--BCHER-KVA.EXAMPLE.COM"
    id = insert(original)
    migrate(:up)
    expect(email_of(id)).to eq("café@bücher.example.com")
    migrate(:down)
    expect(email_of(id)).to eq(original)
  end
  [ [ "A@example.com", "a@example.com" ], [ "a@xn--bcher-kva.example.com", "a@bücher.example.com" ],
    [ "Straße@example.com", "strasse@example.com" ], [ "cafe\u0301@example.com", "café@example.com" ] ].each do |first, second|
    it "aborts identity collision #{first} before modifying rows" do
      id = insert(first)
      insert(second)
      expect { migrate(:up) }.to raise_error(/collision/)
      expect(email_of(id)).to eq(first)
    end
  end
  it "aborts a legacy email that could no longer log in" do
    id = insert("legacy@example.test")
    expect { migrate(:up) }.to raise_error(/correction/)
    expect(email_of(id)).to eq("legacy@example.test")
  end
  it "preserves edits/deletions and checks rollback collisions" do
    edited = insert("Edited@example.com")
    deleted = insert("Deleted@example.com")
    original = insert("Original@example.com")
    migrate(:up)
    @connection.execute("UPDATE users SET email='new@example.com' WHERE id=#{@connection.quote(edited)}")
    @connection.execute("DELETE FROM users WHERE id=#{@connection.quote(deleted)}")
    collision = insert("Original@example.com")
    expect { migrate(:down) }.to raise_error(/collision/)
    expect(email_of(original)).to eq("original@example.com")
    @connection.execute("DELETE FROM users WHERE id=#{@connection.quote(collision)}")
    migrate(:down)
    expect(email_of(original)).to eq("Original@example.com")
    expect(email_of(edited)).to eq("new@example.com")
    expect(email_of(deleted)).to be_nil
  end
end
