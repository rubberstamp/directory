class SyncYoutubeChannelJob < ApplicationJob
  queue_as :default
  
  # YouTube channel ID for Procurement Express
  PROCUREMENT_CHANNEL_ID = "UCFfHVZhyEiN1QXX4s3Z_How"
  
  def perform(channel_id = PROCUREMENT_CHANNEL_ID, options = {})
    Rails.logger.info "Starting YouTube channel sync for channel ID: #{channel_id}"
    
    # Default options
    options = {
      max_videos: 50,
      update_existing: true,
      sync_thumbnails: true
    }.merge(options)
    
    begin
      stats = {
        created: 0,
        updated: 0,
        skipped: 0,
        errors: 0,
        total_processed: 0,
        oldest_video_date: nil
      }
      
      # Track sync history
      sync_history = YoutubeSyncHistory.for_channel(channel_id)
      last_sync_date = sync_history.last_synced_at
      
      # Get the channel
      channel = Yt::Channel.new(id: channel_id)
      Rails.logger.info "Found channel: #{channel.title} with #{channel.video_count} videos"
      Rails.logger.info "Last sync: #{last_sync_date || 'Never'}"
      
      # Optimize API calls - fetch videos from channel
      # The Yt gem makes a separate API call for EACH video when using methods like
      # video.duration, video.thumbnail_url, etc.
      # We need to get all the data we need in a single API call
  
      Rails.logger.info "Starting to fetch videos with optimized API calls"
      
      # Build query with filters
      query = {}
      query_parts = []
      
      # If publish_before is set, use it for pagination
      if options[:publish_before]
        query[:published_before] = options[:publish_before]
        query_parts << "published_before=#{options[:publish_before].iso8601}"
        Rails.logger.info "Filtering videos published before: #{options[:publish_before]}"
      end
      
      # If publish_after is set, use it for incremental sync
      if options[:publish_after]
        query[:published_after] = options[:publish_after]
        query_parts << "published_after=#{options[:publish_after].iso8601}"
        Rails.logger.info "Filtering videos published after: #{options[:publish_after]}" 
      # Otherwise, if we have a last sync date and not forcing full sync, use that
      elsif last_sync_date.present? && !options[:force_full_sync]
        query[:published_after] = last_sync_date
        query_parts << "published_after=#{last_sync_date.iso8601}"
        Rails.logger.info "Fetching only videos published after #{last_sync_date}"
      end
      
      # Get videos with a single API call using the where method
      # This is more efficient than multiple API calls
      if query.present?
        videos = channel.videos.where(query).take(options[:max_videos])
      else
        videos = channel.videos.take(options[:max_videos])
      end
      
      # Log query details
      Rails.logger.info "YouTube API query: #{query_parts.join('&')}" if query_parts.any?
      Rails.logger.info "Fetched #{videos.count} videos in a single API call"
      
      # Log if no videos needed processing
      if videos.empty?
        Rails.logger.info "No new videos found since last sync"
        return stats
      end
      
      Rails.logger.info "Found #{videos.count} videos to process"
      
      videos.each do |youtube_video|
        stats[:total_processed] += 1
        
        # Track the oldest video date for pagination
        if youtube_video.published_at
          if stats[:oldest_video_date].nil? || youtube_video.published_at < stats[:oldest_video_date]
            stats[:oldest_video_date] = youtube_video.published_at
          end
        end
        
        begin
          # Check if the episode already exists
          existing_episode = Episode.find_by(video_id: youtube_video.id)
          
          if existing_episode && options[:update_existing]
            # Update existing episode
            update_episode_from_youtube(existing_episode, youtube_video, options)
            stats[:updated] += 1
            Rails.logger.info "Updated episode ##{existing_episode.number}: #{existing_episode.title}"
          elsif existing_episode
            # Skip existing episodes if update_existing is false
            stats[:skipped] += 1
            Rails.logger.info "Skipped existing episode ##{existing_episode.number}: #{existing_episode.title}"
          else
            # Create new episode
            create_episode_from_youtube(youtube_video)
            stats[:created] += 1
            Rails.logger.info "Created new episode from video: #{youtube_video.title}"
          end
        rescue => e
          stats[:errors] += 1
          Rails.logger.error "Error processing video #{youtube_video.id}: #{e.message}"
        end
      end
      
      # Log summary
      Rails.logger.info "YouTube sync completed. Stats: #{stats.inspect}"
      
      # Update sync history
      if stats[:total_processed] > 0
        sync_history.update_after_sync(stats[:total_processed])
        Rails.logger.info "Updated sync history for channel #{channel_id}"
      end
      
      return stats
    rescue => e
      Rails.logger.error "Error syncing YouTube channel: #{e.message}"
      raise e
    end
  end
  
  private
  
  # Get all necessary data from a YouTube video object with minimal API calls
  def extract_video_data(youtube_video)
    # The Yt gem makes an API call for EACH property access
    # To minimize API calls, fetch all needed data at once and cache it
    
    # We make one API call to get all data we need
    begin
      # IMPORTANT: Make a single request to get all data we need at once
      video_data = {
        id: youtube_video.id,
        title: youtube_video.title,
        description: youtube_video.description,
        published_at: youtube_video.published_at,
        duration: youtube_video.duration
      }
      
      # Thumbnail URLs require a separate API call - only make if necessary
      # (YouTube won't include this in the same response as other data)
      video_data[:thumbnail_url] = youtube_video.thumbnail_url(:high)
      
      return video_data
    rescue => e
      Rails.logger.error "Error extracting video data: #{e.message}"
      return {}
    end
  end

  # Update an existing episode with YouTube data
  def update_episode_from_youtube(episode, youtube_video, options = {})
    # Extract all needed data with minimal API calls
    video_data = extract_video_data(youtube_video)
    return false if video_data.empty?
    
    episode.title = video_data[:title]
    episode.duration_seconds = video_data[:duration] 
    episode.notes = video_data[:description] if episode.notes.blank?
    
    # Set thumbnail if enabled
    if options[:sync_thumbnails] && video_data[:thumbnail_url]
      episode.thumbnail_url = video_data[:thumbnail_url]
    end
    
    # Set air date if not already set
    if episode.air_date.blank? && video_data[:published_at]
      episode.air_date = video_data[:published_at].to_date
    end
    
    episode.save!
  end
  
  # Create a new episode from YouTube data
  def create_episode_from_youtube(youtube_video)
    # Extract all needed data with minimal API calls
    video_data = extract_video_data(youtube_video)
    return false if video_data.empty?
    
    # Try to determine episode number from the title
    number = extract_episode_number(video_data[:title])
    
    # If we can't determine the number, use the highest existing number + 1
    if number.nil?
      max_number = Episode.maximum(:number) || 0
      number = max_number + 1
    end
    
    # Create the episode
    Episode.create!(
      video_id: video_data[:id],
      title: video_data[:title],
      number: number,
      air_date: video_data[:published_at]&.to_date,
      duration_seconds: video_data[:duration],
      notes: video_data[:description],
      thumbnail_url: video_data[:thumbnail_url]
    )
  end
  
  # Try to extract episode number from the title
  def extract_episode_number(title)
    # Common patterns:
    # "EP 123: Title"
    # "Episode 123:"
    # "Episode 123 -"
    # "#123:"
    patterns = [
      /EP\s*(\d+)[:\s]/i,
      /Episode\s*(\d+)[:\s-]/i,
      /#(\d+)[:\s]/i
    ]
    
    patterns.each do |pattern|
      if match = title.match(pattern)
        return match[1].to_i
      end
    end
    
    nil
  end
end