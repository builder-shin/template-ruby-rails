Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "/health/live", to: "health#live"
  get "/health/ready", to: "health#ready"

  namespace :api do
    namespace :v1 do
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
    end
  end

  match "/api/*unmatched", to: "application#route_not_found", via: :all
end
