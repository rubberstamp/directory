namespace :podcast do
  desc "Migrate data from old episode fields to new Episode model"
  task migrate_episode_data: :environment do
    puts "Starting to migrate episode data from Profile to Episode model..."

    # Keep track of created episodes to avoid duplicates
    created_episodes = {}

    # Get all profiles with episode data
    profiles_with_episodes = Profile.where.not(deprecated_episode_url: nil)

    if profiles_with_episodes.empty?
      puts "No profiles found with deprecated episode data."
      exit
    end

    puts "Found #{profiles_with_episodes.count} profiles with episode data to migrate."

    profiles_with_episodes.each do |profile|
      puts "Processing #{profile.name}..."

      # Check if this episode already exists
      video_id = profile.deprecated_episode_url

      if created_episodes[video_id]
        # Episode already exists, just create the association
        episode = created_episodes[video_id]
        puts "  Using existing episode ##{episode.number}: #{episode.title}"
      else
        # Create a new episode
        episode = Episode.new(
          number: profile.deprecated_episode_number,
          title: profile.deprecated_episode_title,
          video_id: video_id,
          air_date: profile.deprecated_episode_date
        )

        if episode.save
          puts "  Created episode ##{episode.number}: #{episode.title}"
          created_episodes[video_id] = episode
        else
          puts "  ERROR creating episode: #{episode.errors.full_messages.join(', ')}"
          next
        end
      end

      # Create the ProfileEpisode association
      profile_episode = ProfileEpisode.new(
        profile: profile,
        episode: episode,
        appearance_type: "Main Guest",
        is_primary_guest: true
      )

      if profile_episode.save
        puts "  Linked #{profile.name} to episode ##{episode.number}"
      else
        puts "  ERROR linking profile to episode: #{profile_episode.errors.full_messages.join(', ')}"
      end
    end

    puts "Finished migrating episode data. Created #{created_episodes.size} episodes."
  end

  desc "Create a new episode with multiple guests"
  task create_episode: :environment do
    puts "Creating a new podcast episode with multiple guests..."

    print "Episode number: "
    episode_number = STDIN.gets.chomp.to_i

    print "Episode title: "
    episode_title = STDIN.gets.chomp

    print "Video ID or full YouTube URL: "
    video_id = STDIN.gets.chomp

    print "Episode date (YYYY-MM-DD): "
    episode_date_str = STDIN.gets.chomp

    begin
      episode_date = Date.parse(episode_date_str)
    rescue ArgumentError
      puts "Invalid date format. Please use YYYY-MM-DD."
      exit
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
    else
      puts "ERROR creating episode: #{episode.errors.full_messages.join(', ')}"
      exit
    end

    # Add guests
    puts "\nNow let's add guests to this episode."
    puts "Enter 'done' for guest name when finished."

    loop do
      print "\nGuest name (or 'done' to finish): "
      guest_name = STDIN.gets.chomp
      break if guest_name.downcase == "done"

      profile = Profile.find_by("LOWER(name) LIKE LOWER(?)", "%#{guest_name}%")

      if profile.nil?
        puts "Guest not found. Please check the spelling."
        next
      end

      print "Is this the primary guest? (y/n): "
      is_primary = STDIN.gets.chomp.downcase == "y"

      print "Appearance type (Main Guest, Co-Host, Panel Member, etc.): "
      appearance_type = STDIN.gets.chomp

      print "Any segment notes? (optional): "
      notes = STDIN.gets.chomp

      # Ask for segment timestamps if applicable
      segment_start_time = nil
      segment_end_time = nil

      print "Does this guest appear in a specific segment? (y/n): "
      has_segment = STDIN.gets.chomp.downcase == "y"

      if has_segment
        print "Segment title (optional): "
        segment_title = STDIN.gets.chomp

        print "Segment start time in seconds: "
        segment_start_time = STDIN.gets.chomp.to_i

        print "Segment end time in seconds (optional): "
        segment_end_time_str = STDIN.gets.chomp
        segment_end_time = segment_end_time_str.empty? ? nil : segment_end_time_str.to_i
      end

      # Create the association
      profile_episode = ProfileEpisode.new(
        profile: profile,
        episode: episode,
        appearance_type: appearance_type,
        notes: notes,
        is_primary_guest: is_primary,
        segment_title: segment_title,
        segment_start_time: segment_start_time,
        segment_end_time: segment_end_time
      )

      if profile_episode.save
        puts "Added #{profile.name} as #{appearance_type} to episode ##{episode.number}"
      else
        puts "ERROR adding guest to episode: #{profile_episode.errors.full_messages.join(', ')}"
      end
    end

    puts "Episode ##{episode.number} created successfully with #{episode.profiles.count} guests."
  end

  desc "Import episodes and guests from a CSV file"
  task import_episodes_from_csv: :environment do
    require "csv"

    puts "Importing episodes from CSV..."
    print "Enter the CSV file path: "
    file_path = STDIN.gets.chomp

    unless File.exist?(file_path)
      puts "File not found at #{file_path}"
      exit
    end

    # Keep track of created episodes to avoid duplicates
    created_episodes = {}

    begin
      CSV.foreach(file_path, headers: true) do |row|
        episode_number = row["Episode Number"].to_i
        episode_title = row["Episode Title"]
        video_id = row["Video ID"]
        episode_date = row["Episode Date"]
        guest_name = row["Guest Name"]
        appearance_type = row["Appearance Type"] || "Main Guest"
        is_primary = (row["Is Primary Guest"] || "yes").downcase == "yes"
        segment_title = row["Segment Title"]
        segment_start = row["Segment Start Time"]&.to_i
        segment_end = row["Segment End Time"]&.to_i
        notes = row["Notes"]

        # Find or create the episode
        episode = created_episodes[episode_number] || Episode.find_by(number: episode_number)

        if episode.nil?
          episode = Episode.new(
            number: episode_number,
            title: episode_title,
            video_id: video_id,
            air_date: Date.parse(episode_date)
          )

          if episode.save
            puts "Created episode ##{episode.number}: #{episode.title}"
            created_episodes[episode_number] = episode
          else
            puts "ERROR creating episode ##{episode_number}: #{episode.errors.full_messages.join(', ')}"
            next
          end
        end

        # Find the profile
        profile = Profile.find_by("LOWER(name) LIKE LOWER(?)", "%#{guest_name}%")

        if profile.nil?
          puts "Guest not found: #{guest_name}"
          next
        end

        # Create the association if it doesn't exist
        profile_episode = ProfileEpisode.find_by(profile: profile, episode: episode)

        if profile_episode
          puts "#{profile.name} is already linked to episode ##{episode.number}"
          next
        end

        profile_episode = ProfileEpisode.new(
          profile: profile,
          episode: episode,
          appearance_type: appearance_type,
          is_primary_guest: is_primary,
          segment_title: segment_title,
          segment_start_time: segment_start,
          segment_end_time: segment_end,
          notes: notes
        )

        if profile_episode.save
          puts "Linked #{profile.name} to episode ##{episode.number}"
        else
          puts "ERROR linking #{profile.name} to episode ##{episode.number}: #{profile_episode.errors.full_messages.join(', ')}"
        end
      end

      puts "Successfully imported episodes and guests!"
    rescue StandardError => e
      puts "Error importing data: #{e.message}"
    end
  end

  desc "Generate a CSV template for importing episodes with multiple guests"
  task generate_episodes_template: :environment do
    require "csv"

    template_path = "podcast_episodes_multi_template.csv"
    headers = [
      "Episode Number",
      "Episode Title",
      "Video ID",
      "Episode Date",
      "Guest Name",
      "Appearance Type",
      "Is Primary Guest",
      "Segment Title",
      "Segment Start Time",
      "Segment End Time",
      "Notes"
    ]

    CSV.open(template_path, "w") do |csv|
      csv << headers

      # Add a few example rows
      csv << [ "42", "How to Optimize Procurement", "abcd1234xyz", "2025-01-15", "John Doe", "Main Guest", "yes", nil, nil, nil, nil ]
      csv << [ "42", "How to Optimize Procurement", "abcd1234xyz", "2025-01-15", "Jane Smith", "Co-Host", "no", "Finance segment", "1800", "2400", "Second half of the show" ]
      csv << [ "43", "Procurement Panel Discussion", "efgh5678abc", "2025-01-22", "Alice Johnson", "Panel Member", "yes", nil, nil, nil, "Moderated the panel" ]
      csv << [ "43", "Procurement Panel Discussion", "efgh5678abc", "2025-01-22", "Bob Williams", "Panel Member", "no", nil, nil, nil, nil ]
      csv << [ "43", "Procurement Panel Discussion", "efgh5678abc", "2025-01-22", "Carol Davis", "Panel Member", "no", nil, nil, nil, nil ]
    end

    puts "Template generated at #{template_path}"
    puts "Format for Episode Date: YYYY-MM-DD"
    puts "Video ID should be the YouTube video ID (11 characters) or full URL"
    puts "Appearance Type examples: Main Guest, Co-Host, Panel Member, Special Guest, Expert Commentary, Interview Subject"
    puts "Is Primary Guest: yes or no"
    puts "Segment times should be in seconds"
  end

  desc "Create sample episodes with multiple guests"
  task create_sample_episodes: :environment do
    puts "Creating sample episodes with multiple guests..."

    # Sample episodes data
    episodes_data = [
      {
        number: 201,
        title: "Procurement Strategy for Growing Businesses",
        video_id: "yK5Y4zYZ8N4",
        air_date: "2025-01-10",
        guests: [
          { name: "Pat Kane", type: "Main Guest", primary: true },
          { name: "Dr. Jens Wilhelm Meyer", type: "Expert Commentary", primary: false, segment_start: 1500, segment_title: "Supply Chain Segment" }
        ]
      },
      {
        number: 202,
        title: "Finance Panel: Future of Procurement",
        video_id: "MQgX9mSzPsw",
        air_date: "2025-01-17",
        guests: [
          { name: "Jens Sonnenborg", type: "Panel Member", primary: true },
          { name: "Bridget Harris", type: "Panel Member", primary: false },
          { name: "Michael Stier", type: "Panel Member", primary: false }
        ]
      },
      {
        number: 203,
        title: "International Procurement Strategies",
        video_id: "tL39NrTe3H8",
        air_date: "2025-01-24",
        guests: [
          { name: "James Bennett", type: "Main Guest", primary: true },
          { name: "Louw Barnardt", type: "Co-Host", primary: false }
        ]
      }
    ]

    episodes_data.each do |episode_data|
      # Create episode
      episode = Episode.new(
        number: episode_data[:number],
        title: episode_data[:title],
        video_id: episode_data[:video_id],
        air_date: Date.parse(episode_data[:air_date])
      )

      if episode.save
        puts "Created episode ##{episode.number}: #{episode.title}"

        # Add guests
        episode_data[:guests].each do |guest_data|
          profile = Profile.find_by("LOWER(name) LIKE LOWER(?)", "%#{guest_data[:name]}%")

          if profile.nil?
            puts "  Guest not found: #{guest_data[:name]}"
            next
          end

          profile_episode = ProfileEpisode.new(
            profile: profile,
            episode: episode,
            appearance_type: guest_data[:type],
            is_primary_guest: guest_data[:primary],
            segment_title: guest_data[:segment_title],
            segment_start_time: guest_data[:segment_start],
            segment_end_time: guest_data[:segment_end]
          )

          if profile_episode.save
            puts "  Added #{profile.name} as #{guest_data[:type]} to episode ##{episode.number}"
          else
            puts "  ERROR adding guest to episode: #{profile_episode.errors.full_messages.join(', ')}"
          end
        end
      else
        puts "ERROR creating episode: #{episode.errors.full_messages.join(', ')}"
      end
    end

    puts "Created #{episodes_data.size} sample episodes with multiple guests."
  end
end
