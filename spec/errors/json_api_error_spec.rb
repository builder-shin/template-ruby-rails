# frozen_string_literal: true

require "rails_helper"

RSpec.describe JsonApiError do
  describe "#source" do
    # 이 태스크가 고치는 자리(Task 4 Step 1): source가 :pointer와 :parameter로만
    # slice되던 시절에는 :header가 조용히 사라졌다 — 정본 가드가 모든 인증 오류에
    # 싣는 source_header="Authorization"이 Rails에서만 빠진 채 나갔다. source.header는
    # JSON:API 1.1이 정의한 멤버다. 여기서 header만 단독으로 고정해 둔다: 다음 사람이
    # "안 쓰는 키"라며 slice에서 :header를 되돌리면 이 테스트가 바로 실패한다.
    it "keeps a header-only source" do
      error = described_class.new(status: 401, code: "INVALID_TOKEN", source: { header: "Authorization" })

      expect(error.source).to eq(header: "Authorization")
    end

    it "keeps pointer, parameter, and header together and drops unknown keys" do
      error = described_class.new(
        status: 401,
        code: "AUTHENTICATION_REQUIRED",
        source: { pointer: "/data", parameter: "filter[name]", header: "Authorization", bogus: "x" }
      )

      expect(error.source).to eq(pointer: "/data", parameter: "filter[name]", header: "Authorization")
    end

    it "accepts a string-keyed source hash" do
      error = described_class.new(status: 401, code: "INVALID_TOKEN", source: { "header" => "Authorization" })

      expect(error.source).to eq(header: "Authorization")
    end

    it "is nil when no source is given" do
      error = described_class.new(status: 500, code: "INTERNAL_SERVER_ERROR")

      expect(error.source).to be_nil
    end

    it "freezes the source hash" do
      error = described_class.new(status: 401, code: "INVALID_TOKEN", source: { header: "Authorization" })

      expect(error.source).to be_frozen
    end
  end

  describe "validation" do
    it "rejects a status outside the HTTP error range" do
      expect { described_class.new(status: 200, code: "AUTHENTICATION_REQUIRED") }
        .to raise_error(ArgumentError, "status must be an HTTP error status")
    end

    it "rejects an unknown error code" do
      expect { described_class.new(status: 400, code: "NOT_A_REAL_CODE") }
        .to raise_error(ArgumentError, "unknown JSON:API error code")
    end

    # Task 4가 여는 세 코드. 이 자리가 없으면 가드가 401/403을 내려는 순간
    # ArgumentError로 500이 된다 — 실제로 지금 이 브랜치 이전에는 그랬다.
    it "accepts the three error codes this task adds" do
      expect { described_class.new(status: 401, code: "INVALID_TOKEN") }.not_to raise_error
      expect { described_class.new(status: 401, code: "TOKEN_EXPIRED") }.not_to raise_error
      expect { described_class.new(status: 403, code: "USER_INACTIVE") }.not_to raise_error
    end
  end
end
