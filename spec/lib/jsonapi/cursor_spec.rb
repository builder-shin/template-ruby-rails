# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jsonapi::Cursor do
  describe ".encode / .decode" do
    it "round-trips values under a matching signature" do
      encoded = described_class.encode("createdAt:desc,id:asc", %w[2026-01-01T00:00:00Z abc])

      expect(described_class.decode(encoded, "createdAt:desc,id:asc", "page[after]")).to eq(
        %w[2026-01-01T00:00:00Z abc]
      )
    end

    it "rejects a cursor encoded under a different signature" do
      encoded = described_class.encode("createdAt:desc,id:asc", %w[x y])

      expect { described_class.decode(encoded, "title:asc,id:asc", "page[after]") }
        .to raise_error(JsonApiError) { |error| expect(error.code).to eq("INVALID_PAGE") }
    end

    it "rejects a value list whose length does not match the signature" do
      encoded = described_class.encode("createdAt:desc,id:asc", %w[x])

      expect { described_class.decode(encoded, "createdAt:desc,id:asc", "page[after]") }
        .to raise_error(JsonApiError)
    end

    it "rejects a string that is not base64url" do
      expect { described_class.decode("not base64!!", "id:asc", "page[after]") }.to raise_error(JsonApiError)
    end

    it "rejects a payload that is not JSON" do
      encoded = Base64.urlsafe_encode64("not json", padding: false)

      expect { described_class.decode(encoded, "id:asc", "page[after]") }.to raise_error(JsonApiError)
    end

    it "rejects a cursor longer than the maximum length without decoding it" do
      # 정본의 4096자 상한과 맞춘다 — base64+JSON 디코딩 비용을 들이기 전에 자른다.
      #
      # "without decoding it"을 실제로 잰다: Base64.urlsafe_decode64를 호출되면
      # (일반) 예외를 내도록 스텁해 둔다. 오버사이즈 문자열은 어차피 base64로도
      # JSON으로도 유효하지 않아 길이 가드를 지워도 같은 INVALID_PAGE로 끝나므로,
      # 스텁 없이는 이 테스트가 가드의 존재가 아니라 디코드 실패를 재는 셈이 된다.
      # 가드가 지워지면 이 스텁이 raise_error(JsonApiError) 기대를 깨뜨려 잡아낸다.
      oversized = "a" * (described_class::MAX_CURSOR_LENGTH + 1)
      allow(Base64).to receive(:urlsafe_decode64).and_raise("length guard did not short-circuit")

      expect { described_class.decode(oversized, "id:asc", "page[after]") }
        .to raise_error(JsonApiError) { |error| expect(error.code).to eq("INVALID_PAGE") }
    end

    it "reports the parameter passed in, not a hardcoded one, in the error source" do
      # source.parameter는 응답 문서의 필드다 — page[before]로 디코딩을 시도했으면
      # 오류도 page[before]를 가리켜야 한다.
      expect { described_class.decode("not base64!!", "id:asc", "page[before]") }
        .to raise_error(JsonApiError) { |error| expect(error.source).to eq(parameter: "page[before]") }
    end
  end

  describe ".encodable?" do
    it "accepts every whitelisted type" do
      accepted = [ "text", 42, true, false, nil, Time.zone.now, DateTime.now, Date.today ]

      aggregate_failures do
        accepted.each do |value|
          expect(described_class.encodable?(value)).to be(true), "expected #{value.class} to be encodable"
        end
      end
    end

    it "rejects a type outside the whitelist" do
      # BigDecimal처럼 나중에 정렬 컬럼으로 열릴 수 있는 타입 — 화이트리스트 밖이면
      # 왕복 가능 여부를 판정하는 이 게이트가 실제로 막아야 한다(지금은 어떤 공개
      # 정렬도 이 타입이 아니라서 요청 스펙으로는 닿지 않는다).
      require "bigdecimal"
      expect(described_class.encodable?(BigDecimal("1.5"))).to be(false)
    end
  end

  describe ".serialize" do
    it "formats every admitted type on its own arm" do
      aggregate_failures do
        expect(described_class.serialize(Time.utc(2026, 1, 2, 3, 4, 5, 600_000)))
          .to eq("2026-01-02T03:04:05.600000Z")
        expect(described_class.serialize(DateTime.new(2026, 1, 2, 3, 4, 5)))
          .to eq("2026-01-02T03:04:05.000000Z")
        expect(described_class.serialize(Date.new(2026, 1, 2))).to eq("2026-01-02")
        expect(described_class.serialize(true)).to eq("true")
        expect(described_class.serialize(false)).to eq("false")
        expect(described_class.serialize(42)).to eq("42")
        expect(described_class.serialize("already-a-string")).to eq("already-a-string")
      end
    end
  end

  describe "value serialization" do
    # 정본과 NestJS가 커서 값을 전부 문자열로 담는다 — Rails만 혼합 타입이면 JSON
    # 왕복에서 타입이 살아 돌아오는 것에 기대게 된다. 정수 정렬로 실제 커서를 받아
    # 확인한다: 이 계약은 특정 타입 하나가 아니라 인코딩 전체의 성질이어야 한다.
    it "encodes every cursor value as a string, even for an integer sort" do
      create_list(:example, 3, score: 10)

      request = ActionDispatch::TestRequest.create
      request.set_header("QUERY_STRING", "sort=score&page[size]=1&page[after]=")
      request.set_header("PATH_INFO", "/api/v1/examples")

      result = Jsonapi::QueryParser.new(
        scope: Example.all,
        request: request,
        action_params: -> { ActionController::Parameters.new(request.query_parameters) },
        contract: Api::V1::ExamplesController.new.send(:query_contract),
        model: Example
      ).call

      next_link = result.links.fetch("next")
      expect(next_link).not_to be_nil

      raw_cursor = URI.decode_www_form(URI.parse(next_link).query).to_h.fetch("page[after]")
      payload = JSON.parse(Base64.urlsafe_decode64(raw_cursor))

      expect(payload.fetch("v")).to all(be_a(String))
    end
  end
end

RSpec.describe Jsonapi::QueryParser do
  # 공개 자원 중 nullable 정렬을 여는 것이 하나도 없다 — 정본과 같은 결정이다.
  # 그래서 이 규칙은 실제 계약이 아니라 여기서 만든 계약으로 검증한다. 검증
  # 편의를 위해 공개 계약에 nullable 정렬을 되돌려 놓지 않는다.
  let(:nullable_contract) do
    {
      filters: {},
      sorts: {
        "title" => { attribute: :title, nullable: false },
        "description" => { attribute: :description, nullable: true }
      },
      includes: [],
      default_sort: [ { field: "title", direction: :asc } ],
      tie_breaker: { field: "id", direction: :asc },
      default_page_size: 20
    }
  end

  def parse(query_string, contract)
    request = ActionDispatch::TestRequest.create
    request.set_header("QUERY_STRING", query_string)
    request.set_header("PATH_INFO", "/api/v1/examples")
    described_class.new(
      scope: Example.all,
      request: request,
      # 실제 컨트롤러는 `action_params: -> { params }`를 넘긴다. 빈 Parameters를
      # 넘기면 page[...]/sort 같은 대괄호 패밀리가 실제로 왔는데도
      # `validate_action_controller_parameters!`가 강한 매개변수로 감싸이지
      # 않았다고 보고 nullable 검증에 닿기 전에 INVALID_PAGE로 끊어버린다 —
      # request.query_parameters로 실제 중첩 구조를 재현해야 한다.
      action_params: -> { ActionController::Parameters.new(request.query_parameters) },
      contract: contract,
      model: Example
    ).call
  end

  it "rejects cursor mode on a nullable sort" do
    # keyset은 (컬럼, id) > (값, 값) 비교로 자르는데 NULL이 섞이면 비교가 unknown이
    # 되어 행을 조용히 건너뛴다. 조용히 틀린 페이지보다 거절이 낫다.
    expect { parse("sort=description&page[after]=", nullable_contract) }
      .to raise_error(JsonApiError) { |error| expect(error.code).to eq("INVALID_PAGE") }
  end

  it "accepts the same sort in offset mode" do
    # 거부되는 것은 커서 모드뿐이다. 규칙이 정렬 자체를 막는 것으로 넓어지면
    # 이 테스트가 잡는다.
    expect { parse("sort=description&page[number]=1", nullable_contract) }.not_to raise_error
  end

  it "accepts cursor mode on a non-nullable sort" do
    expect { parse("sort=title&page[after]=", nullable_contract) }.not_to raise_error
  end
end
