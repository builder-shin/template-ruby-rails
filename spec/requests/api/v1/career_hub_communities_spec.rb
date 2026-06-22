# frozen_string_literal: true

require "rails_helper"

# CrudActions concern 의 index 동작을 CareerHubCommunities 엔드포인트로 검증한다.
# (index/show 는 public 이라 인증 모킹 없이 호출 가능)
#
# 핵심 검증 대상:
# - 필터를 페이지네이션보다 먼저 적용하여 total-count 가 "필터된 집합" 기준인지
# - enum 문자열 라벨 필터(?filter[status_eq]=active)가 integer 로 변환되는지
# - 이미 숫자인 값(?filter[status_eq]=1)은 그대로 통과하는지
# - 매핑 불가한 enum 라벨은 400 을 반환하는지
RSpec.describe "Api::V1::CareerHubCommunities", type: :request do
  let(:base_path) { "/api/v1/career_hub_communities" }

  def body
    JSON.parse(response.body)
  end

  describe "GET /api/v1/career_hub_communities (index)" do
    context "enum 필터 + 페이지네이션" do
      before do
        3.times { |i| CareerHubCommunity.create!(title: "active-#{i}", status: :active) }
        2.times { |i| CareerHubCommunity.create!(title: "pending-#{i}", status: :pending) }
      end

      it "status 문자열 라벨로 필터링하면 해당 상태만 반환한다 (enum → integer 변환)" do
        get base_path, params: { filter: { status_eq: "active" } }

        expect(response).to have_http_status(:ok)
        expect(body["data"].size).to eq(3)
        statuses = body["data"].map { |d| d["attributes"]["status"] }
        expect(statuses).to all(eq("active"))
      end

      it "total-count 가 필터된 집합 기준이다 (페이지 크기보다 결과가 많은 경우)" do
        get base_path, params: { filter: { status_eq: "active" }, page: { size: 2, number: 1 } }

        expect(response).to have_http_status(:ok)
        # 페이지 크기는 2 지만 전체 active 는 3 개 → 한 페이지에 2 개만
        expect(body["data"].size).to eq(2)
        # total-count 는 전체(5)가 아니라 필터된 active(3) 이어야 한다
        expect(body["meta"]["total-count"]).to eq(3)
      end

      it "필터가 없으면 total-count 는 전체 개수다" do
        get base_path, params: { page: { size: 2 } }

        expect(response).to have_http_status(:ok)
        expect(body["meta"]["total-count"]).to eq(5)
      end

      it "page[size] 가 MAX_PAGE_SIZE 를 넘으면 상한으로 클램프된다" do
        # 상한(100)을 초과하는 레코드를 만들고 과대 page size 를 요청 → 한 페이지에 최대 100건
        (CrudActions::MAX_PAGE_SIZE + 1).times { |i| CareerHubCommunity.create!(title: "bulk-#{i}") }

        get base_path, params: { page: { size: 9999 } }

        expect(response).to have_http_status(:ok)
        expect(body["data"].size).to eq(CrudActions::MAX_PAGE_SIZE)
      end

      it "이미 숫자인 값으로도 enum 필터링이 동작한다 (회귀 방지)" do
        get base_path, params: { filter: { status_eq: "1" } }

        expect(response).to have_http_status(:ok)
        expect(body["data"].size).to eq(3)
        expect(body["data"].map { |d| d["attributes"]["status"] }).to all(eq("active"))
      end
    end

    context "매핑 불가한 enum 라벨" do
      it "400 Bad Request 를 반환한다" do
        get base_path, params: { filter: { status_eq: "nonexistent_label" } }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "두 번째 enum(join_policy) 필터" do
      before do
        CareerHubCommunity.create!(title: "open-1", join_policy: :open)
        CareerHubCommunity.create!(title: "approval-1", join_policy: :approval)
      end

      it "join_policy 라벨로 필터링된다" do
        get base_path, params: { filter: { join_policy_eq: "approval" } }

        expect(response).to have_http_status(:ok)
        expect(body["data"].size).to eq(1)
        expect(body["data"].first["attributes"]["join_policy"]).to eq("approval")
      end
    end
  end
end
