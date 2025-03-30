# frozen_string_literal: true

require "test_helper"
require 'minitest/mock'
require "google/cloud/errors" # Required for specific error types

class YoutubeSummarizerServiceTest < ActiveSupport::TestCase
  setup do
    # Create a test episode
    @episode = Episode.create!(
      number: 999,
      title: "Service Test Episode",
      video_id: "dQw4w9WgXcQ", # Valid ID for youtube_url
      air_date: Date.today
    )

    # Mock the Vertex AI client and model chain
    # Mock the model object that the service expects to get
    @mock_model = Minitest::Mock.new 

    # Stub credentials for most tests (override for specific credential tests)
    Rails.application.credentials.stubs(:google_cloud).returns({ project_id: "test-project", location: "us-central1" })
  end

  teardown do
    # Ensure mocks are verified and episode is destroyed
    @episode.destroy if @episode&.persisted?
    # Mocha unstubs automatically
  end

  test "should return summary on successful API call" do
    expected_summary = "This is the expected summary text."
    # Mock the API response structure
    mock_part = OpenStruct.new(text: expected_summary)
    mock_content = OpenStruct.new(parts: [mock_part])
    mock_candidate = OpenStruct.new(content: mock_content)
    mock_response = OpenStruct.new(candidates: [mock_candidate])

    @mock_model.expect :generate_content, mock_response, [Array] # Expect generate_content call

    # Stub the class method *before* initializing the service
    Google::Cloud::AIPlatform.stubs(:generative_model)
                             .with(model_name: YoutubeSummarizerService::MODEL_NAME)
                             .returns(@mock_model)

    service = YoutubeSummarizerService.new(@episode)
    summary = service.call

    assert_equal expected_summary, summary
    @mock_model.verify
  end

  test "should return nil if episode has no youtube_url" do
    @episode.update_column(:video_id, "EPISODE_PLACEHOLDER") # Update without callbacks/validations
    
    service = YoutubeSummarizerService.new(@episode)
    summary = service.call

    assert_nil summary
    # Mocks should not be called in this case
  end

  test "should raise SummarizationError on Google Cloud API error" do
    api_error = Google::Cloud::PermissionDeniedError.new("API permission denied")
    @mock_model.expect :generate_content, nil do |_args| # Expect call but raise error
      raise api_error
    end
    
    # Stub the class method *before* initializing the service
    Google::Cloud::AIPlatform.stubs(:generative_model)
                             .with(model_name: YoutubeSummarizerService::MODEL_NAME)
                             .returns(@mock_model)

    service = YoutubeSummarizerService.new(@episode)

    exception = assert_raises YoutubeSummarizerService::SummarizationError do
      service.call
    end
    assert_match(/API Error: #{api_error.message}/, exception.message)

    # @mock_client.verify # No longer needed
    @mock_model.verify
  end

  test "should raise SummarizationError if API response has no summary text" do
    # Mock response with missing parts/text
    mock_content = OpenStruct.new(parts: [])
    mock_candidate = OpenStruct.new(content: mock_content)
    mock_response = OpenStruct.new(candidates: [mock_candidate])

    @mock_model.expect :generate_content, mock_response, [Array] # Match any array arg
    
    # Stub the class method *before* initializing the service
    Google::Cloud::AIPlatform.stubs(:generative_model)
                             .with(model_name: YoutubeSummarizerService::MODEL_NAME)
                             .returns(@mock_model)

    service = YoutubeSummarizerService.new(@episode)

    exception = assert_raises YoutubeSummarizerService::SummarizationError do
      service.call
    end
    assert_match "No summary content received from API.", exception.message

    # @mock_client.verify # No longer needed
    @mock_model.verify
  end
  test "should raise SummarizationError if Google Cloud Project ID is missing" do
    # Re-stub credentials for this specific test to be missing the project_id
    Rails.application.credentials.stubs(:google_cloud).returns({ location: "us-central1" })

    exception = assert_raises YoutubeSummarizerService::SummarizationError do
      YoutubeSummarizerService.new(@episode) # Error should happen during initialization
    end
    assert_match "Google Cloud Project ID is not configured in credentials.", exception.message
  end
end
