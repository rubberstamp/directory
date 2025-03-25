namespace :profiles do
  desc "Update cached city and country for all profiles"
  task update_location_cache: :environment do
    puts "Updating cached city and country for all profiles..."
    
    # Get count of profiles with coordinates
    profiles_count = Profile.where.not(latitude: nil, longitude: nil).count
    puts "Found #{profiles_count} profiles with coordinates."
    
    success_count = 0
    error_count = 0
    
    # Process profiles in batches to avoid memory issues
    Profile.where.not(latitude: nil, longitude: nil).find_each(batch_size: 50) do |profile|
      begin
        # Skip profiles that already have cached city and country
        if profile.cached_city.present? && profile.cached_country.present?
          print "s"
          success_count += 1
          next
        end
        
        # Store city and country
        profile.store_city_and_country
        
        # Save the profile if it's been changed
        if profile.changed?
          profile.save
          print "."
          success_count += 1
        else
          print "n"  # No changes needed
          success_count += 1
        end
      rescue => e
        puts "
Error processing profile #{profile.id}: #{e.message}"
        print "E"
        error_count += 1
      end
    end
    
    puts "
Finished updating location cache."
    puts "Success: #{success_count}, Errors: #{error_count}"
  end
end
