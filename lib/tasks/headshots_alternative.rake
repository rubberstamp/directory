namespace :headshots do
  desc 'Generate placeholder headshots for profiles with Google Drive links but no image'
  task generate_placeholders: :environment do
    # Find profiles with Google Drive headshot URLs
    profiles_with_drive_links = Profile.where("headshot_url LIKE ?", "%drive.google.com%")
    
    puts "Found #{profiles_with_drive_links.count} profiles with Google Drive headshot links"
    
    count = 0
    profiles_with_drive_links.each do |profile|
      # Only create placeholders for profiles where the Google Drive link failed
      if profile.headshot_url.include?('drive.google.com')
        # Generate a placeholder URL using UI Avatars service
        # This creates a nice initial-based avatar with colors based on the name
        name = CGI.escape(profile.name)
        placeholder_url = "https://ui-avatars.com/api/?name=#{name}&background=random&color=fff&size=200"
        
        profile.update(headshot_url: placeholder_url)
        puts "Created placeholder avatar for #{profile.name}"
        count += 1
      end
    end
    
    puts "Created #{count} placeholder avatars."
  end
  
  desc 'Manual export instructions for Google Drive images'
  task instructions: :environment do
    # Count profiles with Google Drive headshot URLs
    profiles_with_drive_links = Profile.where("headshot_url LIKE ?", "%drive.google.com%")
    
    if profiles_with_drive_links.count > 0
      puts "\n======= MANUAL EXPORT INSTRUCTIONS FOR GOOGLE DRIVE IMAGES ======="
      puts "\nThere are #{profiles_with_drive_links.count} profiles with Google Drive image links."
      puts "Due to Google Drive's permission system, automatic downloading may not work for all images."
      puts "\nHere are the profiles and their Google Drive links:\n\n"
      
      profiles_with_drive_links.each_with_index do |profile, index|
        puts "#{index + 1}. #{profile.name}: #{profile.headshot_url}"
      end
      
      puts "\nTo manually download these images:"
      puts "1. Visit each link in a browser where you're signed in to Google"
      puts "2. Download the images to your computer"
      puts "3. Place them in public/uploads/headshots/ directory with descriptive filenames"
      puts "4. Update the profiles in the database to point to the new local paths (/uploads/headshots/filename.jpg)"
      puts "\nAlternatively, you can use the headshots:generate_placeholders task to create"
      puts "placeholder avatars based on user initials."
      puts "\n=================================================================="
    else
      puts "No profiles with Google Drive links found."
    end
  end
end