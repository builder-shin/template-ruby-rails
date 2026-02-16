Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "/health/live", to: proc { [200, {}, ["OK"]] }
  get "/health/ready", to: proc { [200, {}, ["OK"]] }

  namespace :api do
    namespace :v1 do
      # Add your routes here
    end
  end
end
