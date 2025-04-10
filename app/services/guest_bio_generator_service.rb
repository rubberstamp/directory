# frozen_string_literal: true

require "google/cloud/ai_platform"

# Service to generate a bio for a podcast guest using Vertex AI Gemini API
# Analyzes episodes they've appeared in to create a coherent, personalized bio
class GuestBioGeneratorService
  # Define constants for configuration - using the same as YoutubeSummarizerService
  PROJECT_ID = ENV["GOOGLE_CLOUD_PROJECT_ID"] || Rails.application.credentials.dig(:google_cloud, :project_id)
  LOCATION = ENV["GOOGLE_CLOUD_LOCATION"] || Rails.application.credentials.dig(:google_cloud, :location) || "us-central1"
  API_KEY = ENV["GOOGLE_API_KEY"] || Rails.application.credentials.dig(:google_cloud, :api_key)
  MODEL_NAME = ENV["GEMINI_MODEL_NAME"] || "gemini-1.5-flash" # Or use gemini-1.5-pro for higher quality/cost

  # Allow for response stubbing in tests
  attr_writer :stub_response

  # Error class for service-specific issues
  class BioGenerationError < StandardError; end

  def initialize(profile)
    raise ArgumentError, "Profile cannot be nil" unless profile

    @profile = profile

    # Check configuration and exit early if not valid (in development only)
    return unless validate_configuration!

    # Skip actual client initialization in test environment
    return if Rails.env.test?

    begin
      # Use a simple direct HTTP client to access the Gemini API
      require "net/http"
      require "uri"
      require "json"

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
        Rails.logger.warn "Guest bio generation will not be available."
        @client_initialized = false
      else
        # In production, we'll raise an error
        raise BioGenerationError, "Failed to initialize Vertex AI client. Ensure credentials (e.g., GOOGLE_APPLICATION_CREDENTIALS) and project ID/location are correctly configured. Original error: #{e.message}"
      end
    rescue => e
      Rails.logger.error "Unexpected error during Vertex AI client initialization: #{e.message}"

      # In development, we'll just log the error and continue without a client
      if Rails.env.development?
        Rails.logger.warn "Guest bio generation will not be available."
        @client_initialized = false
      else
        # In production, we'll raise an error
        raise BioGenerationError, "Unexpected error during Vertex AI client initialization: #{e.message}"
      end
    end
  end

  def call
    Rails.logger.info "Starting bio generation for Profile: #{@profile.name}"

    # Check if the profile has any episodes
    episodes = @profile.episodes_by_date

    if episodes.blank?
      Rails.logger.warn "Profile #{@profile.name} has no episodes. Cannot generate bio from episode data."
      return nil
    end

    # In development, return a message if credentials aren't set up
    if Rails.env.development? && !@client_initialized
      Rails.logger.warn "Guest bio generation skipped: Vertex AI client not initialized."
      return "Bio generation not available. Google Cloud credentials not configured."
    end

    begin
      # Use test stub in test environment to bypass actual API call
      if Rails.env.test?
        response = @stub_response || raise("No stub_response provided for test")

        # Extract the bio text from stub response
        if response.respond_to?(:candidates)
          bio = response.candidates.first&.content&.parts&.first&.text
        else
          # If it's a simple string in tests
          return response.to_s
        end
      else
        # Check if client was initialized
        unless @client_initialized
          raise BioGenerationError, "Vertex AI client not initialized"
        end

        # Collect information about the guest and their episodes
        guest_info = {
          name: @profile.name,
          headline: @profile.headline,
          company: @profile.company,
          location: @profile.location,
          specializations: @profile.specializations.map(&:name).join(", "),
          website: @profile.website,
          primary_episodes: @profile.primary_guest_episodes.map { |ep|
            {
              number: ep.number,
              title: ep.title,
              summary: ep.summary,
              notes: ep.notes
            }
          },
          secondary_appearances: @profile.secondary_appearances.map { |appearance|
            {
              episode_number: appearance.episode.number,
              episode_title: appearance.episode.title,
              segment_title: appearance.segment_title,
              appearance_type: appearance.appearance_type
            }
          },
          current_bio: @profile.bio
        }

        # Build a prompt for Gemini to generate a bio
        prompt_template = <<~PROMPT
          I need you to write a professional bio for a podcast guest named #{guest_info[:name]}.
#{'          '}
          Here's information about the guest:
          - Name: #{guest_info[:name]}
          - Headline: #{guest_info[:headline]}
          - Company: #{guest_info[:company]}
          - Location: #{guest_info[:location]}
          - Specializations: #{guest_info[:specializations]}
          - Website: #{guest_info[:website]}
#{'          '}
          The guest has appeared on the following podcast episodes:
          #{guest_info[:primary_episodes].map do |ep|# {' '}
            "- Episode ##{ep[:number]}: \"#{ep[:title]}\"\n" +
            "  Summary: #{ep[:summary]}\n" +
            "  Notes: #{ep[:notes]}"
          end.join("\n\n")}
#{'          '}
          #{if guest_info[:secondary_appearances].any?
            "The guest has also made secondary appearances in:\n" +
            guest_info[:secondary_appearances].map do |appearance|
              "- Episode ##{appearance[:episode_number]}: \"#{appearance[:episode_title]}\"\n" +
              "  Segment: #{appearance[:segment_title]}\n" +
              "  Role: #{appearance[:appearance_type]}"
            end.join("\n\n")
            end}
#{'          '}
They don't currently have a bio, so please create one from scratch based on the podcast appearances.
#{'          '}
          Based on this information, please write a professional and engaging bio that:
          - Is approximately 2-3 paragraphs (150-300 words)
          - Focuses on their professional background, expertise, and achievements
          - Incorporates insights from their podcast appearances when relevant
          - Is written in third person, present tense
          - Has a professional yet engaging tone
          - Emphasizes their areas of expertise and thought leadership
          - Only uses information that can be reasonably inferred from the data provided
#{'          '}
          The bio should not include phrases like "appeared on the podcast" or mention the podcast directly. Instead, integrate insights from their episodes naturally into their professional narrative.
        PROMPT

        # Prepare the Gemini API request
        endpoint_path = "/v1beta/models/#{MODEL_NAME}:generateContent"

        # Prepare request body
        request_body = {
          contents: [
            {
              role: "user",
              parts: [
                {
                  text: prompt_template
                }
              ]
            }
          ],
          generation_config: {
            temperature: 0.4,  # Slightly creative but mostly fact-based
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

        # Log the request for debugging (sanitized)
        Rails.logger.debug "DEBUG: Gemini API request sent for bio generation"

        # Make the HTTP request
        response = @http_client.request(request)

        # Log response code for debugging
        Rails.logger.debug "DEBUG: Gemini API response code: #{response.code}"

        # Check if the request was successful
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "Vertex AI API error: #{response.code} - #{response.body}"
          raise BioGenerationError, "Vertex AI API error: #{response.code} - #{response.message}"
        end

        # Parse the response
        response_data = JSON.parse(response.body)

        # Extract bio from Gemini API response
        if response_data["candidates"] && !response_data["candidates"].empty?
          candidate = response_data["candidates"].first

          if candidate["content"] &&
             candidate["content"]["parts"] &&
             !candidate["content"]["parts"].empty?

            # Extract text from all parts
            bio_parts = candidate["content"]["parts"].map do |part|
              part["text"] if part["text"]
            end.compact

            bio = bio_parts.join(" ")
          else
            Rails.logger.error "Unexpected response format from Gemini API: #{response_data}"
            raise BioGenerationError, "No text content in Gemini API response"
          end
        else
          Rails.logger.error "No candidates in response: #{response_data}"
          raise BioGenerationError, "No candidates in Gemini API response"
        end
      end

      if bio.present?
        # Check if the response indicates it's refusing to generate content
        if bio.match?(/cannot generate|cannot create|unable to generate|not possible to generate/i)
          Rails.logger.error "Gemini refuses to generate a bio for #{@profile.name}"
          raise BioGenerationError, "The AI model refused to generate a bio. Please check the profile data or create a manual bio."
        end

        # Do basic quality check to ensure we have multiple sentences in the bio
        sentence_count = bio.scan(/[.!?]/).count
        if sentence_count < 3
          Rails.logger.warn "Generated bio for #{@profile.name} has only #{sentence_count} sentences. Bio might be too short."
        end

        Rails.logger.info "Successfully generated bio for #{@profile.name}"
        bio.strip
      else
        Rails.logger.error "Failed to extract bio text from Gemini response for #{@profile.name}. Response: #{response.inspect}"
        raise BioGenerationError, "No bio content received from API."
      end

    rescue Google::Cloud::Error => e
      Rails.logger.error "Google Cloud API Error during bio generation for #{@profile.name}: #{e.message}"
      raise BioGenerationError, "API Error: #{e.message}"
    rescue => e
      Rails.logger.error "Unexpected error during bio generation for #{@profile.name}: #{e.message}\n#{e.backtrace.join("\n")}"
      raise BioGenerationError, "Unexpected error: #{e.message}"
    end
  end

  private

  def validate_configuration!
    # Skip validation in test environment if we're testing missing project ID
    # This allows tests to mock the missing project ID scenario
    return if Rails.env.test? && !PROJECT_ID

    unless PROJECT_ID
      raise BioGenerationError, "Google Cloud Project ID (google_cloud.project_id) is not configured in Rails credentials."
    end

    # Also validate that we have either an API key (recommended) or auth credentials
    unless API_KEY
      # In development, we'll check for credentials and log warnings instead of failing
      if Rails.env.development?
        Rails.logger.warn <<~WARNING
          ⚠️ Google Cloud API key not found. Guest bio generation requires an API key.

          To fix this:

          1. Create a Gemini API key:
             a. Go to https://makersuite.google.com/app/apikey
             b. Create a new API key

          2. Add your API key to Rails credentials:
             $ EDITOR="code --wait" rails credentials:edit
          #{'   '}
             Add the following to your credentials file:
          #{'   '}
             google_cloud:
               project_id: your-project-id-here
               location: us-central1
               api_key: your-api-key-here

          After completing these steps, restart your Rails server.
        WARNING
        return false  # Return false to indicate credentials are missing
      else
        # In production, an API key is required
        raise BioGenerationError, "Google Cloud API key is not configured in Rails credentials."
      end
    end

    # Authentication itself is typically handled by Application Default Credentials (ADC)
    # which relies on the environment (e.g., GOOGLE_APPLICATION_CREDENTIALS variable or GCE metadata service).
    # The client initialization will fail if ADC is not set up correctly.
    true  # Return true to indicate validation passed
  end
end
