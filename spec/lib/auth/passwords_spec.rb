# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Passwords do
  describe ".hash_password / .verify_password" do
    it "round-trips the correct password" do
      hash = described_class.hash_password("correct horse battery staple")

      expect(described_class.verify_password("correct horse battery staple", hash)).to be(true)
    end

    it "rejects the wrong password without raising" do
      hash = described_class.hash_password("correct horse battery staple")

      expect(described_class.verify_password("wrong password entirely", hash)).to be(false)
    end

    it "produces an argon2id hash, salted differently on every call" do
      first = described_class.hash_password("same-password")
      second = described_class.hash_password("same-password")

      aggregate_failures do
        expect(first).to start_with("$argon2id$")
        expect(second).to start_with("$argon2id$")
        expect(first).not_to eq(second)
      end
    end

    it "does not silently swallow a corrupted stored hash into false" do
      # 컨테이너 실측: 형식이 argon2가 아닌 저장 값은 Argon2::ArgonHashFail을 낸다.
      # 정본(FastAPI PASSWORD_HASH.verify, NestJS verifyPassword) 둘 다 이 경우를
      # 잡아서 false로 바꾸지 않는다 — 저장된 데이터의 손상을 "비밀번호가 틀렸다"로
      # 위장하면 원인을 추적할 길이 없어지기 때문이다. 이 테스트는 그 계약을
      # 지킨다: 누군가 여기에 rescue를 넣어 false로 감추면 이 테스트가 잡아야 한다.
      expect { described_class.verify_password("anything", "not-an-argon2-hash") }
        .to raise_error(Argon2::ArgonHashFail)
    end

    it "raises for an empty or nil stored hash rather than treating it as a valid non-match" do
      aggregate_failures do
        expect { described_class.verify_password("anything", "") }.to raise_error(Argon2::ArgonHashFail)
        expect { described_class.verify_password("anything", nil) }.to raise_error(Argon2::ArgonHashFail)
      end
    end
  end

  describe ".dummy_hash" do
    it "is a valid argon2id hash that no real password verifies against" do
      aggregate_failures do
        expect(described_class.dummy_hash).to start_with("$argon2id$")
        expect(described_class.verify_password("password", described_class.dummy_hash)).to be(false)
        expect(described_class.verify_password("", described_class.dummy_hash)).to be(false)
      end
    end

    it "memoizes the same hash across calls in the same process" do
      expect(described_class.dummy_hash).to eq(described_class.dummy_hash)
    end
  end
end
