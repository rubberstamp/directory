# Configure the YT gem with our Google API key for YouTube integration

Yt.configure do |config|
  # Use the API key from Rails credentials
  config.api_key = Rails.application.credentials.GOOGLE_API_KEY
  
  # Set log level to debug to show more detailed errors
  config.log_level = :debug if Rails.env.development?
end