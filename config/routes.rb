Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "/health/live", to: "health#live"
  get "/health/ready", to: "health#ready"

  namespace :api do
    namespace :v1 do
      # 가입 · 로그인 · refresh 회전 · 로그아웃. 자원 하나의 CRUD가 아니라 서로
      # 다른 네 동작이라 `resources`가 아니라 각자 경로를 명시한다
      # (AuthController가 CrudActions를 쓰지 않는 이유는 그 컨트롤러 코멘트 참고).
      # 전부 무인증 라우트다 — Bearer 토큰을 발급/회전/폐기하는 자리이지, Bearer로
      # 지키는 자리가 아니다.
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      post "auth/logout", to: "auth#logout"

      resources :examples, only: %i[index show create destroy] do
        member do
          get "relationships/category", action: :category_relationship
          patch "relationships/category", action: :replace_category_relationship
          get :category, action: :related_category
          get "relationships/tags", action: :tags_relationship
          post "relationships/tags", action: :add_tags_relationship
          patch "relationships/tags", action: :replace_tags_relationship
          delete "relationships/tags", action: :remove_tags_relationship
          get :tags, action: :related_tags
        end
      end
      patch "examples/:id", to: "examples#update"
      put "examples/:id", to: "examples#upsert"

      # 인증된 본인의 프로필. /users/{id}가 아니라 /users/me 하나뿐이다 — 이
      # 자원은 항상 "나"만 가리킨다(UserSerializer의 link :self가 user.id로
      # 조립하지 않고 이 경로를 그대로 고정하는 것도 같은 이유다).
      get "users/me", to: "users#me"

      # 읽기 전용 참조 자원. Rails에서 "읽기 전용"은 여기서 정한다 — only: %i[index show]가
      # 그 전부이고, CrudActions가 물려준 write 액션은 라우트가 없어 도달할 수 없다.
      # 두 컨트롤러 다 authenticate_active_user! 콜백이 없으므로, 이 only:에 쓰기 동사를 하나라도
      # 추가하면 그대로 인증 없는 쓰기가 열린다 — spec/routing/api/v1/reference_resources_routing_spec.rb의
      # contain_exactly가 그걸 막는 유일한 장치다.
      resources :categories, only: %i[index show], controller: "example_categories"
      resources :tags, only: %i[index show], controller: "example_tags"
    end
  end

  match "/api/*unmatched", to: "application#route_not_found", via: :all
end
