require 'csv'

namespace :production do
  desc "Import production sheet data from CSV file"
  task import: :environment do
    file_path = ENV['FILE'] || "data/production_sheet.csv"
    
    unless File.exist?(file_path)
      puts "File not found at #{file_path}"
      puts "Usage: rails production:import FILE=path/to/file.csv"
      exit
    end
    
    puts "Importing podcast production data from #{file_path}..."
    
    created_episodes = 0
    updated_episodes = 0
    skipped_rows = 0
    errors = 0
    
    begin
      # First pass: collect all episode data
      episode_data = {}
      
      # Read the entire file at once for better handling of malformed CSV
      content = File.read(file_path, encoding: 'ISO-8859-1:UTF-8')
      
      # Clean up the content
      content = content.gsub(/\r\n(?=[^,]*,)/, ' ') # Replace newlines within fields
      
      # Split into lines
      lines = content.split(/\r?\n/)
      
      # Skip header (which spans the first two lines)
      header_text = lines[0].tr("\r\n", " ") + " " + lines[1].tr("\r\n", " ")
      data_lines = lines[2..-1]
      
      # Process data rows
      data_lines.each_with_index do |line, index|
        # Skip empty lines
        next if line.strip.empty?
        
        # Basic split by comma and clean up values
        values = line.split(',').map(&:strip)
        
        # Ensure we have enough values
        next if values.size < 8
        
        # Skip rows that don't look like data rows
        next if values[0].blank? || values[1].blank?
        
        # Extract episode number
        episode_number = values[1].to_i
        
        # Skip if no valid episode number
        if episode_number <= 0
          skipped_rows += 1
          next
        end
        
        # Extract key fields
        episode_title = values[2].to_s
        
        # Extract headshot URL if available
        headshot_url = values[5].to_s if values[5].present?
        
        # Try to get footage link
        footage_link = values[7].to_s
        video_id = extract_video_id(footage_link)
        
        # If no footage link or couldn't extract ID, try the final video column
        if video_id.blank?
          final_video = values[21].to_s if values.size > 21
          video_id = extract_video_id(final_video.to_s)
        end
        
        # Skip if still no video ID
        if video_id.blank?
          puts "Skipping row with no video ID (episode ##{episode_number}): #{episode_title}"
          skipped_rows += 1
          next
        end
        
        # Get filming date or release date
        filming_date = parse_date(values[9].to_s) || parse_date(values[11].to_s)
        
        # Get profile name for guest (from episode title if available)
        guest_name = extract_guest_name(episode_title)
        
        # Only process each episode once (first row with valid data)
        unless episode_data[episode_number]
          episode_data[episode_number] = {
            number: episode_number,
            title: episode_title,
            video_id: video_id,
            air_date: filming_date,
            guest_name: guest_name,
            headshot_url: headshot_url,
            job_title: values[6].to_s,
            production_status: values[3].to_s,
            writing_status: values[4].to_s,
            producer: values[12].to_s,
            mp3_link: values.size > 22 ? values[22].to_s : nil,
            transcript_link: values.size > 26 ? values[26].to_s : nil
          }
          
          puts "Found Episode ##{episode_number}: #{episode_title}"
        end
      end
      
      # Second pass: create or update episodes and link to profiles
      episode_data.each do |episode_number, data|
        # Find or create the episode
        episode = Episode.find_by(number: episode_number)
        
        if episode
          # Update existing episode
          episode.update(
            title: data[:title] || episode.title,
            video_id: data[:video_id] || episode.video_id,
            air_date: data[:air_date] || episode.air_date,
            notes: "Producer: #{data[:producer]}\nStatus: #{data[:production_status]}"
          )
          puts "Updated episode ##{episode_number}: #{episode.title}"
          updated_episodes += 1
        else
          # Create new episode
          episode = Episode.new(
            number: episode_number,
            title: data[:title],
            video_id: data[:video_id],
            air_date: data[:air_date] || Date.today,
            notes: "Producer: #{data[:producer]}\nStatus: #{data[:production_status]}"
          )
          
          if episode.save
            puts "Created episode ##{episode_number}: #{episode.title}"
            created_episodes += 1
          else
            puts "ERROR creating episode ##{episode_number}: #{episode.errors.full_messages.join(', ')}"
            errors += 1
            next
          end
        end
        
        # Find profile and link to episode if guest name is available
        if data[:guest_name].present?
          profile = find_profile_by_name(data[:guest_name])
          
          if profile
            # Check if profile is already linked to this episode
            unless ProfileEpisode.exists?(profile: profile, episode: episode)
              profile_episode = ProfileEpisode.new(
                profile: profile,
                episode: episode,
                appearance_type: 'Main Guest',
                is_primary_guest: true,
                notes: "Job title: #{data[:job_title]}"
              )
              
              if profile_episode.save
                puts "  Linked #{profile.name} to episode ##{episode_number}"
                
                # Update profile headshot if available and profile doesn't have one
                if data[:headshot_url].present? && profile.headshot_url.blank?
                  profile.update(headshot_url: data[:headshot_url])
                  puts "  Updated headshot for #{profile.name}"
                end
              else
                puts "  ERROR linking #{profile.name} to episode ##{episode_number}: #{profile_episode.errors.full_messages.join(', ')}"
                errors += 1
              end
            else
              puts "  #{profile.name} is already linked to episode ##{episode_number}"
            end
          else
            puts "  Guest not found: #{data[:guest_name]}"
            # Could create a new profile here if needed
          end
        end
      end
      
      puts "\nImport completed!"
      puts "Created #{created_episodes} new episodes"
      puts "Updated #{updated_episodes} existing episodes"
      puts "Skipped #{skipped_rows} rows due to missing data"
      puts "Encountered #{errors} errors"
      
    rescue StandardError => e
      puts "Error processing file: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
  
  # Helper method to extract video ID from various YouTube URL formats
  def extract_video_id(url)
    return nil if url.blank?
    
    # Check if it's already a video ID (11 characters)
    if url.match?(/^[a-zA-Z0-9_-]{11}$/)
      return url
    end
    
    # Check for youtube.com URLs
    if url.include?('youtube.com') || url.include?('youtu.be')
      match = url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)
      return match[1] if match && match[1].present?
    end
    
    # Check for Google Drive URLs with a video
    if url.include?('drive.google.com')
      # We can't extract video IDs from Drive links directly,
      # but we could download and process them if needed
      puts "  Google Drive URL detected, but can't extract YouTube video ID: #{url}"
    end
    
    nil
  end
  
  # Helper method to parse dates in various formats
  def parse_date(date_str)
    return nil if date_str.blank?
    
    begin
      # Try standard date parsing
      Date.parse(date_str.to_s)
    rescue ArgumentError
      # If that fails, try MM/DD/YYYY format
      if date_str.to_s.match?(/\d{1,2}\/\d{1,2}\/\d{4}/)
        parts = date_str.to_s.split('/')
        Date.new(parts[2].to_i, parts[0].to_i, parts[1].to_i)
      else
        nil
      end
    end
  end
  
  # Helper method to extract guest name from episode title
  def extract_guest_name(title)
    return nil if title.blank?
    
    # Many episode titles follow the format "Guest Name" or "Topic with Guest Name"
    if title.include?(" with ")
      title.split(" with ").last.strip
    else
      title.strip
    end
  end
  
  # Helper method to find a profile by name with fuzzy matching
  def find_profile_by_name(name)
    return nil if name.blank?
    
    # Try exact match first
    profile = Profile.find_by("LOWER(name) = LOWER(?)", name)
    return profile if profile
    
    # Try partial match
    profile = Profile.find_by("LOWER(name) LIKE LOWER(?)", "%#{name}%")
    return profile if profile
    
    # Try matching individual name parts
    name_parts = name.split(/\s+/)
    name_parts.each do |part|
      next if part.length < 3  # Skip short parts
      profile = Profile.find_by("LOWER(name) LIKE LOWER(?)", "%#{part}%")
      return profile if profile
    end
    
    nil
  end
  
  desc "Analyze the production sheet structure"
  task analyze: :environment do
    file_path = ENV['FILE'] || "data/production_sheet.csv"
    
    unless File.exist?(file_path)
      puts "File not found at #{file_path}"
      puts "Usage: rails production:analyze FILE=path/to/file.csv"
      exit
    end
    
    puts "Analyzing podcast production sheet structure in #{file_path}..."
    
    begin
      # Read headers and count rows
      headers = nil
      row_count = 0
      column_counts = Hash.new(0)
      sample_values = {}
      
      begin
        CSV.foreach(file_path, encoding: 'ISO-8859-1:UTF-8', liberal_parsing: true) do |row|
        row_count += 1
        
        if row_count == 1
          headers = row
          headers.each_with_index do |header, i|
            sample_values[i] = []
          end
          next
        end
        
        # Count non-empty values in each column
        row.each_with_index do |value, i|
          if value.present?
            column_counts[i] += 1
            
            # Collect sample values (up to 3 per column)
            if sample_values[i].size < 3 && value.to_s.strip.present?
              sample_values[i] << value.to_s.strip
            end
          end
        end
        end
      rescue CSV::MalformedCSVError => e
        puts "Warning: CSV parsing error: #{e.message}. Will try alternative parsing..."
        
        # Read the file directly and process line by line
        content = File.read(file_path, encoding: 'ISO-8859-1:UTF-8')
        # Replace carriage returns in the middle of fields
        content = content.gsub(/\r\n(?=[^,]*,)/, ' ')
        lines = content.split(/\r?\n/)
        row_count = lines.count
        
        # Basic header extraction
        headers = []
        header_line = lines.first
        if header_line
          headers = header_line.split(',')
          headers.each_with_index do |header, i|
            sample_values[i] = []
          end
        else
          puts "Warning: Could not read header line"
        end
        
        # Process remaining lines
        lines[1..-1].each do |line|
          values = line.split(',')
          values.each_with_index do |value, i|
            if value.present?
              column_counts[i] += 1
              
              # Collect sample values
              if sample_values[i].size < 3 && value.to_s.strip.present?
                sample_values[i] << value.to_s.strip
              end
            end
          end
        end
      end
      
      # Display analysis
      puts "\nProduction sheet contains #{row_count} rows (including header)"
      puts "\nColumn analysis:"
      puts "----------------"
      
      if headers && !headers.empty?
        headers.each_with_index do |header, i|
          next if header.blank?
          
          fill_rate = (column_counts[i].to_f / (row_count - 1) * 100).round(1)
          puts "Column #{i+1}: \"#{header}\" - #{column_counts[i]} values (#{fill_rate}% filled)"
          
          if sample_values[i] && sample_values[i].any?
            puts "  Sample values: #{sample_values[i].join(' | ')}"
          end
        end
      else
        # If no headers, just show column numbers
        column_counts.keys.sort.each do |i|
          fill_rate = (column_counts[i].to_f / (row_count - 1) * 100).round(1)
          puts "Column #{i+1}: #{column_counts[i]} values (#{fill_rate}% filled)"
          
          if sample_values[i] && sample_values[i].any?
            puts "  Sample values: #{sample_values[i].join(' | ')}"
          end
        end
      end
      
    rescue StandardError => e
      puts "Error analyzing file: #{e.message}"
    end
  end
  
  desc "Link existing episodes to profiles based on titles and guest names"
  task link_episodes_to_profiles: :environment do
    puts "Linking existing episodes to profiles based on names..."
    
    episodes_without_guests = Episode.left_outer_joins(:profile_episodes).where(profile_episodes: { id: nil })
    
    puts "Found #{episodes_without_guests.count} episodes without any linked profiles"
    
    linked_count = 0
    not_found_count = 0
    
    episodes_without_guests.each do |episode|
      puts "Processing episode ##{episode.number}: #{episode.title}"
      
      # Extract guest name from title
      guest_name = extract_guest_name(episode.title)
      
      if guest_name.blank?
        puts "  Could not extract guest name from title"
        not_found_count += 1
        next
      end
      
      # Find profile
      profile = find_profile_by_name(guest_name)
      
      if profile
        # Create the association
        profile_episode = ProfileEpisode.new(
          profile: profile,
          episode: episode,
          appearance_type: 'Main Guest',
          is_primary_guest: true
        )
        
        if profile_episode.save
          puts "  Linked #{profile.name} to episode ##{episode.number}"
          linked_count += 1
        else
          puts "  ERROR linking profile to episode: #{profile_episode.errors.full_messages.join(', ')}"
        end
      else
        puts "  No profile found matching name: #{guest_name}"
        not_found_count += 1
      end
    end
    
    puts "\nCompleted linking episodes to profiles"
    puts "Successfully linked #{linked_count} episodes"
    puts "Could not find profiles for #{not_found_count} episodes"
  end
  
  desc "Display the first few lines of the production sheet"
  task peek: :environment do
    file_path = ENV['FILE'] || "data/production_sheet.csv"
    
    unless File.exist?(file_path)
      puts "File not found at #{file_path}"
      puts "Usage: rails production:peek FILE=path/to/file.csv"
      exit
    end
    
    puts "Displaying first 10 lines of #{file_path}:"
    puts "----------------------------------------"
    
    content = File.read(file_path, encoding: 'ISO-8859-1:UTF-8')
    lines = content.split(/\r?\n/)
    
    lines.first(10).each_with_index do |line, i|
      puts "#{i+1}: #{line}"
    end
  end
end