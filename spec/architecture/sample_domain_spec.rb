# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "Sample domain architecture" do
  def read_project_file(path)
    Rails.root.join(path).read
  end

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

  it "retains the required background job and storage integrations" do
    contents = tracked_source.values.join("\n")

    expect(contents).to include("Sidekiq", "ActiveStorage")
  end

  it "documents the executable Example API development contract" do
    readme = read_project_file("README.md")

    expect(readme).to include(
      "docker compose up --build",
      "Accept: application/vnd.api+json",
      "Content-Type: application/vnd.api+json",
      "curl --globoff",
      "/api/v1/examples",
      "/relationships/category",
      "/relationships/tags",
      "bin/rails db:reset",
      "SimpleCov 80%",
      "bundle exec rspec",
      "bundle exec rubocop",
      "bundle exec brakeman --no-pager -q",
      # 쓰기 인증의 실제 흐름(가입 → 로그인 → Bearer)이 README에 적혀 있다는 것을
      # 여기서 고정한다. C2 이전의 외부 인증 stub과 쿠키 세션 설명은 그 흐름과
      # 함께 사라졌으므로 더 이상 단언하지 않는다.
      "/api/v1/auth/register",
      "/api/v1/auth/login",
      "/api/v1/auth/refresh",
      "/api/v1/auth/logout",
      "Authorization: Bearer"
    )
  end
end
