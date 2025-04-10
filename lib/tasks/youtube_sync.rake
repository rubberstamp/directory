namespace :youtube do
  desc "Sync episodes from the Procurement Express YouTube channel"
  task sync: :environment do
    puts "Starting YouTube channel sync..."
    channel_id = ENV["CHANNEL_ID"] || SyncYoutubeChannelJob::PROCUREMENT_CHANNEL_ID
    max_videos = (ENV["MAX_VIDEOS"] || 50).to_i
    update_existing = ENV["UPDATE_EXISTING"] != "false"
    force_full_sync = ENV["FORCE_FULL"] == "true"

    options = {
      max_videos: max_videos,
      update_existing: update_existing,
      force_full_sync: force_full_sync
    }

    puts "Channel ID: #{channel_id}"
    puts "Max videos: #{max_videos}"
    puts "Update existing: #{update_existing}"
    puts "Force full sync: #{force_full_sync}"

    # Get sync history
    sync_history = YoutubeSyncHistory.for_channel(channel_id)
    if sync_history.last_synced_at.present? && !force_full_sync
      puts "Last sync: #{sync_history.last_synced_at.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "Only videos published since then will be processed."
    else
      puts "Performing full sync (no history or force mode enabled)"
    end

    if ENV["ASYNC"] == "true"
      # Run job asynchronously
      SyncYoutubeChannelJob.perform_later(channel_id, options)
      puts "Job has been enqueued. Check job status in your job monitoring system."
    else
      # Run job synchronously
      begin
        stats = SyncYoutubeChannelJob.perform_now(channel_id, options)
        puts "Job completed successfully."
        puts "Created: #{stats[:created]}, Updated: #{stats[:updated]}, Skipped: #{stats[:skipped]}, Errors: #{stats[:errors]}"
        puts "Total processed: #{stats[:total_processed]}"

        if stats[:total_processed] == 0
          puts "No new videos found since last sync at #{sync_history.last_synced_at}"
        end
      rescue => e
        puts "Error running sync job: #{e.message}"
        puts e.backtrace.join("\n")
        exit 1
      end
    end
  end
end
