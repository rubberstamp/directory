namespace :podcast do
  desc "Import episodes directly from production_sheet.csv"
  task import_direct: :environment do
    require 'csv'
    
    puts "Directly importing episodes from production_sheet.csv..."
    
    file_path = "#{Rails.root}/data/production_sheet.csv"
    
    unless File.exist?(file_path)
      puts "File not found at #{file_path}"
      exit
    end
    
    episode_count = 0
    guest_count = 0
    
    # Read the file line by line and extract what we need
    lines = File.readlines(file_path, encoding: 'UTF-8')
    
    # Skip the header
    lines.shift
    
    lines.each_with_index do |line, index|
      begin
        # Process only non-empty lines
        next if line.strip.empty?
        
        # Simple splitting by comma (this is not robust CSV parsing)
        # But will work for basic extraction
        columns = line.split(',')
        
        # Make sure we have at least 8 columns (where video links should be)
        next if columns.size < 8
        
        # Extract episode number (column 1)
        episode_number = columns[1].strip.to_i
        next if episode_number <= 0
        
        # Extract guest name (column 2)
        guest_name = columns[2].strip
        next if guest_name.empty?
        
        # Extract video link (column 7)
        video_link = columns[7].strip
        
        # Look for YouTube video ID in the link
        if video_link.include?('drive.google.com')
          puts "Found Google Drive link for episode ##{episode_number}: #{guest_name}"
          
          # Extract video ID from Google Drive link
          # This is more complex, simplify for now by using episode number + name for unique ID
          video_id = "EP#{episode_number}_#{guest_name.gsub(/\s+/, '_')}"
        elsif video_link.include?('youtube.com') || video_link.include?('youtu.be')
          # Try to extract YouTube video ID
          if video_link.match?(/\A(https?:\/\/)/)
            video_id_match = video_link.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)&.captures&.first
            if video_id_match
              puts "Found YouTube link for episode ##{episode_number}: #{guest_name}"
              video_id = video_id_match
            else
              # Skip if we can't extract the video ID
              puts "Could not extract video ID from #{video_link} for episode ##{episode_number}"
              next
            end
          end
        else
          # Skip if no recognized video link
          puts "No recognized video link for episode ##{episode_number}: #{guest_name}"
          next
        end
        
        # Skip if no video ID
        next if video_id.blank?
        
        # Check if this episode already exists
        existing_episode = Episode.find_by(number: episode_number)
        if existing_episode
          puts "Episode ##{episode_number} already exists, updating..."
          episode = existing_episode
          
          # Update video ID if empty
          if episode.video_id.blank? && video_id.present?
            episode.update(video_id: video_id)
          end
        else
          # Create a new episode
          episode = Episode.new(
            number: episode_number,
            title: "Interview with #{guest_name}",
            video_id: video_id,
            air_date: Date.today
          )
          
          # Look for a release date in column 11
          if columns.size > 11 && columns[11].present?
            release_date = columns[11].strip
            begin
              episode.air_date = Date.parse(release_date)
            rescue
              # Keep the default date if parsing fails
            end
          end
          
          if episode.save
            puts "Created episode ##{episode.number}: #{episode.title}"
            episode_count += 1
          else
            puts "ERROR creating episode: #{episode.errors.full_messages.join(', ')}"
            next
          end
        end
        
        # Try to link guest to episode
        profile = Profile.find_by("LOWER(name) LIKE LOWER(?)", "%#{guest_name}%")
        
        if profile.nil?
          puts "Profile not found for #{guest_name}, skipping association..."
        else
          # Check if association already exists
          existing_association = ProfileEpisode.find_by(profile: profile, episode: episode)
          
          if existing_association
            puts "#{profile.name} is already linked to episode ##{episode.number}"
          else
            # Create the association
            profile_episode = ProfileEpisode.new(
              profile: profile,
              episode: episode,
              appearance_type: 'Main Guest',
              is_primary_guest: true
            )
            
            if profile_episode.save
              puts "Linked #{profile.name} to episode ##{episode.number}"
              guest_count += 1
            else
              puts "ERROR linking profile to episode: #{profile_episode.errors.full_messages.join(', ')}"
            end
          end
        end
      rescue => e
        puts "Error processing line #{index + 2}: #{e.message}"
      end
    end
    
    puts "Import completed!"
    puts "Created #{episode_count} new episodes"
    puts "Linked #{guest_count} guests to episodes"
  end
end