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

    # F1 (팀장 fix round 1): 위 두 테스트는 dummy_hash의 "모양"만 본다 — $argon2id$
    # 접두어, 항상 false, 메모이제이션. §6.5가 dummy_hash를 두는 이유(계정 존재
    # 여부가 응답 시간으로 새지 않게 하는 것)는 정작 건드리지 않는다. 팀장이
    # 실측: app/lib/auth/passwords.rb의 hash_password 호출을
    # `Argon2::Password.new(t_cost: 1, m_cost: 3, p_cost: 1).create(...)`로 바꿔도
    # (진짜 해시 33.4ms 대비 dummy 0.02ms — 1711배 빠르다, 계정 열거 오라클이
    # 그대로 부활한다) 위 두 테스트는 "7 examples, 0 failures"로 그대로 통과했다.
    # dummy_hash가 hash_password와 같은 비용 파라미터를 쓰는지 직접 확인한다.
    it "hashes with the same argon2 cost parameters as a real password hash" do
      # 해시 문자열 모양: $argon2id$v=19$m=65536,t=3,p=4$salt$digest.
      # split("$")[1..3]이 알고리즘 변종·버전·비용 파라미터다(salt/digest는 뺀다 —
      # 그건 당연히 매번 다르다). 비용 파라미터가 같아야 진짜 검증과 같은 시간이
      # 걸린다.
      dummy_cost = described_class.dummy_hash.split("$")[1..3]
      real_cost = described_class.hash_password("x").split("$")[1..3]

      expect(dummy_cost).to eq(real_cost)
    end

    it "hashes a freshly generated random value rather than a hardcoded constant" do
      # 모양과 비용 파라미터가 같아도 고정 문자열을 박아 넣으면(예: 소스에 통째로
      # 적어 둔 argon2 해시) 재부팅해도 항상 같은 salt/digest가 나온다 — 진짜
      # SecureRandom.hex(32)를 매번 새로 해시하는 것과 구별이 안 되던 것을
      # 메모이제이션을 강제로 초기화해서 구별한다.
      first = described_class.dummy_hash
      described_class.instance_variable_set(:@dummy_hash, nil)
      second = described_class.dummy_hash

      expect(first).not_to eq(second)
    end
  end
end
