namespace :youtube do
  desc "Fetch YouTube data for all episodes"
  task update_episodes: :environment do
    puts "Fetching YouTube data for episodes..."

    # Find all episodes with YouTube video IDs
    episodes = Episode.where.not(video_id: nil)
                     .where("video_id NOT LIKE 'EP%'")

    updated_count = 0
    skipped_count = 0
    error_count = 0

    # Process each episode with rate limiting (YouTube API has quotas)
    episodes.find_each(batch_size: 50) do |episode|
      print "Processing episode ##{episode.number} (#{episode.video_id})... "

      if episode.fetch_youtube_data
        puts "✅ Updated"
        updated_count += 1
      else
        puts "❌ Error"
        error_count += 1
      end

      # Add a small delay to avoid hitting API limits
      sleep 0.5
    end

    puts "\nCompleted YouTube data update:"
    puts "  #{updated_count} episodes updated"
    puts "  #{error_count} episodes had errors"
    puts "  #{skipped_count} episodes skipped"
  end

  desc "Fetch YouTube data for a specific episode"
  task :update_episode, [ :number ] => :environment do |t, args|
    episode_number = args[:number]

    unless episode_number
      puts "Error: Episode number is required."
      puts "Usage: rake youtube:update_episode[42]"
      exit 1
    end

    episode = Episode.find_by(number: episode_number)

    unless episode
      puts "Error: Episode ##{episode_number} not found."
      exit 1
    end

    puts "Fetching YouTube data for episode ##{episode.number} (#{episode.video_id})..."

    if episode.fetch_youtube_data
      puts "✅ Successfully updated episode ##{episode.number}"
      puts "   Title: #{episode.title}"
      puts "   Duration: #{episode.duration_formatted}"
      puts "   Thumbnail: #{episode.thumbnail_url}"
    else
      puts "❌ Failed to update episode ##{episode.number}"
    end
  end

  desc "List videos from a YouTube channel"
  task :list_channel_videos, [ :channel_id, :max_results ] => :environment do |t, args|
    channel_id = args[:channel_id] || "UCFfHVZhyEiN1QXX4s3Z_How"
    max_results = (args[:max_results] || 10).to_i

    puts "Fetching up to #{max_results} videos from channel #{channel_id}..."

    begin
      channel = Yt::Channel.new id: channel_id
      puts "Channel: #{channel.title} (#{channel.video_count} videos)"
      puts "Description: #{channel.description.split("\n").first}" if channel.description.present?
      puts "\nLatest videos:"

      videos = channel.videos.take(max_results)
      videos.each_with_index do |video, index|
        published = video.published_at.strftime("%Y-%m-%d")
        puts "#{index + 1}. [#{published}] #{video.title}"
        puts "   ID: #{video.id}"
        puts "   Views: #{video.view_count}"
        puts "   Duration: #{format_duration(video.duration)}"
        puts "   URL: https://www.youtube.com/watch?v=#{video.id}"
        puts ""
      end

      puts "Found #{videos.size} videos."
    rescue => e
      puts "❌ Error fetching channel videos: #{e.message}"
      puts e.backtrace.first(5).join("\n") if e.backtrace
    end
  end

  # Helper method to format seconds to HH:MM:SS
  def self.format_duration(seconds)
    return "00:00" unless seconds

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    seconds = seconds % 60

    if hours > 0
      "%d:%02d:%02d" % [ hours, minutes, seconds ]
    else
      "%d:%02d" % [ minutes, seconds ]
    end
  end

  desc "Test fetching a specific YouTube video"
  task :test_video, [ :video_id ] => :environment do |t, args|
    video_id = args[:video_id] || "dQw4w9WgXcQ" # Default to a well-known video ID

    puts "Fetching YouTube video with ID: #{video_id}..."

    begin
      # Try to fetch the video
      video = Yt::Video.new id: video_id

      # Print video details
      puts "✅ Successfully fetched video:"
      puts "Title: #{video.title}"
      puts "Channel: #{video.channel_title}"
      puts "Published: #{video.published_at.strftime('%Y-%m-%d')}"
      puts "Duration: #{self.format_duration(video.duration)}"
      puts "Description (excerpt): #{video.description.split("\n").first}"
      puts "URL: https://www.youtube.com/watch?v=#{video.id}"
      puts "Embed URL: https://www.youtube.com/embed/#{video.id}"

      # Print thumbnail URLs
      puts "\nThumbnail URLs:"
      [ :default, :medium, :high, :standard, :maxres ].each do |size|
        url = video.thumbnail_url(size)
        puts "- #{size}: #{url}" if url
      end

      # Try to get some statistics
      puts "\nStatistics:"
      puts "View count: #{video.view_count}"
      puts "Like count: #{video.like_count}" if video.respond_to?(:like_count)
      puts "Comment count: #{video.comment_count}" if video.respond_to?(:comment_count)

    rescue => e
      puts "❌ Error fetching video: #{e.message}"
      puts e.backtrace.first(5).join("\n") if e.backtrace
    end
  end
end
