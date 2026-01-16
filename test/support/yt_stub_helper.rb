# frozen_string_literal: true

# Helper module for stubbing YouTube API (Yt gem) calls in tests
module YtStubHelper
  # Creates a mock Yt::Video object
  def stub_yt_video(attrs = {})
    defaults = {
      id: "test_video_123",
      title: "Test Video Title",
      description: "Test video description",
      duration: 1800, # 30 minutes in seconds
      published_at: 1.day.ago,
      thumbnail_url: "https://example.com/thumbnail.jpg"
    }
    attrs = defaults.merge(attrs)

    mock = Minitest::Mock.new
    mock.expect(:id, attrs[:id])
    mock.expect(:title, attrs[:title])
    mock.expect(:description, attrs[:description])
    mock.expect(:duration, attrs[:duration])
    mock.expect(:published_at, attrs[:published_at])

    # thumbnail_url accepts a size argument
    mock.define_singleton_method(:thumbnail_url) do |_size = nil|
      attrs[:thumbnail_url]
    end

    mock
  end

  # Creates a mock Yt::Channel object
  def stub_yt_channel(attrs = {})
    defaults = {
      id: "UC_test_channel",
      title: "Test Channel",
      video_count: 10
    }
    attrs = defaults.merge(attrs)

    mock = Minitest::Mock.new
    mock.expect(:id, attrs[:id])
    mock.expect(:title, attrs[:title])
    mock.expect(:video_count, attrs[:video_count])
    mock
  end

  # Creates a mock videos collection that responds to iteration
  def stub_video_collection(videos)
    collection = Object.new
    collection.define_singleton_method(:each) do |&block|
      videos.each(&block)
    end
    collection.define_singleton_method(:map) do |&block|
      videos.map(&block)
    end
    collection.define_singleton_method(:any?) { videos.any? }
    collection.define_singleton_method(:count) { videos.count }
    collection.define_singleton_method(:size) { videos.size }
    collection.define_singleton_method(:to_a) { videos }
    collection
  end
end
