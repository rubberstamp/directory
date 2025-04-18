# Configure the YT gem with our Google API key for YouTube integration

Yt.configure do |config|
  # Use the API key from Rails credentials (properly nested under google_cloud)
  config.api_key = ENV["GOOGLE_API_KEY"] || Rails.application.credentials.dig(:google_cloud, :api_key)

  # Set log level to debug to diagnose API issues
  config.log_level = :debug
end

# Enable caching for YouTube API requests
Rails.application.config.after_initialize do
  # Use a separate cache store for YouTube API responses
  youtube_cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 24.hours)
end
