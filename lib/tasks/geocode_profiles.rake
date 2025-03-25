namespace :profiles do
  desc "Geocode profiles that have location or mailing_address but no coordinates"
  task geocode: :environment do
    profiles = Profile.where(latitude: nil).or(Profile.where(longitude: nil))
                     .where("location IS NOT NULL OR mailing_address IS NOT NULL")
                    
    if profiles.empty?
      puts "No profiles found needing geocoding."
      exit
    end
    
    puts "Found #{profiles.count} profiles that need geocoding..."
    
    profiles.each_with_index do |profile, i|
      if i > 0 && i % 10 == 0
        # Be nice to the geocoding API by not sending too many requests at once
        puts "Geocoded #{i} profiles - sleeping for 2 seconds..."
        sleep(2)
      end
      
      address = profile.full_address
      
      if address.present?
        puts "[#{i+1}/#{profiles.count}] Geocoding #{profile.name} (#{address})..."
        result = profile.geocode
        if result.present?
          profile.save
          puts "  ✓ Geocoded to [#{profile.latitude}, #{profile.longitude}]"
        else
          puts "  ✗ Could not geocode address"
        end
      else
        puts "[#{i+1}/#{profiles.count}] #{profile.name} has no address to geocode"
      end
    end
    
    puts "Done!"
  end
end