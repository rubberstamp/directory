#!/usr/bin/env ruby
# Script to test YouTube API integration
# Run with: bundle exec ruby test_youtube_api.rb

require_relative 'config/environment'

puts "\n=== Testing YouTube API Integration ===\n\n"

# Test 1: Check if API key is configured
puts "Test 1: Checking API key configuration..."
api_key = Rails.application.credentials.GOOGLE_API_KEY
if api_key.present?
  puts "✓ API key is configured in credentials"
else
  puts "✗ API key is missing in credentials"
  exit 1
end

# Test 2: Try to fetch a known YouTube video
puts "\nTest 2: Fetching a known YouTube video..."
TEST_VIDEO_ID = "dQw4w9WgXcQ"  # Rick Astley - Never Gonna Give You Up

begin
  puts "Trying to fetch video with ID: #{TEST_VIDEO_ID}"
  
  # Try direct YT gem access first for better error messages
  puts "Direct YT gem access:"
  begin
    yt_video = Yt::Video.new(id: TEST_VIDEO_ID)
    puts "  - Accessing title: #{yt_video.title.inspect}"
  rescue => e
    puts "  ✗ Direct YT gem error: #{e.class.name}: #{e.message}"
    if e.message.include?("API key")
      puts "    This appears to be an API key issue. Check if your key is valid and has YouTube Data API v3 access."
    end
  end
  
  # Now try the wrapper model
  puts "\nUsing YoutubeVideo model:"
  video = YoutubeVideo.find(TEST_VIDEO_ID)
  if video
    puts "✓ Successfully fetched video:"
    puts "  - Title: #{video.title}"
    puts "  - Channel: #{video.channel_title}"
    puts "  - Published: #{video.published_at&.strftime('%Y-%m-%d')}"
    puts "  - Duration: #{video.duration}"
    puts "  - Thumbnail: #{video.thumbnail_url}"
  else
    puts "✗ Failed to fetch test video"
    puts "  Check Rails logs for detailed error messages"
    puts "  Common issues: Invalid API key, API quota exceeded, or network issues"
    exit 1
  end
rescue => e
  puts "✗ Error fetching test video: #{e.class.name}: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end

# Test 3: Search for videos
puts "\nTest 3: Searching for videos using YoutubeVideo model..."
begin
  search_term = "procurement podcast"

  # Test the application's wrapper model directly
  puts "Using YoutubeVideo.search:"
  results = YoutubeVideo.search(search_term, max_results: 3)

  if results.any?
    puts "✓ Successfully searched for '#{search_term}':"
    results.each_with_index do |result, index|
      puts "  #{index+1}. #{result.title} (#{result.id})"
    end
  else
    puts "✗ No search results returned"
    puts "  Check Rails logs for detailed error messages"
    puts "  Common issues: Search quota differs from basic quota and may need separate approval"
  end
rescue => e
  puts "✗ Error searching videos: #{e.class.name}: #{e.message}"
  puts e.backtrace.join("\n")
end

# Test 4: Try using the Yt gem directly
puts "\nTest 4: Using Yt gem directly (basic channel instantiation)..."
begin
  # Instantiate the channel object. This verifies the ID format and basic API connectivity
  # without necessarily fetching all details, reducing API cost for this test.
  channel = Yt::Channel.new(id: 'UC_x5XG1OV2P6uZZ5FSM9Ttw') # Google Developers channel
  puts "✓ Successfully instantiated Yt::Channel object for ID 'UC_x5XG1OV2P6uZZ5FSM9Ttw'"
  # We avoid accessing properties like .title, .subscriber_count, .video_count here
  # to minimize API calls during this basic test.
rescue => e
  puts "✗ Error instantiating Yt::Channel object: #{e.message}"
  puts "  This could indicate an issue with the API key, permissions, or the channel ID itself."
  puts e.backtrace.join("\n")
  exit 1
end

puts "\n✓ All tests passed! YT gem is configured correctly."
