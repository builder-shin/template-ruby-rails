Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "/health/live", to: proc { [ 200, {}, [ "OK" ] ] }
  get "/health/ready", to: proc { [ 200, {}, [ "OK" ] ] }

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

      # Blog — example domain demonstrating CrudActions (filtering, pagination,
      # JSON:API includes, enums). Replace with your own resources.
      resources :blog_posts
      resources :blog_categories
      resources :blog_post_categories, only: [ :index, :show, :create, :destroy ]
      resources :blog_views, only: [ :index, :show, :create ]
      resources :blog_author_permissions

      # Email templates — backs NotificationService (SendGrid template dispatch)
      resources :email_templates
    end
  end

  match "/api/*unmatched", to: "application#route_not_found", via: :all
end
