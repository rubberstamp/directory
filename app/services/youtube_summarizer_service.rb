# frozen_string_literal: true

require "google/cloud/ai_platform"

# Service to summarize a YouTube video using Vertex AI Gemini API
class YoutubeSummarizerService
  # Define constants for configuration
  PROJECT_ID = Rails.application.credentials.google_cloud&.project_id
  LOCATION = Rails.application.credentials.google_cloud&.location || "us-central1" # Default location
  MODEL_NAME = "gemini-1.5-flash-001" # Or use gemini-1.5-pro-001 for higher quality/cost

  # Error class for service-specific issues
  class SummarizationError < StandardError; end

  def initialize(episode)
    raise ArgumentError, "Episode cannot be nil" unless episode

    @episode = episode
    validate_configuration!

    begin
      # Directly initialize the generative model client
      @model = Google::Cloud::AIPlatform.generative_model model_name: MODEL_NAME
    rescue Google::Cloud::Error => e
      # Catch potential auth/config errors during initialization
      Rails.logger.error "Failed to initialize Vertex AI client: #{e.message}"
      raise SummarizationError, "Failed to initialize Vertex AI client. Ensure credentials (e.g., GOOGLE_APPLICATION_CREDENTIALS) and project ID/location are correctly configured. Original error: #{e.message}"
    rescue => e
      Rails.logger.error "Unexpected error during Vertex AI client initialization: #{e.message}"
      raise SummarizationError, "Unexpected error during Vertex AI client initialization: #{e.message}"
    end
  end

  def call
    Rails.logger.info "Starting summarization for Episode ##{@episode.number} (Video ID: #{@episode.video_id})"

    unless @episode.youtube_url
      Rails.logger.warn "Episode ##{@episode.number} does not have a valid YouTube URL. Skipping summarization."
      return nil # Or raise an error?
    end

    begin
      # Prepare the request parts
      video_part = { file_data: { mime_type: "video/youtube", file_uri: @episode.youtube_url } }
      prompt_part = { text: "Provide a concise summary of this YouTube video suitable for show notes. Focus on the key topics discussed and main takeaways. Aim for 2-3 paragraphs." }

      # Make the API call using the initialized model
      response = @model.generate_content(
        [video_part, prompt_part]
      )

      # Extract the summary text
      summary = response.candidates.first&.content&.parts&.first&.text

      if summary.present?
        Rails.logger.info "Successfully generated summary for Episode ##{@episode.number}"
        summary.strip
      else
        Rails.logger.error "Failed to extract summary text from Gemini response for Episode ##{@episode.number}. Response: #{response.inspect}"
        raise SummarizationError, "No summary content received from API."
      end

    rescue Google::Cloud::Error => e
      Rails.logger.error "Google Cloud API Error during summarization for Episode ##{@episode.number}: #{e.message}"
      raise SummarizationError, "API Error: #{e.message}"
    rescue => e
      Rails.logger.error "Unexpected error during summarization for Episode ##{@episode.number}: #{e.message}\n#{e.backtrace.join("\n")}"
      raise SummarizationError, "Unexpected error: #{e.message}"
    end
  end

  private

  def validate_configuration!
    unless PROJECT_ID
      raise SummarizationError, "Google Cloud Project ID (google_cloud.project_id) is not configured in Rails credentials."
    end
    # Authentication itself is typically handled by Application Default Credentials (ADC)
    # which relies on the environment (e.g., GOOGLE_APPLICATION_CREDENTIALS variable or GCE metadata service).
    # The client initialization will fail if ADC is not set up correctly.
  end
end
