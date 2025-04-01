# Configure the YT gem with our Google API key for YouTube integration

Yt.configure do |config|
  # Use the API key from Rails credentials
  config.api_key = Rails.application.credentials.GOOGLE_API_KEY
  
  # Set log level to info to reduce excessive logging (debug generates too much output)
  config.log_level = :debug
end

# Enable caching for YouTube API requests
Rails.application.config.after_initialize do
  # Use a separate cache store for YouTube API responses
  youtube_cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 24.hours)
  
end
