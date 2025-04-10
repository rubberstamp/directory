class GeocodeProfileJob < ApplicationJob
  queue_as :default

  # Retry on common geocoding errors with exponential backoff
  # Waits 3s, 18s, 81s, 256s, 625s between retries
  retry_on Geocoder::Error, wait: :exponentially_longer, attempts: 5
  retry_on Timeout::Error, wait: :exponentially_longer, attempts: 5
  # Add other network-related errors if needed, e.g.:
  # retry_on SocketError, wait: :exponentially_longer, attempts: 5

  def perform(profile_id)
    profile = Profile.find_by(id: profile_id)
    return unless profile

    Rails.logger.info "GeocodeProfileJob: Geocoding profile #{profile_id} - #{profile.name}"

    begin
      # Get the address to geocode using the profile's full_address method
      # This now prioritizes location field over mailing address
      address_to_geocode = profile.full_address

      # Log what we're trying to geocode
      Rails.logger.info "GeocodeProfileJob: Attempting to geocode '#{address_to_geocode}' for profile #{profile.id}"

      # Perform the geocoding
      result = Geocoder.search(address_to_geocode).first

      if result
        # Update the coordinates
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

        # Save with geocoding callbacks disabled to prevent infinite loop
        profile.skip_geocoding = true
        profile.save
        profile.skip_geocoding = false

        Rails.logger.info "GeocodeProfileJob: Successfully geocoded #{profile.name} to [#{profile.latitude}, #{profile.longitude}]"
      else
        Rails.logger.warn "GeocodeProfileJob: No geocoding results found for '#{address_to_geocode}' (#{profile.name})"

        # If we tried to use location field but got no results, and mailing_address is present,
        # try using the mailing address as a fallback
        if profile.location.present? && profile.mailing_address.present? && address_to_geocode == profile.location
          Rails.logger.info "GeocodeProfileJob: Trying mailing address as fallback for profile #{profile.id}"

          result = Geocoder.search(profile.mailing_address).first

          if result
            # Update with fallback coordinates
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

            # Save with geocoding callbacks disabled to prevent infinite loop
            profile.skip_geocoding = true
            profile.save
            profile.skip_geocoding = false

            Rails.logger.info "GeocodeProfileJob: Successfully geocoded #{profile.name} using mailing address fallback to [#{profile.latitude}, #{profile.longitude}]"
          else
            Rails.logger.warn "GeocodeProfileJob: Fallback geocoding also failed for profile #{profile.id}"
          end
        end
      end
    rescue => e
      Rails.logger.error "GeocodeProfileJob: Error geocoding profile #{profile_id}: #{e.message}"
    end
  end
end
