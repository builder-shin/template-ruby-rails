# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Tokens do
  let(:identifier) { "12345678-1234-5678-9012-123456789012" }
  def signed(changes)
    config = described_class.config
    payload = { "sub" => identifier, "jti" => identifier, "iat" => Time.now.to_i, "exp" => Time.now.to_i + 3600,
      "type" => "refresh", "iss" => config.issuer, "aud" => config.audience }.merge(changes)
    unsigned = [ { "alg" => "HS256", "typ" => "JWT" }, payload ].map { |part| Base64.urlsafe_encode64(JSON.generate(part), padding: false) }.join(".")
    unsigned + "." + Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", config.secret_key, unsigned), padding: false)
  end
  it "accepts and normalizes compact and wrapped UUIDs" do
    [ identifier.delete("-"), "{#{identifier}}", "urn:uuid:#{identifier}" ].each do |jti|
      expect(described_class.decode(signed("jti" => jti), expected_type: "refresh").jti).to eq(identifier)
    end
  end
  it "accepts the fractional last second in year 9999" do
    expect(described_class.decode(signed("exp" => 253402300799.5), expected_type: "refresh").exp.to_f).to eq(253402300799.5)
  end
  [ { "iat" => Time.now.to_i + 3600 }, { "iat" => true }, { "nbf" => true }, { "nbf" => "1" }, { "exp" => 0, "jti" => "bad" } ].each do |changes|
    it "rejects malformed or future claims #{changes}" do
      expect { described_class.decode(signed(changes), expected_type: "refresh") }.to raise_error(Auth::Tokens::InvalidToken)
    end
  end
end
