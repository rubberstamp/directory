namespace :youtube do
  desc "Sync episodes from the Procurement Express YouTube channel"
  task sync: :environment do
    puts "Starting YouTube channel sync..."
    channel_id = ENV['CHANNEL_ID'] || SyncYoutubeChannelJob::PROCUREMENT_CHANNEL_ID
    max_videos = (ENV['MAX_VIDEOS'] || 50).to_i
    update_existing = ENV['UPDATE_EXISTING'] != 'false'
    
    options = {
      max_videos: max_videos,
      update_existing: update_existing
    }
    
    puts "Channel ID: #{channel_id}"
    puts "Max videos: #{max_videos}"
    puts "Update existing: #{update_existing}"
    
    if ENV['ASYNC'] == 'true'
      # Run job asynchronously
      SyncYoutubeChannelJob.perform_later(channel_id, options)
      puts "Job has been enqueued. Check job status in your job monitoring system."
    else
      # Run job synchronously
      begin
        stats = SyncYoutubeChannelJob.perform_now(channel_id, options)
        puts "Job completed successfully."
        puts "Created: #{stats[:created]}, Updated: #{stats[:updated]}, Skipped: #{stats[:skipped]}, Errors: #{stats[:errors]}"
      rescue => e
        puts "Error running sync job: #{e.message}"
        puts e.backtrace.join("\n")
        exit 1
      end
    end
  end
end