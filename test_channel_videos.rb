#!/usr/bin/env ruby
# Script to list videos from a specific YouTube channel
# Run with: bundle exec ruby test_channel_videos.rb

require_relative 'config/environment'

puts "\n=== Fetching videos from YouTube channel ===\n\n"

CHANNEL_ID = "UCFfHVZhyEiN1QXX4s3Z_How"

begin
  puts "Fetching channel info for ID: #{CHANNEL_ID}"
  channel = Yt::Channel.new(id: CHANNEL_ID)
  
  puts "Channel: #{channel.title}"
  puts "Subscriber count: #{channel.subscriber_count}"
  puts "Video count: #{channel.video_count}"
  
  puts "\nFetching videos (limited to last 10):"
  videos = channel.videos.take(10)
  
  if videos.any?
    videos.each_with_index do |video, index|
      published = video.published_at&.strftime('%Y-%m-%d') || 'Unknown date'
      duration = video.duration ? "#{video.duration / 60}:#{video.duration % 60}" : 'Unknown'
      
      puts "#{index + 1}. #{video.title}"
      puts "   ID: #{video.id}"
      puts "   Published: #{published}"
      puts "   Duration: #{duration}"
      puts "   Views: #{video.view_count}"
      puts "   URL: https://www.youtube.com/watch?v=#{video.id}"
      puts ""
    end
  else
    puts "No videos found for this channel."
  end
rescue Yt::Errors::Forbidden => e
  puts "Error: API quota exceeded. Please try again later."
  puts "Error details: #{e.message}"
rescue Yt::Errors::NoItems => e
  puts "Error: Channel not found or has no public videos."
  puts "Error details: #{e.message}"
rescue => e
  puts "Unexpected error: #{e.class.name}: #{e.message}"
  puts e.backtrace.join("\n")
end