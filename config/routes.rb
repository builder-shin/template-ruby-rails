Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "/health/live", to: proc { [200, {}, ["OK"]] }
  get "/health/ready", to: proc { [200, {}, ["OK"]] }

  namespace :api do
    namespace :v1 do
      # Reference data
      resources :countries, only: [:index, :show]
      resources :job_categories, only: [:index, :show]

      # Career Hub
      resources :career_hub_categories, only: [:index, :show]
      resources :career_hub_communities
      resources :career_hub_community_events
      resources :career_hub_community_event_participants
      resources :career_hub_community_feeds
      resources :career_hub_community_feed_likes, only: [:index, :show, :create, :destroy]
      resources :career_hub_community_leaders
      resources :career_hub_community_members
      resources :career_hub_event_reviews

      # Job Posts
      resources :job_posts
      resources :job_post_categories
      resources :job_post_jobs
      resources :job_post_languages

      # Jobs
      resources :jobs, only: [:index, :show]
      resources :job_applications

      # Profiles
      resources :profiles
      resources :profile_attachments
      resources :direct_uploads, only: [:create]
      resources :profile_educations
      resources :profile_experiences
      resources :profile_freelance_experiences
      resources :profile_highlights
      resources :profile_languages
      resources :profile_links
      resources :profile_projects
      resources :featured_profiles, only: [:index, :show]

      # Blog
      resources :blog_posts

      # Recruitment
      resources :recruitment_requests, only: [:create]
    end
  end
end
