# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth configuration" do
  # auth_service_config_spec.rb는 INITIALIZER/ENVIRONMENT_KEYS를 이 describe 블록
  # 안에서 상수로 정의한다. 그런데 `RSpec.describe do ... end`는 class_exec로
  # 실행돼도 상수 대입만큼은 self가 아니라 블록이 "쓰인" 렉시컬 스코프(이 파일의
  # 최상단)를 따른다 — 즉 두 파일 다 같은 top-level Object::INITIALIZER,
  # Object::ENVIRONMENT_KEYS에 겹쳐 쓴다. 실제로 겪은 문제: 두 spec 파일이 같은
  # 프로세스에서 함께 로드되면(전체 스위트 실행 시 항상 그렇다) 나중에 로드되는
  # 파일의 값으로 덮어써져서, 이 파일의 around 훅이 3개짜리(AUTH_SERVICE_URL류)
  # 키 목록으로 ENV를 정리하며 내 7개 JWT_* 키는 전혀 건드리지 못했다 — 그 결과
  # 한 예제가 설정한 ENV 값이 다음 예제로 새어 들어갔다. def로 정의하는 인스턴스
  # 메서드는 class_exec의 self를 따라 이 describe 블록에만 스코프되므로 같은
  # 문제가 없다.
  def initializer_path
    Rails.root.join("config/initializers/auth.rb")
  end

  def environment_keys
    %w[
      JWT_SECRET_KEY JWT_ISSUER JWT_AUDIENCE JWT_ACCESS_EXPIRES_SECONDS
      JWT_REFRESH_EXPIRES_SECONDS JWT_LEEWAY_SECONDS REFRESH_SESSION_RETENTION_SECONDS
    ]
  end

  def valid_secret
    "a" * 32
  end

  around do |example|
    original_environment = environment_keys.to_h { |key| [ key, ENV[key] ] }
    original_config = Rails.application.config.x.auth

    example.run
  ensure
    original_environment.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    Rails.application.config.x.auth = original_config
  end

  # auth_service_config_spec.rb의 load_auth_initializer와 같은 모양이다. 다만 이
  # 설정은 Rails.env에 따라 분기하지 않으므로(JWT_SECRET_KEY는 모든 환경에서 필수)
  # environment 인자가 없다 — 매 예제가 알려진 키를 전부 지운 뒤 필요한 것만 넣는다.
  def load_auth_initializer(overrides = {})
    environment_keys.each { |key| ENV.delete(key) }
    overrides.each { |key, value| ENV[key] = value }

    load initializer_path
    Rails.application.config.x.auth
  end

  it "JWT_SECRET_KEY가 없으면 변수 이름을 담은 오류로 부팅에 실패한다" do
    expect { load_auth_initializer }.to raise_error(/JWT_SECRET_KEY/)
  end

  it "JWT_SECRET_KEY가 blank이면 없는 것과 같이 취급해 실패한다" do
    [ "", "   " ].each do |blank|
      expect { load_auth_initializer("JWT_SECRET_KEY" => blank) }.to raise_error(/JWT_SECRET_KEY/)
    end
  end

  it "JWT_SECRET_KEY가 32바이트 미만이면 부팅에 실패한다" do
    expect { load_auth_initializer("JWT_SECRET_KEY" => "a" * 31) }.to raise_error(/JWT_SECRET_KEY/)
  end

  it "JWT_SECRET_KEY가 정확히 32바이트면 통과한다" do
    config = load_auth_initializer("JWT_SECRET_KEY" => valid_secret)
    expect(config.secret_key).to eq(valid_secret)
  end

  it "멀티바이트 문자는 문자 수가 아니라 바이트 수로 32바이트 이상을 요구한다" do
    # UTF-8에서 한글 한 글자는 3바이트다. 11글자는 length(문자 수)로 재면 11이라
    # 미달로 착각하기 쉽지만 실제로는 33바이트라 통과해야 한다 — bytesize로 재고
    # 있는지를 이 테스트가 직접 확인한다.
    eleven_hangul_chars = "가" * 11
    expect(eleven_hangul_chars.length).to eq(11)
    expect(eleven_hangul_chars.bytesize).to eq(33)

    config = load_auth_initializer("JWT_SECRET_KEY" => eleven_hangul_chars)
    expect(config.secret_key).to eq(eleven_hangul_chars)
  end

  it "나머지 값은 기본값을 갖는다" do
    config = load_auth_initializer("JWT_SECRET_KEY" => valid_secret)

    expect(config.issuer).to eq("template-ruby-rails")
    expect(config.audience).to eq("template-ruby-rails")
    expect(config.access_expires_seconds).to eq(900)
    expect(config.refresh_expires_seconds).to eq(2_592_000)
    expect(config.leeway_seconds).to eq(0)
    expect(config.refresh_session_retention_seconds).to eq(604_800)
  end

  it "환경변수로 기본값을 전부 덮어쓸 수 있다" do
    config = load_auth_initializer(
      "JWT_SECRET_KEY" => valid_secret,
      "JWT_ISSUER" => "custom-issuer",
      "JWT_AUDIENCE" => "custom-audience",
      "JWT_ACCESS_EXPIRES_SECONDS" => "60",
      "JWT_REFRESH_EXPIRES_SECONDS" => "120",
      "JWT_LEEWAY_SECONDS" => "5",
      "REFRESH_SESSION_RETENTION_SECONDS" => "10"
    )

    expect(config.issuer).to eq("custom-issuer")
    expect(config.audience).to eq("custom-audience")
    expect(config.access_expires_seconds).to eq(60)
    expect(config.refresh_expires_seconds).to eq(120)
    expect(config.leeway_seconds).to eq(5)
    expect(config.refresh_session_retention_seconds).to eq(10)
  end

  it "만료 초가 0 이하이면 변수 이름을 담은 오류로 실패한다" do
    expect { load_auth_initializer("JWT_SECRET_KEY" => valid_secret, "JWT_ACCESS_EXPIRES_SECONDS" => "0") }
      .to raise_error(/JWT_ACCESS_EXPIRES_SECONDS/)
    expect { load_auth_initializer("JWT_SECRET_KEY" => valid_secret, "JWT_REFRESH_EXPIRES_SECONDS" => "-1") }
      .to raise_error(/JWT_REFRESH_EXPIRES_SECONDS/)
  end

  it "leeway와 retention은 음수면 실패한다" do
    expect { load_auth_initializer("JWT_SECRET_KEY" => valid_secret, "JWT_LEEWAY_SECONDS" => "-1") }
      .to raise_error(/JWT_LEEWAY_SECONDS/)
    expect { load_auth_initializer("JWT_SECRET_KEY" => valid_secret, "REFRESH_SESSION_RETENTION_SECONDS" => "-1") }
      .to raise_error(/REFRESH_SESSION_RETENTION_SECONDS/)
  end

  it "leeway와 retention은 0이면 통과한다" do
    config = load_auth_initializer(
      "JWT_SECRET_KEY" => valid_secret, "JWT_LEEWAY_SECONDS" => "0", "REFRESH_SESSION_RETENTION_SECONDS" => "0"
    )

    expect(config.leeway_seconds).to eq(0)
    expect(config.refresh_session_retention_seconds).to eq(0)
  end

  it "정수가 아닌 값은 변수 이름을 담은 오류로 실패한다 (조용히 0으로 바뀌지 않는다)" do
    expect { load_auth_initializer("JWT_SECRET_KEY" => valid_secret, "JWT_ACCESS_EXPIRES_SECONDS" => "abc") }
      .to raise_error(/JWT_ACCESS_EXPIRES_SECONDS/)
  end

  it "숫자로 시작하되 뒤에 쓰레기가 붙은 값도 조용히 앞자리만 취하지 않고 거부한다" do
    # mutation-test에서 실제로 잡은 구멍: "abc"만으로는 부족하다 — "abc".to_i가
    # 0이 되고, 그 0이 우연히 "0 이하이면 실패"에도 걸려서 같은 변수 이름을 담은
    # 오류가 나므로, read_int가 정말 Integer()로 엄격하게 파싱하는지, 아니면
    # .to_i로 조용히 0으로 바꾼 뒤 다른 검사가 우연히 잡아준 것인지 구별하지
    # 못했다. "900abc"는 .to_i가 900(양수)으로 읽어버려서 "0 이하" 검사를
    # 통과해 버린다 — 여기서 걸려야 read_int 자체가 엄격하다는 뜻이다.
    expect { load_auth_initializer("JWT_SECRET_KEY" => valid_secret, "JWT_ACCESS_EXPIRES_SECONDS" => "900abc") }
      .to raise_error(/JWT_ACCESS_EXPIRES_SECONDS/)
  end

  it "JWT_ISSUER/JWT_AUDIENCE가 설정됐는데 blank이면 기본값으로 조용히 넘어가지 않고 실패한다" do
    expect { load_auth_initializer("JWT_SECRET_KEY" => valid_secret, "JWT_ISSUER" => "  ") }
      .to raise_error(/JWT_ISSUER/)
    expect { load_auth_initializer("JWT_SECRET_KEY" => valid_secret, "JWT_AUDIENCE" => "") }
      .to raise_error(/JWT_AUDIENCE/)
  end
end
