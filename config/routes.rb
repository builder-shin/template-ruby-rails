Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "/health/live", to: proc { [200, {}, ["OK"]] }
  get "/health/ready", to: proc { [200, {}, ["OK"]] }

  namespace :api do
    namespace :v1 do
      # Blog — example domain demonstrating CrudActions (filtering, pagination,
      # JSON:API includes, enums). Replace with your own resources.
      resources :blog_posts
      resources :blog_categories
      resources :blog_post_categories, only: [:index, :show, :create, :destroy]
      resources :blog_views, only: [:index, :show, :create]
      resources :blog_author_permissions

      # Email templates — backs NotificationService (SendGrid template dispatch)
      resources :email_templates
    end
  end
end
