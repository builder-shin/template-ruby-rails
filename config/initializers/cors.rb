Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "http://localhost:3000").split(",").map(&:strip)

  allow do
    origins allow_origins
    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization", "X-Total-Count", "Content-Type", "ETag" ],
      credentials: true
  end
end
