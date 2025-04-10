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
    puts "Using improved geocoding approach (prioritizing location field)..."

    # Track statistics
    success_count = 0
    fallback_count = 0
    failed_count = 0

    profiles.each_with_index do |profile, i|
      if i > 0 && i % 10 == 0
        # Be nice to the geocoding API by not sending too many requests at once
        puts "Geocoded #{i} profiles (#{success_count} successes, #{fallback_count} fallbacks, #{failed_count} failures) - sleeping for 2 seconds..."
        sleep(2)
      end

      # First try using location field if present
      primary_address = profile.location.presence || profile.mailing_address
      fallback_address = (profile.location.present? && profile.mailing_address.present?) ? profile.mailing_address : nil

      if primary_address.present?
        puts "[#{i+1}/#{profiles.count}] Geocoding #{profile.name} (#{primary_address})..."

        # Try primary address
        result = Geocoder.search(primary_address).first
        if result.present?
          # Update coordinates
          profile.latitude = result.latitude
          profile.longitude = result.longitude

          # Update cached city and country
          if result.address.is_a?(Hash)
            profile.cached_city = result.address["city"] if result.address["city"].present?
            profile.cached_country = result.address["country"] if result.address["country"].present?
          elsif result.address.is_a?(String)
            address_parts = result.address.split(", ")
            if address_parts.size >= 2
              profile.cached_city = address_parts[-3] # Often city is 3rd from the end
              profile.cached_country = address_parts[-1] # Country is usually last
            end
          end

          # Save with geocoding callbacks disabled
          profile.skip_geocoding = true
          profile.save
          profile.skip_geocoding = false

          success_count += 1
          puts "  ✓ Geocoded to [#{profile.latitude}, #{profile.longitude}] - #{profile.formatted_location}"
        elsif fallback_address.present?
          # Try fallback address
          puts "    Trying fallback address: #{fallback_address}"
          result = Geocoder.search(fallback_address).first

          if result.present?
            # Update coordinates
            profile.latitude = result.latitude
            profile.longitude = result.longitude

            # Update cached city and country
            if result.address.is_a?(Hash)
              profile.cached_city = result.address["city"] if result.address["city"].present?
              profile.cached_country = result.address["country"] if result.address["country"].present?
            elsif result.address.is_a?(String)
              address_parts = result.address.split(", ")
              if address_parts.size >= 2
                profile.cached_city = address_parts[-3] # Often city is 3rd from the end
                profile.cached_country = address_parts[-1] # Country is usually last
              end
            end

            # Save with geocoding callbacks disabled
            profile.skip_geocoding = true
            profile.save
            profile.skip_geocoding = false

            fallback_count += 1
            puts "  ✓ Geocoded using fallback to [#{profile.latitude}, #{profile.longitude}] - #{profile.formatted_location}"
          else
            failed_count += 1
            puts "  ✗ Could not geocode either address"
          end
        else
          failed_count += 1
          puts "  ✗ Could not geocode address"
        end
      else
        puts "[#{i+1}/#{profiles.count}] #{profile.name} has no address to geocode"
        failed_count += 1
      end
    end

    puts "Geocoding complete!"
    puts "Summary:"
    puts "- Successfully geocoded: #{success_count}"
    puts "- Geocoded using fallback address: #{fallback_count}"
    puts "- Failed to geocode: #{failed_count}"
    puts "- Total processed: #{profiles.count}"
  end

  desc "Regenerate cached location information for profiles with coordinates"
  task update_location_cache: :environment do
    profiles = Profile.where.not(latitude: nil).where.not(longitude: nil)
                     .where("cached_city IS NULL OR cached_country IS NULL")

    if profiles.empty?
      puts "No profiles found needing location cache updates."
      exit
    end

    puts "Found #{profiles.count} profiles that need location cache updates..."

    success_count = 0
    failed_count = 0

    profiles.each_with_index do |profile, i|
      if i > 0 && i % 20 == 0
        # Be nice to the geocoding API by not sending too many requests at once
        puts "Processed #{i} profiles - sleeping for 1 second..."
        sleep(1)
      end

      puts "[#{i+1}/#{profiles.count}] Updating location cache for #{profile.name}..."

      begin
        result = Geocoder.search([ profile.latitude, profile.longitude ]).first

        if result
          # Update cached city and country
          if result.address.is_a?(Hash)
            profile.cached_city = result.address["city"] if result.address["city"].present?
            profile.cached_country = result.address["country"] if result.address["country"].present?
          elsif result.address.is_a?(String)
            address_parts = result.address.split(", ")
            if address_parts.size >= 2
              profile.cached_city = address_parts[-3] # Often city is 3rd from the end
              profile.cached_country = address_parts[-1] # Country is usually last
            end
          end

          # Save with geocoding callbacks disabled
          profile.skip_geocoding = true
          profile.save
          profile.skip_geocoding = false

          success_count += 1
          puts "  ✓ Updated cache to: #{profile.formatted_location}"
        else
          failed_count += 1
          puts "  ✗ Could not reverse geocode coordinates"
        end
      rescue => e
        failed_count += 1
        puts "  ✗ Error during reverse geocoding: #{e.message}"
      end
    end

    puts "Cache update complete!"
    puts "Summary:"
    puts "- Successfully updated: #{success_count}"
    puts "- Failed to update: #{failed_count}"
    puts "- Total processed: #{profiles.count}"
  end
end
