namespace :podcast do
  desc "Import episodes from the guest_list.csv with YouTube links"
  task import_from_guest_list: :environment do
    require 'csv'
    
    puts "Importing episodes from guest_list.csv..."
    
    file_path = "#{Rails.root}/data/guest_list.csv"
    
    unless File.exist?(file_path)
      puts "File not found at #{file_path}"
      exit
    end
    
    episode_count = 0
    guest_count = 0
    
    begin
      # Convert the file to use LF line endings and parse manually
      csv_text = File.read(file_path).encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      csv_text.gsub!("\r\n", "\n") # Convert CRLF to LF
      
      # Keep track of created episodes to avoid duplicates
      created_episodes = {}
      
      CSV.parse(csv_text, headers: true) do |row|
        # Skip empty rows
        next if row['Guest Name'].blank?
        
        # Get profile by name
        name = row['Guest Name']
        profile = Profile.find_by("LOWER(name) LIKE LOWER(?)", "%#{name}%")
        
        if profile.nil?
          puts "Profile not found for #{name}, skipping..."
          next
        end
        
        # Look for YouTube links in any field
        youtube_url = nil
        row.each do |field, value|
          next if value.blank?
          
          # Check if the field contains a YouTube URL
          if value.to_s.match?(/youtube\.com\/|youtu\.be\//)
            youtube_url = value
            break
          end
        end
        
        # Skip if no YouTube URL found
        if youtube_url.blank?
          puts "No YouTube URL found for #{name}, skipping..."
          next
        end
        
        # Extract video ID from URL
        video_id = nil
        if youtube_url.match?(/\A(https?:\/\/)/)
          video_id_match = youtube_url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)&.captures&.first
          if video_id_match
            video_id = video_id_match
          else
            puts "Could not extract video ID from #{youtube_url}, skipping..."
            next
          end
        else
          # Assume it's just the video ID
          video_id = youtube_url
        end
        
        # Check if an episode with this video ID already exists
        existing_episode = Episode.find_by(video_id: video_id)
        if existing_episode
          puts "Episode with video ID #{video_id} already exists, linking #{name} to episode ##{existing_episode.number}..."
          episode = existing_episode
        else
          # Generate a new episode number
          next_episode_number = Episode.maximum(:number).to_i + 1
          
          # Extract submission date for episode air date
          episode_date = nil
          if row['Timestamp'].present?
            episode_date = Date.parse(row['Timestamp'].split(' ').first) rescue Date.today
          else
            episode_date = Date.today
          end
          
          # Create episode title based on profile info
          title = "Interview with #{name}"
          if profile.company.present?
            title += " from #{profile.company}"
          end
          
          # Create the episode
          episode = Episode.new(
            number: next_episode_number,
            title: title,
            video_id: video_id,
            air_date: episode_date
          )
          
          if episode.save
            puts "Created episode ##{episode.number}: #{episode.title}"
            episode_count += 1
          else
            puts "ERROR creating episode: #{episode.errors.full_messages.join(', ')}"
            next
          end
        end
        
        # Now create the association between profile and episode
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
      
      puts "Import completed!"
      puts "Created #{episode_count} new episodes"
      puts "Linked #{guest_count} guests to episodes"
      
    rescue => e
      puts "Error importing data: #{e.message}"
      puts e.backtrace
    end
  end
  
  desc "Import episodes from production CSV with YouTube links"
  task import_from_production_sheet: :environment do
    require 'csv'
    
    puts "Importing episodes from production sheet CSV..."
    print "Enter the CSV file path: "
    file_path = STDIN.gets.chomp
    
    unless File.exist?(file_path)
      puts "File not found at #{file_path}"
      exit
    end
    
    episode_count = 0
    guest_count = 0
    
    begin
      csv_text = File.read(file_path).encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      
      # Parse header to identify columns
      headers = CSV.parse_line(csv_text.lines.first)
      
      # Look for relevant column indexes
      episode_number_idx = headers.index { |h| h =~ /episode\s*(?:#|number|num)/i }
      guest_name_idx = headers.index { |h| h =~ /guest\s*name/i }
      video_url_idx = headers.index { |h| h =~ /(?:video|youtube|url)/i }
      title_idx = headers.index { |h| h =~ /(?:title|episode\s*title)/i }
      date_idx = headers.index { |h| h =~ /(?:date|air\s*date|published)/i }
      
      puts "Found columns: "
      puts "  Episode Number: #{headers[episode_number_idx]}" if episode_number_idx
      puts "  Guest Name: #{headers[guest_name_idx]}" if guest_name_idx
      puts "  Video URL: #{headers[video_url_idx]}" if video_url_idx
      puts "  Title: #{headers[title_idx]}" if title_idx
      puts "  Date: #{headers[date_idx]}" if date_idx
      
      # Check if we have the minimum required columns
      if !video_url_idx 
        puts "ERROR: Missing video URL column in CSV"
        exit
      end
      
      if !guest_name_idx
        puts "ERROR: Missing guest name column in CSV"
        exit
      end
      
      CSV.parse(csv_text, headers: true) do |row|
        # Skip empty rows or rows without video URL
        next if row[video_url_idx].blank?
        
        # Get video ID
        video_url = row[video_url_idx]
        video_id = nil
        
        if video_url.match?(/\A(https?:\/\/)/)
          video_id_match = video_url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)&.captures&.first
          if video_id_match
            video_id = video_id_match
          else
            puts "Could not extract video ID from #{video_url}, skipping..."
            next
          end
        else
          # Assume it's just the video ID if it's 11 chars
          if video_url.length == 11
            video_id = video_url
          else
            puts "Invalid video ID format: #{video_url}, skipping..."
            next
          end
        end
        
        # Check if episode already exists with this video ID
        existing_episode = Episode.find_by(video_id: video_id)
        if existing_episode
          puts "Episode with video ID #{video_id} already exists (##{existing_episode.number}), skipping creation..."
          episode = existing_episode
        else
          # Extract episode number, or generate one
          episode_number = episode_number_idx ? row[episode_number_idx].to_i : Episode.maximum(:number).to_i + 1
          
          # Extract title
          episode_title = title_idx ? row[title_idx] : "Episode ##{episode_number}"
          
          # Extract date
          episode_date = nil
          if date_idx && row[date_idx].present?
            begin
              episode_date = Date.parse(row[date_idx])
            rescue ArgumentError
              puts "Could not parse date: #{row[date_idx]}, using today's date"
              episode_date = Date.today
            end
          else
            episode_date = Date.today
          end
          
          # Create the episode
          episode = Episode.new(
            number: episode_number,
            title: episode_title,
            video_id: video_id,
            air_date: episode_date
          )
          
          if episode.save
            puts "Created episode ##{episode.number}: #{episode.title}"
            episode_count += 1
          else
            puts "ERROR creating episode: #{episode.errors.full_messages.join(', ')}"
            next
          end
        end
        
        # Link guest to episode if guest name is provided
        if guest_name_idx && row[guest_name_idx].present?
          guest_name = row[guest_name_idx]
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
        end
      end
      
      puts "Import completed!"
      puts "Created #{episode_count} new episodes"
      puts "Linked #{guest_count} guests to episodes"
      
    rescue => e
      puts "Error importing data: #{e.message}"
      puts e.backtrace
    end
  end
  
  desc "Extract YouTube links from guest testimonials and create episodes"
  task extract_from_testimonials: :environment do
    puts "Extracting YouTube links from testimonials..."
    
    episode_count = 0
    guest_count = 0
    
    # Find profiles with testimonials
    profiles = Profile.where.not(testimonial: [nil, ''])
    
    profiles.each do |profile|
      testimonial = profile.testimonial.to_s
      
      # Look for YouTube URLs in testimonial
      if testimonial.match?(/youtube\.com\/|youtu\.be\//)
        puts "Found YouTube mention in #{profile.name}'s testimonial, checking..."
        
        # Extract all YouTube URLs
        youtube_matches = testimonial.scan(/(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S+?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/)
        
        if youtube_matches.any?
          youtube_matches.each do |match|
            video_id = match[0]
            
            # Check if this episode already exists
            existing_episode = Episode.find_by(video_id: video_id)
            
            if existing_episode
              puts "Episode with video ID #{video_id} already exists, linking #{profile.name}..."
              episode = existing_episode
            else
              # Generate episode number
              next_episode_number = Episode.maximum(:number).to_i + 1
              
              # Create episode title
              title = "Interview with #{profile.name}"
              if profile.company.present?
                title += " from #{profile.company}"
              end
              
              # Use submission date for air date if available
              episode_date = profile.submission_date || Date.today
              
              # Create the episode
              episode = Episode.new(
                number: next_episode_number,
                title: title,
                video_id: video_id,
                air_date: episode_date
              )
              
              if episode.save
                puts "Created episode ##{episode.number}: #{episode.title}"
                episode_count += 1
              else
                puts "ERROR creating episode: #{episode.errors.full_messages.join(', ')}"
                next
              end
            end
            
            # Link profile to episode if not already linked
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
        end
      end
    end
    
    puts "Extraction completed!"
    puts "Created #{episode_count} new episodes"
    puts "Linked #{guest_count} guests to episodes"
  end
end