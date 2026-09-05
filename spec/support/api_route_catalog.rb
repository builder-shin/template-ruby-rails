# frozen_string_literal: true

# 라우터가 정의한 `/api/v1` 라우트 **전부**에 대해 "성공하는 요청 한 벌"을 적어 둔 표.
#
# 두 계약 스펙이 이 표 하나를 공유한다:
#
#   - spec/requests/api/v1/jsonapi_response_media_type_spec.rb
#       모든 응답이 파라미터 없는 JSON:API 미디어 타입을 내는가(읽기·쓰기 바이트 동일)
#   - spec/requests/api/v1/swagger_security_contract_spec.rb
#       인증 없이 401을 내는 라우트가 곧 swagger가 `security`로 문서화한 라우트인가
#
# **목록을 손으로 다시 적으면 드리프트한다.** 그래서 두 스펙 모두, 자기 단언을 하기
# 전에 `router_api_routes`(= Rails 라우터에서 끌어온 집합)와 이 표의 키 집합이
# 정확히 같은지를 `contain_exactly`로 먼저 단언한다 — 라우트를 추가하고 여기에
# 넣지 않으면 그 단언이 먼저 실패한다. 이 저장소가 마이그레이션·엔티티 인덱스
# 이름에서 쓴 것과 같은 원칙이다.
#
# 픽스처는 라우트마다 새로 만든다. 공유하면 `DELETE /examples/:id`가 지운 행을
# 뒤 라우트가 다시 쓰게 되어 표의 순서가 조용한 전제가 된다 — 이 브랜치가
# 반복해서 만난 "테스트가 명시되지 않은 순서에 의존한다"의 그 자리다.
module ApiRouteCatalog
  # 로그인 최소 길이(AuthController#login의 `min: 12`)를 넘는 값이라야 한다.
  CATALOG_PASSWORD = "correct-horse-battery"

  Probe = Struct.new(:verb, :path_spec, :path, :body, keyword_init: true) do
    def key
      [ verb, path_spec ]
    end

    def to_s
      "#{verb} #{path_spec}"
    end
  end

  # 라우터가 아는 `/api/v1` 라우트 전부를 `[verb, path_spec]`로 돌려준다.
  # `match "/api/*unmatched"` 폴백은 controller가 `application`이라 여기 들어오지 않는다.
  def router_api_routes
    Rails.application.routes.routes.filter_map do |route|
      next unless route.defaults[:controller].to_s.start_with?("api/v1/")

      [ route.verb, route.path.spec.to_s.delete_suffix("(.:format)") ]
    end
  end

  # 라우터 경로(`/api/v1/examples/:id`)를 OpenAPI 경로(`/api/v1/examples/{id}`)로 옮긴다.
  # 기계적 변환이라 두 문서 사이에 손으로 옮겨 적는 자리가 생기지 않는다.
  def openapi_path_for(path_spec)
    path_spec.gsub(/:(\w+)/) { "{#{Regexp.last_match(1)}}" }
  end

  def api_route_probes
    probes = []
    add = lambda do |verb, path_spec, path, body = nil|
      probes << Probe.new(verb: verb, path_spec: path_spec, path: path, body: body)
    end

    # --- auth: 넷 다 무인증 쓰기다(Bearer를 발급하는 자리이지 Bearer로 지키는 자리가 아니다) ---
    add.call(
      "POST", "/api/v1/auth/register", "/api/v1/auth/register",
      { data: { type: "users",
                attributes: { email: "catalog-register@example.com", password: CATALOG_PASSWORD } } }
    )
    add.call(
      "POST", "/api/v1/auth/login", "/api/v1/auth/login",
      { data: { type: "authCredentials",
                attributes: { email: catalog_login_user.email, password: CATALOG_PASSWORD } } }
    )
    add.call(
      "POST", "/api/v1/auth/refresh", "/api/v1/auth/refresh",
      { data: { type: "refreshTokens", attributes: { refreshToken: catalog_refresh_token } } }
    )
    add.call(
      "POST", "/api/v1/auth/logout", "/api/v1/auth/logout",
      { data: { type: "refreshTokens", attributes: { refreshToken: catalog_refresh_token } } }
    )

    # --- examples 컬렉션 ---
    add.call("GET", "/api/v1/examples", "/api/v1/examples")
    add.call(
      "POST", "/api/v1/examples", "/api/v1/examples",
      { data: { type: "examples", attributes: { title: "Catalog create", status: "draft", score: 0 } } }
    )

    # --- examples 단건 (쓰기 라우트마다 자기 행을 쓴다) ---
    add.call("GET", "/api/v1/examples/:id", "/api/v1/examples/#{create(:example).id}")
    patchable = create(:example)
    add.call(
      "PATCH", "/api/v1/examples/:id", "/api/v1/examples/#{patchable.id}",
      { data: { type: "examples", id: patchable.id, attributes: { title: "Catalog patch" } } }
    )
    replaceable = create(:example)
    add.call(
      "PUT", "/api/v1/examples/:id", "/api/v1/examples/#{replaceable.id}",
      { data: { type: "examples", id: replaceable.id,
                attributes: { title: "Catalog replace", status: "active", score: 1 } } }
    )
    add.call("DELETE", "/api/v1/examples/:id", "/api/v1/examples/#{create(:example).id}")

    # --- category 관계 ---
    add.call(
      "GET", "/api/v1/examples/:id/relationships/category",
      "/api/v1/examples/#{create(:example).id}/relationships/category"
    )
    add.call(
      "PATCH", "/api/v1/examples/:id/relationships/category",
      "/api/v1/examples/#{create(:example).id}/relationships/category",
      { data: { type: "exampleCategories", id: create(:example_category).id } }
    )
    add.call("GET", "/api/v1/examples/:id/category", "/api/v1/examples/#{create(:example).id}/category")

    # --- tags 관계 ---
    add.call(
      "GET", "/api/v1/examples/:id/relationships/tags",
      "/api/v1/examples/#{create(:example).id}/relationships/tags"
    )
    add.call(
      "POST", "/api/v1/examples/:id/relationships/tags",
      "/api/v1/examples/#{create(:example).id}/relationships/tags",
      { data: [ { type: "exampleTags", id: create(:example_tag).id } ] }
    )
    add.call(
      "PATCH", "/api/v1/examples/:id/relationships/tags",
      "/api/v1/examples/#{create(:example).id}/relationships/tags",
      { data: [ { type: "exampleTags", id: create(:example_tag).id } ] }
    )
    # DELETE 관계는 실제로 붙어 있는 tag를 떼야 한다 — 붙이지 않고 떼면 204가 나오긴
    # 하지만 "정말 그 라우트를 지났는가"가 흐려진다.
    tagged_example = create(:example)
    detachable_tag = create(:example_tag)
    create(:example_tagging, example: tagged_example, example_tag: detachable_tag)
    add.call(
      "DELETE", "/api/v1/examples/:id/relationships/tags",
      "/api/v1/examples/#{tagged_example.id}/relationships/tags",
      { data: [ { type: "exampleTags", id: detachable_tag.id } ] }
    )
    add.call("GET", "/api/v1/examples/:id/tags", "/api/v1/examples/#{create(:example).id}/tags")

    # --- 본인 프로필 ---
    add.call("GET", "/api/v1/users/me", "/api/v1/users/me")

    # --- 읽기 전용 참조 자원 ---
    add.call("GET", "/api/v1/categories", "/api/v1/categories")
    add.call("GET", "/api/v1/categories/:id", "/api/v1/categories/#{create(:example_category).id}")
    add.call("GET", "/api/v1/tags", "/api/v1/tags")
    add.call("GET", "/api/v1/tags/:id", "/api/v1/tags/#{create(:example_tag).id}")

    probes
  end

  # 로그인 프로브가 쓰는 사용자. argon2 해시는 1회당 ~30ms라 예제당 한 번만 계산한다.
  def catalog_login_user
    @catalog_login_user ||= create(
      :user,
      email: "catalog-login@example.com",
      password_hash: Auth::Passwords.hash_password(CATALOG_PASSWORD)
    )
  end

  # refresh/logout 프로브는 각자 아직 쓰이지 않은 refresh token이 필요하다 —
  # 하나를 나눠 쓰면 뒤 프로브가 401 TOKEN_REVOKED를 받는다. 컨트롤러가 쓰는
  # 것과 같은 원시 함수로 발급한다.
  def catalog_refresh_token
    user = create(:user)
    Auth::RefreshSessions.issue_for_locked_user(user).refresh_token
  end
end

RSpec.configure do |config|
  config.include ApiRouteCatalog, type: :request
end
