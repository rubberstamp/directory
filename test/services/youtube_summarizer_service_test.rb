# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
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

    # Mock the model object that the service expects to get
    @mock_model = Minitest::Mock.new
    # Define standard test credentials
    @test_credentials = { project_id: "test-project", location: "us-central1" }
  end

  teardown do
    # Ensure mocks are verified and episode is destroyed
    @episode.destroy if @episode&.persisted?
    # Minitest stub cleans up automatically
  end

  test "should return summary on successful API call" do
    expected_summary = "This is the expected summary text."
    # Mock the API response structure
    mock_part = OpenStruct.new(text: expected_summary)
    mock_content = OpenStruct.new(parts: [ mock_part ])
    mock_candidate = OpenStruct.new(content: mock_content)
    mock_response = OpenStruct.new(candidates: [ mock_candidate ])

    @mock_model.expect :generate_content, mock_response, [ Array ] # Expect generate_content call

    # Define the stub logic for the class method
    generative_model_stub = ->(model_name:) {
      assert_equal YoutubeSummarizerService::MODEL_NAME, model_name
      @mock_model # Return the mock model object
    }

    # Stub the necessary methods within the block
    Rails.application.credentials.stub :google_cloud, @test_credentials do
      Google::Cloud::AIPlatform.stub :generative_model, generative_model_stub do
        service = YoutubeSummarizerService.new(@episode)
        summary = service.call
        assert_equal expected_summary, summary
      end
    end
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

    # Define the stub logic for the class method
    generative_model_stub = ->(model_name:) {
      assert_equal YoutubeSummarizerService::MODEL_NAME, model_name
      @mock_model # Return the mock model object
    }

    # Stub the necessary methods within the block
    Rails.application.credentials.stub :google_cloud, @test_credentials do
      Google::Cloud::AIPlatform.stub :generative_model, generative_model_stub do
        service = YoutubeSummarizerService.new(@episode)
        exception = assert_raises YoutubeSummarizerService::SummarizationError do
          service.call
        end
        assert_match(/API Error: #{api_error.message}/, exception.message)

        # @mock_client.verify # No longer needed
        @mock_model.verify
      end
    end
  end

  test "should raise SummarizationError if API response has no summary text" do
    # Mock response with missing parts/text
    mock_content = OpenStruct.new(parts: [])
    mock_candidate = OpenStruct.new(content: mock_content)
    mock_response = OpenStruct.new(candidates: [ mock_candidate ])

    @mock_model.expect :generate_content, mock_response, [ Array ] # Match any array arg

    # Define the stub logic for the class method
    generative_model_stub = ->(model_name:) {
      assert_equal YoutubeSummarizerService::MODEL_NAME, model_name
      @mock_model # Return the mock model object
    }

    # Stub the necessary methods within the block
    Rails.application.credentials.stub :google_cloud, @test_credentials do
      Google::Cloud::AIPlatform.stub :generative_model, generative_model_stub do
        service = YoutubeSummarizerService.new(@episode)
        exception = assert_raises YoutubeSummarizerService::SummarizationError do
          service.call
        end
        assert_match "No summary content received from API.", exception.message

        # @mock_client.verify # No longer needed
        @mock_model.verify
      end
    end
  end
  test "should raise SummarizationError if Google Cloud Project ID is missing" do
    # Stub credentials to be missing the project_id for this test
    Rails.application.credentials.stub :google_cloud, { location: "us-central1" } do
      exception = assert_raises YoutubeSummarizerService::SummarizationError do
        YoutubeSummarizerService.new(@episode) # Error should happen during initialization
      end
      assert_match "Google Cloud Project ID (google_cloud.project_id) is not configured in Rails credentials.", exception.message
    end
  end
end
