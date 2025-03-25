class MapController < ApplicationController
  def index
    @profiles = Profile.where.not(latitude: nil, longitude: nil)
    
    # Log the initial count of profiles with coordinates
    Rails.logger.debug "Found #{@profiles.count} profiles with coordinates"
    
    # Allow filtering by specialization
    if params[:specialization_id].present?
      @profiles = @profiles.joins(:specializations).where(specializations: { id: params[:specialization_id] })
      Rails.logger.debug "After specialization filter: #{@profiles.count} profiles"
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
      specializations: profile.specializations.pluck(:name)
    }
  end
end
