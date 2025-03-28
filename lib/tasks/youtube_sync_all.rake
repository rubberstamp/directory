namespace :youtube do
  desc "Sync ALL episodes from the YouTube channel in batches to handle pagination"
  task sync_all: :environment do
    puts "Starting full YouTube channel sync..."
    channel_id = ENV['CHANNEL_ID'] || SyncYoutubeChannelJob::PROCUREMENT_CHANNEL_ID
    batch_size = (ENV['BATCH_SIZE'] || 50).to_i
    update_existing = ENV['UPDATE_EXISTING'] != 'false'
    max_batches = ENV['MAX_BATCHES'] ? ENV['MAX_BATCHES'].to_i : nil
    
    # Get the channel to determine video count
    begin
      channel = Yt::Channel.new(id: channel_id)
      total_videos = channel.video_count
      puts "Found channel: #{channel.title} with #{total_videos} videos"
      
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
          # Get the oldest video from previous batches
          oldest_processed_video_date = Episode.where.not(air_date: nil).order(air_date: :desc).limit((batch_number-1) * batch_size).last&.air_date
          
          if oldest_processed_video_date
            # Use one day after as the cut-off to avoid missing videos
            publish_before = (oldest_processed_video_date + 1.day).to_time
            puts "Getting videos published before: #{publish_before.strftime('%Y-%m-%d')}"
          end
        end
        
        options = {
          max_videos: batch_size,
          update_existing: update_existing,
          sync_thumbnails: true,
          publish_before: publish_before
        }
        
        begin
          # Execute the batch
          batch_stats = SyncYoutubeChannelJob.perform_now(channel_id, options)
          
          # Update overall stats
          overall_stats[:created] += batch_stats[:created]
          overall_stats[:updated] += batch_stats[:updated]
          overall_stats[:skipped] += batch_stats[:skipped]
          overall_stats[:errors] += batch_stats[:errors]
          overall_stats[:total_processed] += batch_stats[:total_processed]
          
          puts "Batch #{batch_number} completed: Created: #{batch_stats[:created]}, Updated: #{batch_stats[:updated]}, Errors: #{batch_stats[:errors]}"
          
          # If we didn't process any videos in this batch, we might be done
          if batch_stats[:total_processed] == 0
            puts "No videos processed in this batch. Likely reached the end of the channel."
            break
          end
          
          # Sleep between batches to avoid quota issues (optional)
          if batch_number < total_batches
            puts "Waiting 5 seconds before next batch to avoid quota issues..."
            sleep 5
          end
        rescue => e
          puts "Error processing batch #{batch_number}: #{e.message}"
          puts e.backtrace.join("\n")
        end
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