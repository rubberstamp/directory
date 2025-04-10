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

      Rails.logger.info "Found #{videos.count} videos to potentially process. Fetching details in bulk."

      # Extract video IDs for bulk fetching
      video_ids = videos.map(&:id)

      if video_ids.any?
        # Fetch details for all videos in one API call
        # Requesting snippet (title, description, publishedAt, thumbnails) and contentDetails (duration)
        begin
          bulk_videos_collection = Yt::Collections::Videos.new
          detailed_videos = bulk_videos_collection.where(id: video_ids.join(","), part: "snippet,contentDetails")
          Rails.logger.info "Fetched details for #{detailed_videos.count} videos via bulk API call."

          # Process videos using the detailed data
          detailed_videos.each do |detailed_video|
            stats[:total_processed] += 1

            # Track the oldest video date for pagination (using the detailed video object)
            if detailed_video.published_at
              if stats[:oldest_video_date].nil? || detailed_video.published_at < stats[:oldest_video_date]
                stats[:oldest_video_date] = detailed_video.published_at
              end
            end

            begin
              # Check if the episode already exists
              existing_episode = Episode.find_by(video_id: detailed_video.id)

              if existing_episode && options[:update_existing]
                # Update existing episode using detailed data
                update_episode_from_youtube(existing_episode, detailed_video, options)
                stats[:updated] += 1
                Rails.logger.info "Updated episode ##{existing_episode.number}: #{existing_episode.title}"
              elsif existing_episode
                # Skip existing episodes if update_existing is false
                stats[:skipped] += 1
                Rails.logger.info "Skipped existing episode ##{existing_episode.number}: #{existing_episode.title}"
              else
                # Create new episode using detailed data
                create_episode_from_youtube(detailed_video, options) # Pass options for consistency
                stats[:created] += 1
                Rails.logger.info "Created new episode from video: #{detailed_video.title}"
              end
            rescue => e
              stats[:errors] += 1
              Rails.logger.error "Error processing video #{detailed_video.id}: #{e.message}"
              Rails.logger.error e.backtrace.join("\n") # Add backtrace for debugging
            end
          end # end detailed_videos.each

        rescue Yt::Errors::RequestError => e
          stats[:errors] += video_ids.count # Assume all failed if the bulk request fails
          Rails.logger.error "YouTube API Error during bulk fetch: #{e.message}"
          # Potentially re-raise or handle specific errors (like quota exceeded)
          raise e # Re-raise for standard job retry mechanisms
        rescue => e
          stats[:errors] += video_ids.count # Assume all failed
          Rails.logger.error "Generic Error during bulk fetch or processing: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          raise e # Re-raise
        end
      else
         Rails.logger.info "No video IDs found to process after filtering."
      end

      # Log summary
      Rails.logger.info "YouTube sync completed. Stats: #{stats.inspect}"

      # Update sync history
      if stats[:total_processed] > 0
        sync_history.update_after_sync(stats[:total_processed])
        Rails.logger.info "Updated sync history for channel #{channel_id}"
      end

      stats
    rescue => e
      Rails.logger.error "Error syncing YouTube channel: #{e.message}"
      raise e
    end
  end
  private

  # Update an existing episode with YouTube data (now expects a detailed Yt::Video object)
  def update_episode_from_youtube(episode, detailed_video, options = {})
    # Access properties directly from the detailed_video object
    # Assumes 'snippet' and 'contentDetails' were fetched
    episode.title = detailed_video.title
    episode.duration_seconds = detailed_video.duration # duration is in seconds
    episode.notes = detailed_video.description if episode.notes.blank?

    # Set thumbnail if enabled
    # Access thumbnail_url directly - :high might still be preferred if available
    if options[:sync_thumbnails] && detailed_video.respond_to?(:thumbnail_url)
       begin
         # Prefer high quality, fallback gracefully if method/size isn't available
         episode.thumbnail_url = detailed_video.thumbnail_url(:high)
       rescue NoMethodError, ArgumentError
         # Fallback to default or medium if high isn't available or causes error
         episode.thumbnail_url = detailed_video.thumbnail_url rescue nil
       end
    end

    # Set air date if not already set
    if episode.air_date.blank? && detailed_video.published_at
      episode.air_date = detailed_video.published_at.to_date
    end

    # Save only if changes were made
    episode.save! if episode.changed?
  end

  # Create a new episode from YouTube data (now expects a detailed Yt::Video object)
  def create_episode_from_youtube(detailed_video, options = {})
    # Access properties directly from the detailed_video object
    # Assumes 'snippet' and 'contentDetails' were fetched

    # Try to determine episode number from the title
    number = extract_episode_number(detailed_video.title)

    # If we can't determine the number, use the highest existing number + 1
    if number.nil?
      max_number = Episode.maximum(:number) || 0
      number = max_number + 1
    end

    # Prepare thumbnail URL
    thumbnail_url_to_save = nil
    if options[:sync_thumbnails] && detailed_video.respond_to?(:thumbnail_url)
       begin
         thumbnail_url_to_save = detailed_video.thumbnail_url(:high)
       rescue NoMethodError, ArgumentError
         thumbnail_url_to_save = detailed_video.thumbnail_url rescue nil
       end
    end

    # Create the episode
    Episode.create!(
      video_id: detailed_video.id,
      title: detailed_video.title,
      number: number,
      air_date: detailed_video.published_at&.to_date,
      duration_seconds: detailed_video.duration, # duration is in seconds
      notes: detailed_video.description,
      thumbnail_url: thumbnail_url_to_save
    )
  end

  # Try to extract episode number from the title (no changes needed here)
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
