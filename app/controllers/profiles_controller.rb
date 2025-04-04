class ProfilesController < ApplicationController
  def index
    @profiles = Profile.includes(:specializations).all.order(name: :asc)
    
    # Filter by specialization
    if params[:specialization_id].present?
      @profiles = @profiles.joins(:specializations).where(specializations: { id: params[:specialization_id] })
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
