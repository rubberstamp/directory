namespace :episodes do
  desc "Associate profiles to episodes if the episode title contains the profile name"
  task associate_profiles_by_title: :environment do
    puts "Starting task: Associate profiles to episodes by title..."

    # Fetch all profiles (id and name) efficiently
    # Lowercase names immediately for case-insensitive comparison
    profiles_data = Profile.pluck(:id, :name).map do |id, name|
      { id: id, name: name, lower_name: name.downcase }
    end
    puts "Loaded #{profiles_data.count} profiles."

    associated_count = 0
    skipped_count = 0
    error_count = 0

    # Iterate through each episode
    Episode.find_each do |episode|
      puts "Processing Episode ##{episode.number}: #{episode.title}"
      episode_title_lower = episode.title.downcase

      # Get IDs of profiles already associated with this episode
      existing_profile_ids = episode.profile_ids.to_set

      # Check against each profile
      profiles_data.each do |profile_data|
        # Check if the profile name is present in the episode title (case-insensitive)
        # Ensure the name is not blank to avoid matching empty strings
        if profile_data[:lower_name].present? && episode_title_lower.include?(profile_data[:lower_name])
          # Check if this profile is already associated
          if existing_profile_ids.include?(profile_data[:id])
            # puts "  - Skipping profile '#{profile_data[:name]}' (already associated)"
            skipped_count += 1
          else
            # Associate the profile with the episode
            begin
              # Using create! to raise an error on failure
              episode.profile_episodes.create!(profile_id: profile_data[:id])
              puts "  + Associated profile '#{profile_data[:name]}' (ID: #{profile_data[:id]})"
              associated_count += 1
              # Add the newly associated ID to the set to avoid duplicate checks within this episode loop
              existing_profile_ids.add(profile_data[:id])
            rescue ActiveRecord::RecordInvalid => e
              puts "  ! ERROR associating profile '#{profile_data[:name]}' (ID: #{profile_data[:id]}) to Episode ##{episode.id}: #{e.message}"
              error_count += 1
            end
          end
        end
      end
    end

    puts "\nTask finished."
    puts "Summary:"
    puts "  - Associations created: #{associated_count}"
    puts "  - Associations skipped (already existed): #{skipped_count}"
    puts "  - Errors: #{error_count}"
  end
end
