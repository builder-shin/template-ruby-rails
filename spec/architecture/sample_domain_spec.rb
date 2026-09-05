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

  it "retains the required authentication, background job, and storage integrations" do
    contents = tracked_source.values.join("\n")

    expect(contents).to include("AuthServiceClient", "Sidekiq", "ActiveStorage")
  end

  it "documents the executable Example API development contract" do
    readme = read_project_file("README.md")

    expect(readme).to include(
      "docker compose up --build",
      "session_web=dev-session",
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
      # Task 5: 쓰기 인증이 session_web 쿠키에서 로컬 JWT Bearer로 바뀌었다 —
      # 위 "session_web=dev-session" 문자열은 여전히 참이지만(auth-stub 자체는
      # Task 6 전까지 아직 존재), 그것이 더 이상 쓰기 인증 방법이라고 읽혀서는
      # 안 된다. 실제 흐름(가입 → 로그인 → Bearer)이 README에 있다는 것을 여기서
      # 같이 고정한다.
      "/api/v1/auth/register",
      "/api/v1/auth/login",
      "/api/v1/auth/refresh",
      "/api/v1/auth/logout",
      "Authorization: Bearer"
    )
    expect(readme).to match(/Auth stub.*development.*production.*AUTH_SERVICE_URL/im)
  end
end
