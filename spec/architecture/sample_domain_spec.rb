# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "Sample domain architecture" do
  def tracked_source_files
    stdout, status = Open3.capture2(
      "git", "ls-files", "-z", "--", "app/**/*.rb", "config/**/*.rb", "Gemfile", "Gemfile.lock", ".env.example",
      chdir: Rails.root.to_s
    )

    raise "git ls-files failed" unless status.success?

    stdout.split("\0").select { |path| Rails.root.join(path).file? }
  end

  def tracked_source
    tracked_source_files.to_h do |path|
      [ path, Rails.root.join(path).read ]
    end
  end

  it "does not retain the legacy blog, email, SendGrid, or Sentry integrations" do
    forbidden_patterns = {
      "Blog" => /blog/i,
      "EmailTemplate" => /email_?template/i,
      "SendGrid" => /sendgrid/i,
      "Sentry" => /sentry/i
    }

    violations = tracked_source.flat_map do |path, contents|
      forbidden_patterns.filter_map do |name, pattern|
        "#{path}: #{name}" if contents.match?(pattern)
      end
    end

    expect(violations).to be_empty, "legacy references found:\n#{violations.join("\n")}"
  end

  it "retains the required authentication, background job, and storage integrations" do
    contents = tracked_source.values.join("\n")

    expect(contents).to include("AuthServiceClient", "Sidekiq", "ActiveStorage")
  end
end
