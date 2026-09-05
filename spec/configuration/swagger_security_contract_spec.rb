# frozen_string_literal: true

require "rails_helper"
require "yaml"

# 공개되는 OpenAPI 문서가 **보호된 엔드포인트를 보호로 말하는지**를 지킨다.
#
# `spec/configuration/swagger_contract_spec.rb`는 auth 네 라우트에 `security`가
# **없음**만 단언하고, "생성물이 최신인가"(`YAML.safe_load_file(...) == normalized(openapi)`)를
# 본다. 그 둘만으로는 `spec/swagger_helper.rb`에서 `protected: true`를 떼고 CI가
# 시키는 대로 `rswag:specs:swaggerize`를 다시 돌리면 **양쪽이 함께 움직여 통과한다** —
# 런타임은 그대로 401인데 문서만 "공개"라고 광고하는 상태가 게이트를 전부 지난다.
#
# 그래서 여기서는 **어떤 라우트가 보호 대상인지를 목록으로 다시 적지 않는다.**
# 인증 헤더 없이 각 라우트를 실제로 호출해서 401 AUTHENTICATION_REQUIRED가
# 나오는지로 판정하고(= 런타임 인증 경계), 그 판정과 생성된 `swagger/v1/swagger.yaml`의
# `security` 유무가 **양방향으로** 일치하는지를 단언한다. 목록을 손으로 옮겨 적으면
# 드리프트하므로 라우트 집합 자체도 라우터에서 끌어온다.
#
# 읽는 대상이 메모리의 `openapi` 해시가 아니라 **생성된 파일**인 것도 의도다 —
# 실제로 배포되고 SDK를 만들어 내는 산출물이 그 파일이다.
#
# `spec/requests/` 가 아니라 여기에 두는 이유: `rswag:specs:swaggerize` 는
# `spec/requests/**/*_spec.rb` 만 돌리고(rswag-specs 2.17.0의 rake task),
# 파일은 그 실행이 **끝난 뒤에** 쓴다. 이 스펙이 거기 있으면 재생성 도중에는
# 아직 옛 파일을 읽게 되어, 정당한 swagger 변경이 재생성 게이트를 한 번
# 실패시킨다. `type: :request` 는 메타데이터로 직접 지정한다.
RSpec.describe "OpenAPI security와 런타임 인증 경계", type: :request do
  let(:swagger) { YAML.safe_load_file(Rails.root.join("swagger/v1/swagger.yaml"), aliases: true) }

  def swagger_operation(document, probe)
    document.dig("paths", openapi_path_for(probe.path_spec), probe.verb.downcase)
  end

  it "인증 없이 401을 내는 라우트가 곧 swagger가 security로 문서화한 라우트다" do
    probes = api_route_probes

    # 라우트 목록을 손으로 적어 두면 드리프트한다 — 표가 라우터와 정확히 일치하는지
    # 먼저 단언한다.
    expect(probes.map(&:key)).to contain_exactly(*router_api_routes)

    rows = probes.map do |probe|
      # **Authorization 헤더를 싣지 않는다.** 이 요청이 401이면 그 라우트는 보호 라우트다.
      public_send(probe.verb.downcase, probe.path, params: probe.body&.to_json, headers: jsonapi_headers)

      code = (JSON.parse(response.body).dig("errors", 0, "code") if response.body.present?)
      { probe: probe, status: response.status, code: code }
    end

    protected_rows, public_rows = rows.partition { |row| row[:status] == 401 }

    aggregate_failures("런타임 인증 경계") do
      # 401이 인증 때문인지 확인한다 — 다른 이유의 401을 보호로 잘못 읽지 않는다.
      expect(protected_rows.pluck(:code).uniq).to eq([ "AUTHENTICATION_REQUIRED" ])
      # 공개로 분류된 라우트가 정말 그 액션에 도달했는가. 잘못 조립한 요청이
      # 404/415로 튕기면 "공개"로 잘못 분류되어 아래 대칭 단언이 조용히 빈다.
      expect(public_rows.reject { |row| (200..299).cover?(row[:status]) }).to eq([])
      # 두 세계가 실제로 갈리는지. 한쪽이 비면 아래 단언이 통째로 공회전한다.
      expect(protected_rows).not_to be_empty
      expect(public_rows).not_to be_empty
    end

    protected_rows.each do |row|
      operation = swagger_operation(swagger, row[:probe])

      aggregate_failures("보호 라우트 #{row[:probe]}") do
        expect(operation).to be_present, "#{row[:probe]}가 swagger에 문서화돼 있지 않다"
        expect(operation&.fetch("security", nil)).to eq([ { "BearerAuth" => [] } ])
      end
    end

    public_rows.each do |row|
      operation = swagger_operation(swagger, row[:probe])

      aggregate_failures("공개 라우트 #{row[:probe]}") do
        expect(operation).to be_present, "#{row[:probe]}가 swagger에 문서화돼 있지 않다"
        expect(operation).not_to have_key("security")
      end
    end
  end

  it "security 스킴이 Bearer로 선언돼 있다" do
    # 위 대칭 단언이 참조하는 이름이 실제로 정의된 스킴인지 못 박는다 — 정의되지
    # 않은 이름을 가리키는 `security`는 문서로서 아무 뜻도 없다.
    expect(swagger.dig("components", "securitySchemes", "BearerAuth"))
      .to eq("type" => "http", "scheme" => "bearer")
  end
end
