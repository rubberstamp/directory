# frozen_string_literal: true

require "test_helper"

class SummarizeYoutubeVideoJobTest < ActiveJob::TestCase
  setup do
    @episode = Episode.create!(
      number: 999,
      title: "Test Episode for Summarization",
      video_id: "test_video_123",
      air_date: 1.week.ago
    )
  end

  test "updates episode summary on successful summarization" do
    mock_service = mock("youtube_summarizer_service")
    mock_service.expects(:call).returns("This is a generated summary of the episode content.")

    YoutubeSummarizerService.stubs(:new).returns(mock_service)

    SummarizeYoutubeVideoJob.perform_now(@episode.id)

    @episode.reload
    assert_equal "This is a generated summary of the episode content.", @episode.summary
  end

  test "handles missing episode gracefully" do
    assert_nothing_raised do
      SummarizeYoutubeVideoJob.perform_now(999999)
    end
  end

  test "handles nil summary from service" do
    mock_service = mock("youtube_summarizer_service")
    mock_service.expects(:call).returns(nil)

    YoutubeSummarizerService.stubs(:new).returns(mock_service)

    SummarizeYoutubeVideoJob.perform_now(@episode.id)

    @episode.reload
    assert_nil @episode.summary
  end

  test "handles SummarizationError and updates episode with error message" do
    mock_service = mock("youtube_summarizer_service")
    mock_service.expects(:call).raises(YoutubeSummarizerService::SummarizationError, "API quota exceeded")

    YoutubeSummarizerService.stubs(:new).returns(mock_service)

    SummarizeYoutubeVideoJob.perform_now(@episode.id)

    @episode.reload
    assert_match(/Summarization failed:.*API quota exceeded/, @episode.summary)
  end

  test "handles unexpected errors and updates episode with generic error message" do
    mock_service = mock("youtube_summarizer_service")
    mock_service.expects(:call).raises(StandardError, "Unexpected network failure")

    YoutubeSummarizerService.stubs(:new).returns(mock_service)

    SummarizeYoutubeVideoJob.perform_now(@episode.id)

    @episode.reload
    assert_match(/Summarization failed with unexpected error/, @episode.summary)
  end
end
