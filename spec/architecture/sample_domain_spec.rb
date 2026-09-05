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

  # 정본이 테스트로 고정한 두 보안 주의를 Rails README에도 고정한다
  # (정본 `tests/docs/test_readme.py::test_readme_documents_token_storage_and_logout_limit`).
  #
  # 둘 다 이 구현의 실제 성질이다. (1) 토큰은 cookie가 아니라 JSON body로만 나가고
  # 인증은 `Authorization` 헤더로만 받는다. (2) `Auth::RefreshSessions.logout`은 refresh
  # session만 폐기하므로 이미 발급된 access token은 `JWT_ACCESS_EXPIRES_SECONDS`(기본 900초)
  # 까지 그대로 유효하다 — 템플릿 사용자가 "로그아웃했으니 끝"이라고 오해하기 좋은 자리다.
  it "documents the token storage and logout limits the canonical template pins" do
    readme = read_project_file("README.md")

    expect(readme).to include(
      "안전하게 보관",
      "cookie에 저장하지 않고",
      "JSON body",
      "logout",
      "JWT_ACCESS_EXPIRES_SECONDS",
      "15분"
    )
  end
end
