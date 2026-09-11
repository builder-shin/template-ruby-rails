# frozen_string_literal: true

require "rails_helper"

# JSON:API 1.1 §5.1은 **응답**의 미디어 타입에 파라미터를 붙이는 것을 금지한다.
# 이 API는 그 규칙을 요청 쪽에서 스스로 강제한다 —
# `JsonapiNegotiation#validate_jsonapi_content_type!`이 `charset` 같은 미등록
# 파라미터가 붙은 Content-Type을 415로 거절한다. 그래서 응답이 파라미터를 달면
# **자기 API가 받지 않는 값을 광고하게 된다.**
#
# 이 스펙이 있기 전에는 그 갈림을 아무것도 지키지 않았다. `render jsonapi:`로 내는
# 읽기 응답 네 자리(`examples#show`·`categories#show`·`tags#show`·`users#me`)가
# `; charset=utf-8`을 달았는데, 셋은 Content-Type 단언 자체가 없었고 하나
# (`users_me_spec.rb`)는 `start_with`로 단언해 **두 세계를 모두 통과시켰다.**
# 그래서 여기서는 `eq`로만 단언한다.
RSpec.describe "JSON:API 응답 미디어 타입", type: :request do
  let(:media_type) { JsonapiRequestHelper::JSONAPI_MEDIA_TYPE }

  it "모든 라우트가 파라미터 없는 미디어 타입을 내고 읽기와 쓰기가 바이트 단위로 같다" do
    mock_bearer_user
    headers = jsonapi_headers.merge(auth_bearer_headers)
    probes = api_route_probes

    # 라우트 목록을 손으로 적어 두면 드리프트한다 — 표가 라우터와 정확히 일치하는지
    # 먼저 단언한다. 라우트를 추가하고 spec/support/api_route_catalog.rb에 넣지
    # 않으면 여기서 먼저 실패한다.
    expect(probes.map(&:key)).to contain_exactly(*router_api_routes)

    rows = probes.map do |probe|
      public_send(probe.verb.downcase, probe.path, params: probe.body&.to_json, headers: headers)

      {
        route: probe.to_s,
        verb: probe.verb,
        status: response.status,
        content_type: response.headers["Content-Type"]
      }
    end

    # 프로브가 실제로 그 액션에 도달했는가. 이 단언이 없으면 잘못 조립한 요청이
    # 404/415로 튕겨도 "Content-Type이 옳다"가 통과해 이 스펙 자체가 속 빈 가드가 된다.
    expect(rows.reject { |row| (200..299).cover?(row[:status]) }).to eq([])

    with_body, without_body = rows.partition { |row| row[:status] != 204 }
    reads = with_body.select { |row| row[:verb] == "GET" }.pluck(:content_type).uniq
    writes = with_body.reject { |row| row[:verb] == "GET" }.pluck(:content_type).uniq

    aggregate_failures do
      # `eq`다 — `start_with`는 `"application/vnd.api+json; charset=utf-8"`도 통과시켜
      # 이 스펙이 구별해야 할 두 세계를 하나로 만든다.
      expect(reads).to eq([ media_type ])
      expect(writes).to eq([ media_type ])
      # 읽기·쓰기가 **바이트 단위로 같다**. 위 두 단언이 각각 비어 있지 않음을
      # 이미 못 박았으므로(빈 배열은 `[media_type]`과 다르다) 이 단언이 공회전하지 않는다.
      expect(reads).to eq(writes)
      # 본문 없는 응답(204)은 Content-Type 자체를 내지 않는다.
      expect(without_body.pluck(:content_type).uniq).to eq([ nil ])
    end
  end

  # 결함의 실제 실패 모드를 그대로 재현한다: 읽기 응답이 낸 Content-Type을 그대로
  # 되돌려 보내는 클라이언트(SDK 생성기가 흔히 만든다)의 쓰기 요청이 415로 막혔다.
  it "읽기 응답이 낸 Content-Type을 그대로 쓰기 요청에 실어도 415가 나지 않는다" do
    mock_bearer_user
    auth_headers = jsonapi_headers.merge(auth_bearer_headers)

    get "/api/v1/users/me", headers: auth_headers
    echoed = response.headers.fetch("Content-Type")

    post "/api/v1/examples",
         params: {
           data: {
             type: "examples",
             attributes: { title: "Echoed media type", status: "draft", score: 0 }
           }
         }.to_json,
         headers: auth_headers.merge("CONTENT_TYPE" => echoed)

    expect(response).to have_http_status(:created), "읽기 응답의 #{echoed.inspect}를 쓰기가 거절했다"
  end
end
