class ProfilesController < ApplicationController
  def index
    # Debug params to understand what's happening
    Rails.logger.debug "PARAMS: #{params.inspect}"
    Rails.logger.debug "SPECIALIZATION ID: #{params[:specialization_id].inspect}"
    
    # Only show profiles with status 'guest' by default, partners first, then alphabetical
    @profiles = Profile.includes(:specializations).where(status: 'guest')
                     .order(partner: :desc, name: :asc)
    
    # Filter by specialization
    if params[:specialization_id].present? && params[:specialization_id] != ""
      specialization_id = params[:specialization_id].to_i
      Rails.logger.debug "Filtering by specialization ID: #{specialization_id.inspect}, class: #{specialization_id.class}"
      # Only apply filter if ID is valid (greater than 0)
      if specialization_id > 0
        # Join with profile_specializations to find profiles with this specialization
        @profiles = @profiles.joins(:profile_specializations)
                            .where(profile_specializations: { specialization_id: specialization_id })
                            .distinct
        Rails.logger.debug "After filter, profile count: #{@profiles.count}"
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
              nearby_profiles = Profile.where(status: 'guest')
                                       .where.not(latitude: nil, longitude: nil)
                                       .near([lat, lon], 80, units: :km)
                                       
              # Apply the other filters to maintain consistency
              if params[:specialization_id].present?
                nearby_profiles = nearby_profiles.joins(:specializations)
                                                .where(specializations: { id: params[:specialization_id] })
              end
              
              if params[:guest_filter].present?
                case params[:guest_filter]
                when 'partners'
                  nearby_profiles = nearby_profiles.where(partner: true)
                when 'podcast_guests'
                  nearby_profiles = nearby_profiles.where.not(submission_date: nil)
                when 'procurement'
                  nearby_profiles = nearby_profiles.where(interested_in_procurement: true)
                end
              end
              
              # Combine results (keep original text matches and add any new nearby profiles)
              if nearby_profiles.any?
                @profiles = @profiles.or(nearby_profiles)
              end
            end
          end
        rescue => e
          Rails.logger.error "Error geocoding search input '#{params[:location]}': #{e.message}"
        end
      end
    end
    
    # Filter by guest status
    if params[:guest_filter].present?
      case params[:guest_filter]
      when 'partners'
        @profiles = @profiles.where(partner: true)
      when 'podcast_guests'
        @profiles = @profiles.where.not(submission_date: nil)
      when 'procurement'
        @profiles = @profiles.where(interested_in_procurement: true)
      end
    end
    
    @specializations = Specialization.all.order(:name)
  end

  def show
    @profile = Profile.find(params[:id])
  end
end
