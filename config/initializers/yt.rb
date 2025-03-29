# Configure the YT gem with our Google API key for YouTube integration

Yt.configure do |config|
  # Use the API key from Rails credentials
  config.api_key = Rails.application.credentials.GOOGLE_API_KEY
  
  # Set log level to info to reduce excessive logging (debug generates too much output)
  config.log_level = :info
end

# Enable caching for YouTube API requests
Rails.application.config.after_initialize do
  # Use a separate cache store for YouTube API responses
  youtube_cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 24.hours)
  
  # Monkey patch the Yt::Request class to use caching
  # We need to do this because Yt gem doesn't provide built-in caching
  if defined?(Yt::Request)
    Yt::Request.class_eval do
      class << self
        alias_method :original_process, :process
        
        def process(options = {})
          # Generate a cache key based on the request options
          cache_key = "yt_request_#{options.to_s.hash}"
          
          # Try to get from cache first
          youtube_cache.fetch(cache_key) do
            # If not cached, make the actual request
            original_process(options)
          end
        end
      end
    end
  end
end
