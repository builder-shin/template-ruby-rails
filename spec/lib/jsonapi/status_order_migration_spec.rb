# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20260911120000_align_example_status_order")

RSpec.describe AlignExampleStatusOrder do
  it "preserves every existing status through downgrade and upgrade" do
    ids = %w[draft active archived].map { |status| create(:example, status: status).id }
    connection = ActiveRecord::Base.connection
    original = connection.select_rows("SELECT id, status::text FROM examples ORDER BY id")
    migration = described_class.new
    migration.down
    expect(connection.select_rows("SELECT id, status::text FROM examples ORDER BY id")).to eq(original)
    expect(connection.columns("examples").find { |column| column.name == "status" }.sql_type).to eq("character varying")
    expect(connection.columns("examples").find { |column| column.name == "status" }.default).to be_nil
    migration.up
    expect(connection.select_rows("SELECT id, status::text FROM examples ORDER BY id")).to eq(original)
    expect(connection.columns("examples").find { |column| column.name == "status" }.default).to be_nil
    expect(connection.select_values("SELECT status FROM examples WHERE id IN (#{ids.map { |id| connection.quote(id) }.join(',')}) ORDER BY status")).to eq(%w[draft active archived])
  end
end
