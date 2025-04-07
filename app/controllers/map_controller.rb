class MapController < ApplicationController
  def index
    # Debug params to understand what's happening
    Rails.logger.debug "MAP PARAMS: #{params.inspect}"
    Rails.logger.debug "MAP SPECIALIZATION ID: #{params[:specialization_id].inspect}"
    
    @profiles = Profile.where.not(latitude: nil, longitude: nil)
    
    # Log the initial count of profiles with coordinates
    Rails.logger.debug "Found #{@profiles.count} profiles with coordinates"
    
    # Allow filtering by specialization
    if params[:specialization_id].present? && params[:specialization_id] != ""
      specialization_id = params[:specialization_id].to_i
      Rails.logger.debug "Filtering by specialization ID: #{specialization_id.inspect}, class: #{specialization_id.class}"
      # Only apply filter if ID is valid (greater than 0)
      if specialization_id > 0
        # Join with profile_specializations to find profiles with this specialization
        @profiles = @profiles.joins(:profile_specializations)
                            .where(profile_specializations: { specialization_id: specialization_id })
                            .distinct
        Rails.logger.debug "After specialization filter: #{@profiles.count} profiles"
      else
        Rails.logger.warn "Invalid specialization ID value: #{params[:specialization_id]}"
      end
    end
    
    # Filter by location - enhanced with geocoding
    if params[:location].present?
      # Try exact location field match first
      text_query = @profiles.where("location LIKE ?", "%#{params[:location]}%")
      
      # Also search in cached city and country
      text_query = text_query.or(@profiles.where("cached_city LIKE ?", "%#{params[:location]}%"))
      text_query = text_query.or(@profiles.where("cached_country LIKE ?", "%#{params[:location]}%"))
      
      # Set this as our base result set
      @profiles = text_query
      Rails.logger.debug "After text location filter: #{@profiles.count} profiles"
      
      # If very few or no results found, try geocoding the input location and search within a radius
      if @profiles.count < 3
        begin
          # Geocode the search input
          results = Geocoder.search(params[:location])
          
          if results.present? && results.first&.coordinates.present?
            # Get the lat/lon coordinates
            lat, lon = results.first.coordinates
            
            # Safety checks for valid coordinates
            if lat.present? && lon.present? && lat.to_f.between?(-90, 90) && lon.to_f.between?(-180, 180)
              # Search within ~50 miles/80km
              nearby_profiles = Profile.where.not(latitude: nil, longitude: nil)
                                       .near([lat, lon], 80, units: :km)
                                       
              # Apply the other filters to maintain consistency
              if params[:specialization_id].present?
                nearby_profiles = nearby_profiles.joins(:specializations)
                                              .where(specializations: { id: params[:specialization_id] })
              end
              
              if params[:guest_filter].present?
                case params[:guest_filter]
                when 'podcast_guests'
                  nearby_profiles = nearby_profiles.where.not(submission_date: nil)
                when 'procurement'
                  nearby_profiles = nearby_profiles.where(interested_in_procurement: true)
                end
              end
              
              # Combine results (keep original text matches and add any new nearby profiles)
              if nearby_profiles.any?
                @profiles = @profiles.or(nearby_profiles)
                Rails.logger.debug "After geocoded location filter: #{@profiles.count} profiles"
              end
            end
          end
        rescue => e
          Rails.logger.error "Error geocoding search input '#{params[:location]}': #{e.message}"
        end
      end
    end
    
    # Allow filtering by guest status
    if params[:guest_filter].present?
      case params[:guest_filter]
      when 'podcast_guests'
        @profiles = @profiles.where.not(submission_date: nil)
      when 'procurement'
        @profiles = @profiles.where(interested_in_procurement: true)
      end
      Rails.logger.debug "After guest filter: #{@profiles.count} profiles"
    end
    
    @specializations = Specialization.all.order(:name)
    
    respond_to do |format|
      format.html
      format.json do
        markers = @profiles.map { |profile| profile_to_marker(profile) }.compact
        Rails.logger.debug "Sending #{markers.count} marker objects to the client"
        render json: markers
      end
    end
  end
  
  private
  
  def profile_to_marker(profile)
    # Ensure we have valid coordinates
    return nil unless profile.latitude.present? && profile.longitude.present?
    
    # Get formatted location with cached city/country to avoid geocoding
    location_display = profile.formatted_location
    
    # Get headshot URL if available
    headshot_url = nil
    if profile.headshot.attached?
      headshot_url = url_for(profile.headshot)
    elsif profile.headshot_url.present? && !profile.headshot_url.include?('drive.google.com')
      headshot_url = profile.headshot_url
    elsif profile.image_url.present?
      headshot_url = profile.image_url
    end
    
    # Debug log for development
    Rails.logger.debug "Profile #{profile.id} (#{profile.name}): lat=#{profile.latitude}, lng=#{profile.longitude}, loc=#{location_display}"
    
    {
      id: profile.id,
      name: profile.name,
      latitude: profile.latitude.to_f,  # Convert to float for JSON serialization
      longitude: profile.longitude.to_f, # Convert to float for JSON serialization
      company: profile.company,
      headline: profile.headline,
      location: location_display,
      profile_path: profile_path(profile),
      has_podcast: profile.has_podcast_episode?,
      specializations: profile.specializations.pluck(:name),
      headshot_url: headshot_url
    }
  end
end
