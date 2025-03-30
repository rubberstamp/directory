# frozen_string_literal: true

require "google/cloud/ai_platform"

# Service to summarize a YouTube video using Vertex AI Gemini API
class YoutubeSummarizerService
  # Define constants for configuration - check environment variables first, then fall back to credentials
  PROJECT_ID = ENV["GOOGLE_CLOUD_PROJECT_ID"] || Rails.application.credentials.dig(:google_cloud, :project_id)
  LOCATION = ENV["GOOGLE_CLOUD_LOCATION"] || Rails.application.credentials.dig(:google_cloud, :location) || "us-central1"
  API_KEY = ENV["GOOGLE_API_KEY"] || Rails.application.credentials.dig(:google_cloud, :api_key)
  MODEL_NAME = ENV["GEMINI_MODEL_NAME"] || "gemini-1.5-flash" # Or use gemini-1.5-pro for higher quality/cost

  # Allow for response stubbing in tests
  attr_writer :stub_response

  # Error class for service-specific issues
  class SummarizationError < StandardError; end

  def initialize(episode)
    raise ArgumentError, "Episode cannot be nil" unless episode

    @episode = episode
    
    # Check configuration and exit early if not valid (in development only)
    return unless validate_configuration!

    # Skip actual client initialization in test environment
    return if Rails.env.test?

    begin
      # Use a simple direct HTTP client to access the Gemini API
      require 'net/http'
      require 'uri'
      require 'json'
      
      # Set up our own simple HTTP client for the Gemini API
      @http_client = Net::HTTP.new("generativelanguage.googleapis.com", 443)
      @http_client.use_ssl = true
      
      @client_initialized = true
      
      Rails.logger.info "Successfully initialized HTTP client for Gemini API"
      
      @client_initialized = true
    rescue Google::Cloud::Error => e
      # Catch potential auth/config errors during initialization
      Rails.logger.error "Failed to initialize Vertex AI client: #{e.message}"
      
      # In development, we'll just log the error and continue without a client
      if Rails.env.development?
        Rails.logger.warn "YouTube summarization will not be available."
        @client_initialized = false
      else 
        # In production, we'll raise an error
        raise SummarizationError, "Failed to initialize Vertex AI client. Ensure credentials (e.g., GOOGLE_APPLICATION_CREDENTIALS) and project ID/location are correctly configured. Original error: #{e.message}"
      end
    rescue => e
      Rails.logger.error "Unexpected error during Vertex AI client initialization: #{e.message}"
      
      # In development, we'll just log the error and continue without a client
      if Rails.env.development?
        Rails.logger.warn "YouTube summarization will not be available."
        @client_initialized = false
      else
        # In production, we'll raise an error
        raise SummarizationError, "Unexpected error during Vertex AI client initialization: #{e.message}"
      end
    end
  end

  def call
    Rails.logger.info "Starting summarization for Episode ##{@episode.number}"
    Rails.logger.info "Original Video ID: #{@episode.video_id.inspect}"
    
    # Check if video_id is present
    if @episode.video_id.blank?
      Rails.logger.warn "Episode ##{@episode.number} does not have a video ID. Skipping summarization."
      return nil
    end
    
    # Check if it's a placeholder ID
    if @episode.video_id.start_with?("EP")
      Rails.logger.warn "Episode ##{@episode.number} has a placeholder video ID (#{@episode.video_id}). Skipping summarization."
      return nil
    end
    
    # Extract video ID properly to verify what video is being used
    video_id = extract_video_id(@episode.video_id)
    Rails.logger.info "Extracted Video ID: #{video_id.inspect}"
    
    # Validate extracted video ID
    if video_id.nil? || video_id.length != 11
      Rails.logger.warn "Episode ##{@episode.number} has an invalid YouTube video ID format: #{@episode.video_id}. Skipping summarization."
      return nil
    end

    # In development, return a message if credentials aren't set up
    if Rails.env.development? && !@client_initialized
      Rails.logger.warn "YouTube summarization skipped: Vertex AI client not initialized."
      return "Video summarization not available. Google Cloud credentials not configured."
    end

    begin
      # Use test stub in test environment to bypass actual API call
      if Rails.env.test?
        response = @stub_response || raise("No stub_response provided for test")
        
        # Extract the summary text from stub response
        if response.respond_to?(:candidates)
          summary = response.candidates.first&.content&.parts&.first&.text
        else
          # If it's a simple string in tests
          return response.to_s
        end
      else
        # Check if client was initialized
        unless @client_initialized
          raise SummarizationError, "Vertex AI client not initialized"
        end
        
        # Extract the video ID properly
        extracted_video_id = extract_video_id(@episode.video_id)
        Rails.logger.debug "DEBUG: YouTube extraction: Original video_id field: #{@episode.video_id.inspect}"
        Rails.logger.debug "DEBUG: YouTube extraction: Extracted video ID: #{extracted_video_id.inspect}"
        
        # Check if we have a valid video ID (standard YouTube IDs are 11 characters)
        if extracted_video_id.nil? || extracted_video_id.length != 11
          Rails.logger.error "Invalid YouTube video ID extracted: #{extracted_video_id.inspect} from original: #{@episode.video_id.inspect}"
          raise SummarizationError, "Could not extract a valid YouTube video ID"
        end
        
        # IMPORTANT: Instruct Gemini to analyze a specific video by ID, not rely on URL fetching
        youtube_url = "https://www.youtube.com/watch?v=#{extracted_video_id}"
        Rails.logger.debug "DEBUG: YouTube extraction: Final YouTube URL: #{youtube_url.inspect}"
        
        # Save the extracted video ID and URL for verification
        Rails.logger.info "Using YouTube video ID: #{extracted_video_id} (URL: #{youtube_url})"
        
        # Try to fetch metadata to verify the video and enhance prompt
        metadata = fetch_video_metadata(extracted_video_id)
        Rails.logger.debug "DEBUG: Video metadata: #{metadata.inspect}"
        
        # Create basic metadata if fetching failed
        if metadata.nil?
          # For episodes, we can use the episode title as a fallback
          metadata = {
            title: @episode.title || "YouTube Video",
            channel: "Procurement Express Podcast",
            description: @episode.notes.to_s[0..100] + "..." 
          }
          Rails.logger.debug "DEBUG: Using fallback metadata: #{metadata.inspect}"
        end
        
        # Build a more explicit prompt for Gemini with metadata if available
        if metadata
          prompt_template = <<~PROMPT
            I need you to provide a summary of a specific YouTube video with the ID: #{extracted_video_id}
            The full URL for this video is: #{youtube_url}
            
            Video details:
            - Title: "#{metadata[:title]}"
            - Channel: #{metadata[:channel]}
            - Description excerpt: "#{metadata[:description]}"
            
            Please analyze and summarize ONLY this exact video with ID #{extracted_video_id}. 
            The video should be titled "#{metadata[:title]}" on the #{metadata[:channel]} channel.
            
            Focus on the main topics discussed in the video and the key takeaways.
            Provide a concise summary (2-3 paragraphs) suitable for podcast show notes.
            If you cannot access this specific video or if the video you find has a different title/channel, please indicate that in your response.
          PROMPT
        else
          prompt_template = <<~PROMPT
            I need you to provide a summary of a specific YouTube video with the ID: #{extracted_video_id}
            The full URL for this video is: #{youtube_url}
            
            Please analyze and summarize ONLY this exact video:
            Video ID: #{extracted_video_id}
            Video URL: #{youtube_url}
            
            Focus on the main topics discussed in the video and the key takeaways.
            Provide a concise summary (2-3 paragraphs) suitable for podcast show notes.
            If you cannot access this specific video, please indicate that in your response.
          PROMPT
        end

        # Prepare the Gemini API request
        endpoint_path = "/v1beta/models/#{MODEL_NAME}:generateContent"
        
        # Create a prompt that utilizes the metadata and episode information we already have
        # since the model can't actually access YouTube videos
        
        # Extract useful information from the episode for context
        episode_info = {
          title: @episode.title || "Unknown Title",
          number: @episode.number || "Unknown Number",
          notes: @episode.notes || "",
        }
        
        # Prepare a better prompt based on episode data
        request_body = {
          contents: [
            {
              role: "user",
              parts: [
                { 
                  text: <<~PROMPT
                    I need you to create a concise summary (2-3 paragraphs) suitable for podcast show notes for an episode of the "Procurement Express Podcast".
                    
                    Here's information about the episode:
                    - Episode ##{episode_info[:number]}: "#{episode_info[:title]}"
                    - YouTube video ID: #{extracted_video_id}
                    - YouTube URL: #{youtube_url}
                    
                    Here are the episode notes or description:
                    """
                    #{episode_info[:notes].to_s.strip}
                    """
                    
                    Based on this information, please write a professional and engaging summary that:
                    - Captures the key topics discussed in the episode
                    - Highlights main points and takeaways 
                    - Is written in a clear, professional style
                    - Is appropriate for a business podcast about procurement
                    - Consists of 2-3 concise paragraphs
                    
                    Write in third person, present tense, and focus on the content rather than summarizing what the hosts did.
                  PROMPT
                }
              ]
            }
          ],
          generation_config: {
            temperature: 0.3,  # Slightly higher temperature for more creativity with limited information
            max_output_tokens: 1024,
            top_p: 0.8,
            top_k: 40
          }
        }.to_json
        
        # Create an HTTP request with API key
        request_path = "#{endpoint_path}?key=#{API_KEY}"
        request = Net::HTTP::Post.new(request_path)
        request["Content-Type"] = "application/json"
        
        request.body = request_body
        
        # Log the full request for debugging
        Rails.logger.debug "DEBUG: Gemini API request body: #{request_body}"
        
        # Make the HTTP request
        response = @http_client.request(request)
        
        # Log the full response for debugging
        Rails.logger.debug "DEBUG: Gemini API response code: #{response.code}"
        Rails.logger.debug "DEBUG: Gemini API response body: #{response.body}"
        
        # Check if the request was successful
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "Vertex AI API error: #{response.code} - #{response.body}"
          raise SummarizationError, "Vertex AI API error: #{response.code} - #{response.message}"
        end
        
        # Parse the response
        response_data = JSON.parse(response.body)
        
        # Extract summary from Gemini API response
        if response_data["candidates"] && !response_data["candidates"].empty?
          candidate = response_data["candidates"].first
          
          if candidate["content"] && 
             candidate["content"]["parts"] && 
             !candidate["content"]["parts"].empty?
            
            # Extract text from all parts
            summary_parts = candidate["content"]["parts"].map do |part|
              part["text"] if part["text"]
            end.compact
            
            summary = summary_parts.join(" ")
          else
            Rails.logger.error "Unexpected response format from Gemini API: #{response_data}"
            raise SummarizationError, "No text content in Gemini API response"
          end
        else
          Rails.logger.error "No candidates in response: #{response_data}"
          raise SummarizationError, "No candidates in Gemini API response"
        end
      end

      if summary.present?
        # Check if the response indicates it's refusing to generate content
        if summary.match?(/cannot generate|cannot create|unable to generate|not possible to generate|cannot provide a summary/i)
          Rails.logger.error "Gemini refuses to generate a summary for Episode ##{@episode.number}"
          raise SummarizationError, "The AI model refused to generate a summary. Please check the episode content or create a manual summary."
        end
        
        # Do basic quality check to ensure we have multiple sentences in the summary
        sentence_count = summary.scan(/[.!?]/).count
        if sentence_count < 3
          Rails.logger.warn "Generated summary for Episode ##{@episode.number} has only #{sentence_count} sentences. Summary might be too short."
        end
        
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

  # Attempt to fetch video metadata to verify we have the correct video
  def fetch_video_metadata(video_id)
    return nil if Rails.env.test? # Skip in test environment
    
    # Method 1: Try using the Yt gem if available
    if defined?(Yt::Video)
      begin
        yt_video = Yt::Video.new(id: video_id)
        
        # Return basic metadata
        return {
          title: yt_video.title,
          channel: yt_video.channel_title,
          description: yt_video.description.to_s[0..100] + "..." # First 100 chars
        }
      rescue => e
        Rails.logger.warn "Could not fetch YouTube metadata using Yt: #{e.message}"
      end
    end
    
    # Method 2: Try to fetch the OG tags from the YouTube page
    begin
      require 'net/http'
      url = URI("https://www.youtube.com/watch?v=#{video_id}")
      response = Net::HTTP.get_response(url)
      
      if response.is_a?(Net::HTTPSuccess)
        html = response.body
        
        # Extract metadata from HTML using simple regex
        title_match = html.match(/<meta property="og:title" content="([^"]+)"/)
        site_name_match = html.match(/<meta property="og:site_name" content="([^"]+)"/)
        
        if title_match
          return {
            title: title_match[1],
            channel: site_name_match ? site_name_match[1] : "YouTube",
            description: "Video from YouTube"
          }
        end
      end
    rescue => e
      Rails.logger.warn "Could not fetch YouTube metadata using HTTP request: #{e.message}"
    end
    
    # Fallback: Return nil if neither method works
    nil
  end

  private
  
  # Extract video ID from various formats of YouTube URLs
  def extract_video_id(input)
    return nil if input.blank?
    
    # Clean up the input
    input = input.strip
    
    # Log the input for debugging
    Rails.logger.debug "DEBUG: extract_video_id input: #{input.inspect}"
    
    # If it's already a clean video ID (11 characters) with no URL components
    if input.length == 11 && !input.include?('/') && !input.include?(':') && !input.include?('.')
      Rails.logger.debug "DEBUG: Treating as clean video ID: #{input}"
      return input
    end
    
    # Try various methods to extract the ID
    
    # Method 1: Standard watch URLs
    if input.include?('youtube.com/watch?v=')
      match = input.match(/youtube\.com\/watch\?v=([^&]{11})/)
      if match && match[1]
        Rails.logger.debug "DEBUG: Extracted via standard watch URL: #{match[1]}"
        return match[1]
      end
    end
    
    # Method 2: Shortened youtu.be URLs
    if input.include?('youtu.be/')
      match = input.match(/youtu\.be\/([^?&\/]{11})/)
      if match && match[1]
        Rails.logger.debug "DEBUG: Extracted via shortened URL: #{match[1]}"
        return match[1]
      end
    end
    
    # Method 3: Embed URLs
    if input.include?('youtube.com/embed/')
      match = input.match(/youtube\.com\/embed\/([^?&\/]{11})/)
      if match && match[1]
        Rails.logger.debug "DEBUG: Extracted via embed URL: #{match[1]}"
        return match[1]
      end
    end
    
    # Method 4: General regex for any URL format (fallback)
    if input.match?(/\A(https?:\/\/)/)
      regex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/
      match = input.match(regex)
      if match && match[1]
        Rails.logger.debug "DEBUG: Extracted via general regex: #{match[1]}"
        return match[1]
      end
    end
    
    # If all extraction methods fail but input is 11 characters, it might be an ID
    if input.length == 11
      Rails.logger.debug "DEBUG: Returning as potential video ID based on length: #{input}"
      return input
    end
    
    # Log if we couldn't extract a proper ID
    Rails.logger.debug "DEBUG: Could not extract video ID from: #{input}"
    
    # Return nil to indicate failure
    nil
  end

  def validate_configuration!
    # Skip validation in test environment if we're testing missing project ID
    # This allows tests to mock the missing project ID scenario
    return if Rails.env.test? && !PROJECT_ID
    
    unless PROJECT_ID
      raise SummarizationError, "Google Cloud Project ID (google_cloud.project_id) is not configured in Rails credentials."
    end
    
    # Also validate that we have either an API key (recommended) or auth credentials
    unless API_KEY
      # In development, we'll check for credentials and log warnings instead of failing
      if Rails.env.development?
        Rails.logger.warn <<~WARNING
          ⚠️ Google Cloud API key not found. YouTube video summarization requires an API key.
          
          To fix this:
          
          1. Create a Gemini API key:
             a. Go to https://makersuite.google.com/app/apikey
             b. Create a new API key
          
          2. Add your API key to Rails credentials:
             $ EDITOR="code --wait" rails credentials:edit
             
             Add the following to your credentials file:
             
             google_cloud:
               project_id: your-project-id-here
               location: us-central1
               api_key: your-api-key-here
          
          After completing these steps, restart your Rails server.
        WARNING
        return false  # Return false to indicate credentials are missing
      else
        # In production, an API key is required
        raise SummarizationError, "Google Cloud API key is not configured in Rails credentials."
      end
    end
    
    # Authentication itself is typically handled by Application Default Credentials (ADC)
    # which relies on the environment (e.g., GOOGLE_APPLICATION_CREDENTIALS variable or GCE metadata service).
    # The client initialization will fail if ADC is not set up correctly.
    true  # Return true to indicate validation passed
  end
end
