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
        total_processed: 0
      }
      
      # Get the channel
      channel = Yt::Channel.new(id: channel_id)
      Rails.logger.info "Found channel: #{channel.title} with #{channel.video_count} videos"
      
      # Get videos from the channel (most recent first)
      # If publish_before is set, use it for pagination
      if options[:publish_before]
        videos = channel.videos.where(published_before: options[:publish_before]).take(options[:max_videos])
      else
        videos = channel.videos.take(options[:max_videos])
      end
      
      videos.each do |youtube_video|
        stats[:total_processed] += 1
        
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
      return stats
    rescue => e
      Rails.logger.error "Error syncing YouTube channel: #{e.message}"
      raise e
    end
  end
  
  private
  
  # Update an existing episode with YouTube data
  def update_episode_from_youtube(episode, youtube_video, options = {})
    episode.title = youtube_video.title
    episode.duration_seconds = youtube_video.duration
    episode.notes = youtube_video.description if episode.notes.blank?
    
    # Set thumbnail if enabled
    if options[:sync_thumbnails]
      episode.thumbnail_url = youtube_video.thumbnail_url(:high)
    end
    
    # Set air date if not already set
    if episode.air_date.blank? && youtube_video.published_at
      episode.air_date = youtube_video.published_at.to_date
    end
    
    episode.save!
  end
  
  # Create a new episode from YouTube data
  def create_episode_from_youtube(youtube_video)
    # Try to determine episode number from the title
    number = extract_episode_number(youtube_video.title)
    
    # If we can't determine the number, use the highest existing number + 1
    if number.nil?
      max_number = Episode.maximum(:number) || 0
      number = max_number + 1
    end
    
    # Create the episode
    Episode.create!(
      video_id: youtube_video.id,
      title: youtube_video.title,
      number: number,
      air_date: youtube_video.published_at&.to_date,
      duration_seconds: youtube_video.duration,
      notes: youtube_video.description,
      thumbnail_url: youtube_video.thumbnail_url(:high)
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