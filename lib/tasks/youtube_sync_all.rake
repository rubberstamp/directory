namespace :youtube do
  desc "Sync ALL episodes from the YouTube channel in batches to handle pagination"
  task sync_all: :environment do
    puts "Starting full YouTube channel sync..."
    channel_id = ENV['CHANNEL_ID'] || SyncYoutubeChannelJob::PROCUREMENT_CHANNEL_ID
    batch_size = (ENV['BATCH_SIZE'] || 50).to_i
    update_existing = ENV['UPDATE_EXISTING'] != 'false'
    max_batches = ENV['MAX_BATCHES'] ? ENV['MAX_BATCHES'].to_i : nil
    force_full_sync = ENV['FORCE_FULL'] == 'true'
    
    # Check sync history
    sync_history = YoutubeSyncHistory.for_channel(channel_id)
    last_sync_date = sync_history.last_synced_at if !force_full_sync
    
    if last_sync_date.present? && !force_full_sync
      puts "Last sync: #{last_sync_date.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "Only fetching videos published since then."
    else
      puts "Performing full sync (no history or force mode enabled)"
    end
    
    # Get the channel to determine video count
    begin
      # Create the channel object (will use caching from Yt.configure)
      channel = Yt::Channel.new(id: channel_id)
      
      # Cache expensive operations like video_count
      total_videos = nil
      channel_title = nil
      
      # First try to get from instance variable to avoid repeated API calls
      if defined?(@channel_data) && @channel_data[:id] == channel_id
        total_videos = @channel_data[:video_count]
        channel_title = @channel_data[:title]
      end
      
      # If not cached, fetch from API
      if total_videos.nil?
        total_videos = channel.video_count
        channel_title = channel.title
        
        # Cache in instance variable
        @channel_data = {
          id: channel_id,
          title: channel_title,
          video_count: total_videos
        }
      end
      
      puts "Found channel: #{channel_title} with #{total_videos} videos"
      
      # If we have a last sync date, estimate how many videos we need to process
      # This is an approximation since we can't easily know without fetching
      if last_sync_date.present? && !force_full_sync
        # Estimate based on channel publish frequency - default assumption is 2 videos per week
        weeks_since_last_sync = ((Time.current - last_sync_date) / 1.week).ceil
        estimated_videos = [weeks_since_last_sync * 2, 10].max # At least 10 videos to account for estimation error
        total_videos = [estimated_videos, total_videos].min
        puts "Estimating #{total_videos} videos published since last sync"
      end
      
      # Calculate batches
      total_batches = (total_videos.to_f / batch_size).ceil
      total_batches = [total_batches, max_batches].min if max_batches
      
      puts "Will sync in #{total_batches} batches of #{batch_size} videos each"
      puts "Update existing episodes: #{update_existing}"
      
      # Track overall stats
      overall_stats = {
        created: 0,
        updated: 0,
        skipped: 0,
        errors: 0,
        total_processed: 0
      }
      
      # Process each batch
      (1..total_batches).each do |batch_number|
        puts "Processing batch #{batch_number} of #{total_batches}..."
        
        # Calculate publish_before for pagination - this is a workaround for YouTube API limitations
        # Since Yt doesn't directly support pagination, we use publish dates as a proxy
        publish_before = nil
        if batch_number > 1
          # IMPORTANT: Instead of asking for the oldest, track the oldest from the previous batch
          # This prevents making a new database query for each batch
          
          # For the first paginated batch, get the oldest from the first batch
          if batch_number == 2 && defined?(@last_batch_oldest_date)
            publish_before = @last_batch_oldest_date
            puts "Getting videos published before: #{publish_before.strftime('%Y-%m-%d')}"
          # For subsequent batches, use the last batch's oldest
          elsif defined?(@last_batch_oldest_date)
            publish_before = @last_batch_oldest_date
            puts "Getting videos published before: #{publish_before.strftime('%Y-%m-%d')}"
          end
        end
        
        options = {
          max_videos: batch_size,
          update_existing: update_existing,
          sync_thumbnails: true,
          publish_before: publish_before,
          force_full_sync: force_full_sync
        }
        
        # Add publish_after for incremental sync if this is the first batch
        if batch_number == 1 && last_sync_date.present? && !force_full_sync
          options[:publish_after] = last_sync_date
          puts "Getting videos published after: #{last_sync_date.strftime('%Y-%m-%d')}"
        end
        
        begin
          # Execute the batch
          batch_stats = SyncYoutubeChannelJob.perform_now(channel_id, options)
          
          # Store the oldest date from this batch for the next pagination
          if batch_stats[:total_processed] > 0 && batch_stats[:oldest_video_date]
            # Use one day before as the cut-off to avoid missing videos 
            @last_batch_oldest_date = (batch_stats[:oldest_video_date] - 1.day).to_time
            puts "Next batch will fetch videos before: #{@last_batch_oldest_date.strftime('%Y-%m-%d')}"
          end
          
          # Update overall stats
          overall_stats[:created] += batch_stats[:created]
          overall_stats[:updated] += batch_stats[:updated]
          overall_stats[:skipped] += batch_stats[:skipped]
          overall_stats[:errors] += batch_stats[:errors]
          overall_stats[:total_processed] += batch_stats[:total_processed]
          
          puts "Batch #{batch_number} completed: Created: #{batch_stats[:created]}, Updated: #{batch_stats[:updated]}, Errors: #{batch_stats[:errors]}"
          
          # If we didn't process any videos in this batch, we might be done
          if batch_stats[:total_processed] == 0
            puts "No videos processed in this batch. Likely reached the end of the channel or no new videos."
            break
          end
          
          # Sleep between batches to avoid quota issues
          if batch_number < total_batches
            wait_time = ENV['BATCH_DELAY'] ? ENV['BATCH_DELAY'].to_i : 5
            puts "Waiting #{wait_time} seconds before next batch to avoid quota issues..."
            sleep wait_time
          end
        rescue => e
          puts "Error processing batch #{batch_number}: #{e.message}"
          puts e.backtrace.join("\n")
        end
      end
      
      # Update sync history with total processed
      if overall_stats[:total_processed] > 0
        sync_history.update_after_sync(overall_stats[:total_processed])
        puts "Updated sync history for channel #{channel_id}"
      end
      
      puts "\nFull sync completed!"
      puts "Total stats:"
      puts "  Created: #{overall_stats[:created]}"
      puts "  Updated: #{overall_stats[:updated]}"
      puts "  Skipped: #{overall_stats[:skipped]}"
      puts "  Errors: #{overall_stats[:errors]}"
      puts "  Total processed: #{overall_stats[:total_processed]}"
    rescue => e
      puts "Error during full sync: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end
end