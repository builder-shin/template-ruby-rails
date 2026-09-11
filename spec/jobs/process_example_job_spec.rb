# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessExampleJob, type: :job do
  %i[canonical compact braced urn uppercase].each do |form|
    it "processes the persisted #{form} UUID and logs success without mutation" do
      example = create(:example)
      before = example.attributes
      id = { canonical: example.id, compact: example.id.delete("-"), braced: "{#{example.id}}", urn: "urn:uuid:#{example.id}", uppercase: example.id.upcase }.fetch(form)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      described_class.perform_now(id)
      expect(Rails.logger).to have_received(:info).with("Processed Example job (example_id=#{example.id})")
      expect(Rails.logger).not_to have_received(:warn)
      expect(example.reload.attributes).to eq(before)
    end
  end

  [ nil, 42, true, [], {} ].each do |value|
    it "rejects nonstring identifier #{value.inspect} without querying" do
      allow(Rails.logger).to receive(:warn)
      expect(Example).not_to receive(:find_by)
      described_class.perform_now(value)
      expect(Rails.logger).to have_received(:warn).with(/malformed identifier/)
    end
  end
  it "processes an existing Example repeatedly without mutating it" do
    example = create(:example, title: "Worker example", status: "active", score: 80)
    before = example.attributes
    allow(Rails.logger).to receive(:info)

    described_class.perform_now(example.id)
    described_class.perform_now(example.id)

    expect(example.reload.attributes).to eq(before)
    expect(Rails.logger).to have_received(:info)
      .with("Processed Example job (example_id=#{example.id})")
      .twice
  end

  it "warns and returns for malformed and missing identifiers" do
    missing_id = SecureRandom.uuid
    allow(Rails.logger).to receive(:warn)

    expect(described_class.perform_now("not-a-uuid")).to be_nil
    expect(described_class.perform_now(missing_id)).to be_nil
    expect(Rails.logger).to have_received(:warn)
      .with("Skipping Example job with malformed identifier (example_id=not-a-uuid)")
    expect(Rails.logger).to have_received(:warn)
      .with("Skipping Example job because the resource does not exist (example_id=#{missing_id})")
  end

  it "uses the shared initial-attempt plus three-retry policy" do
    expect(described_class.get_sidekiq_options["retry"]).to eq(3)
    expect(described_class.queue_name).to eq("default")
  end
end
