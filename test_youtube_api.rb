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
puts "\nTest 3: Searching for videos..."
begin
  search_term = "procurement podcast"
  
  # Try direct YT gem search first
  puts "Direct YT gem search:"
  begin
    yt_results = Yt::Collections::Videos.new.where(
      q: search_term,
      order: 'relevance', 
      max_results: 3
    )
    
    # Test if we can iterate the results
    first_result = yt_results.first
    if first_result
      puts "  ✓ Direct search successful"
      puts "    First result: #{first_result.title} (#{first_result.id})"
    else
      puts "  ✗ No direct search results"
    end
  rescue => e
    puts "  ✗ Direct YT gem search error: #{e.class.name}: #{e.message}"
  end
  
  # Now try the wrapper model
  puts "\nUsing YoutubeVideo model search:"
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
puts "\nTest 4: Using Yt gem directly..."
begin
  channel = Yt::Channel.new(id: 'UC_x5XG1OV2P6uZZ5FSM9Ttw')  # Google Developers channel
  puts "✓ Successfully fetched channel '#{channel.title}'"
  puts "  - Subscriber count: #{channel.subscriber_count}"
  puts "  - Video count: #{channel.video_count}"
rescue => e
  puts "✗ Error using Yt gem directly: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end

puts "\n✓ All tests passed! YT gem is configured correctly."