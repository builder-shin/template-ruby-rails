# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthServiceClient do
  let(:client) { described_class.new }
  let(:bearer_token) { "test_token_12345" }

  describe "#verify_session" do
    context "인증 성공 시" do
      let(:success_response) do
        {
          "success" => true,
          "data" => {
            "id" => "user-123",
            "email" => "user@example.com",
            "name" => "Test User",
            "workspace_id" => "ws-456",
            "workspace_kind" => "enterprise",
            "workspace_role" => "admin",
            "member_status" => "active"
          }
        }
      end

      before do
        stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me")
          .with(headers: { "Authorization" => "Bearer #{bearer_token}" })
          .to_return(
            status: 200,
            body: success_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "AuthUser 객체를 반환한다" do
        result = client.verify_session(bearer_token)

        expect(result).to be_a(AuthUser)
        expect(result.id).to eq("user-123")
        expect(result.email).to eq("user@example.com")
        expect(result.name).to eq("Test User")
        expect(result.workspace_id).to eq("ws-456")
        expect(result.workspace_kind).to eq("enterprise")
        expect(result.workspace_role).to eq("admin")
        expect(result.member_status).to eq("active")
      end

      it "enterprise? 메서드가 true를 반환한다" do
        result = client.verify_session(bearer_token)
        expect(result.enterprise?).to be true
        expect(result.personal?).to be false
      end

      it "응답을 캐싱한다" do
        # 메모리 캐시 스토어로 임시 전환하여 캐싱 테스트
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

        client.verify_session(bearer_token)
        client.verify_session(bearer_token)

        expect(WebMock).to have_requested(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me").once
      end
    end

    context "인증 실패 시 (401)" do
      before do
        stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me")
          .with(headers: { "Authorization" => "Bearer #{bearer_token}" })
          .to_return(status: 401, body: { error: "Unauthorized" }.to_json)
      end

      it "AuthenticationError를 발생시킨다" do
        expect { client.verify_session(bearer_token) }
          .to raise_error(AuthServiceClient::AuthenticationError, "인증에 실패했습니다.")
      end
    end

    context "서비스 오류 시 (500)" do
      before do
        stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me")
          .with(headers: { "Authorization" => "Bearer #{bearer_token}" })
          .to_return(status: 500, body: { error: "Internal Server Error" }.to_json)
      end

      it "ServiceUnavailableError를 발생시킨다" do
        expect { client.verify_session(bearer_token) }
          .to raise_error(AuthServiceClient::ServiceUnavailableError, "인증 서비스에 연결할 수 없습니다.")
      end
    end

    context "타임아웃 시" do
      before do
        stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me")
          .with(headers: { "Authorization" => "Bearer #{bearer_token}" })
          .to_timeout
      end

      it "ServiceUnavailableError를 발생시킨다" do
        expect { client.verify_session(bearer_token) }
          .to raise_error(AuthServiceClient::ServiceUnavailableError, "인증 서비스에 연결할 수 없습니다.")
      end
    end

    context "연결 실패 시" do
      before do
        stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me")
          .with(headers: { "Authorization" => "Bearer #{bearer_token}" })
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "ServiceUnavailableError를 발생시킨다" do
        expect { client.verify_session(bearer_token) }
          .to raise_error(AuthServiceClient::ServiceUnavailableError, "인증 서비스에 연결할 수 없습니다.")
      end
    end

    context "응답에 success가 false인 경우" do
      before do
        stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me")
          .with(headers: { "Authorization" => "Bearer #{bearer_token}" })
          .to_return(
            status: 200,
            body: { "success" => false, "error" => "Invalid session" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "nil을 반환한다" do
        result = client.verify_session(bearer_token)
        expect(result).to be_nil
      end
    end
  end
end
