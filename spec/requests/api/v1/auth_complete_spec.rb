# frozen_string_literal: true

require "rails_helper"
RSpec.describe "Complete auth documents and headers", type: :request do
  let(:email) { "auth-complete-#{SecureRandom.hex(8)}@example.com" }
  let(:password) { "canonical-password-123" }
  def document(type = "users")
    { "data" => { "type" => type, "attributes" => { "email" => email, "password" => password } } }
  end
  it "rejects non-object auth documents without invented member pointers" do
    [ nil, true, 1, [], "text" ].each do |body|
      post "/api/v1/auth/register", params: body.to_json, headers: jsonapi_headers
      expect(response.status).to eq(422), "#{body.inspect}: #{response.body}"
      errors = parsed_body.fetch("errors")
      expect(errors.length).to eq(1)
      expect(errors.first).not_to have_key("source")
    end
  end
  it "aggregates unknown members, wrong type and invalid attributes" do
    body = { "extra" => 1, "data" => { "type" => "wrong", "id" => SecureRandom.uuid, "meta" => {}, "relationships" => {},
      "attributes" => { "email" => "bad", "password" => "short", "a/b~c" => 1 } } }
    post "/api/v1/auth/register", params: body.to_json, headers: jsonapi_headers
    expect(response.status).to eq(422)
    expect(parsed_body.fetch("errors").map { |error| error.fetch("source").fetch("pointer") }).to match_array([
      "/extra", "/data/type", "/data/id", "/data/meta", "/data/relationships", "/data/attributes/email", "/data/attributes/password", "/data/attributes/a~1b~0c"
    ])
  end
  it "accepts Bearer separator whitespace and supported subject UUID forms for real users" do
    post "/api/v1/auth/register", params: document.to_json, headers: jsonapi_headers
    expect(response.status).to eq(201)
    post "/api/v1/auth/login", params: document("authCredentials").to_json, headers: jsonapi_headers
    expect(response.status).to eq(200)
    token = parsed_body.fetch("data").fetch("attributes").fetch("accessToken")
    [ "Bearer  ", "Bearer \t", "bEaReR " ].each do |prefix|
      get "/api/v1/users/me", headers: jsonapi_headers.merge("Authorization" => prefix + token)
      expect(response.status).to eq(200)
    end
    payload = JWT.decode(token, nil, false).first
    [ payload['sub'].delete('-'), "{#{payload['sub']}}", "urn:uuid:#{payload['sub']}" ].each do |subject|
      signed = JWT.encode(payload.merge('sub' => subject), Auth::Tokens.config.secret_key, 'HS256')
      get "/api/v1/users/me", headers: jsonapi_headers.merge("Authorization" => "Bearer #{signed}")
      expect(response.status).to eq(200)
    end
  end
end
