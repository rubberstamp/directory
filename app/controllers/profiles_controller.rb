class ProfilesController < ApplicationController
  def index
    @profiles = Profile.includes(:specializations).all.order(name: :asc)
    
    # Filter by specialization
    if params[:specialization_id].present?
      @profiles = @profiles.joins(:specializations).where(specializations: { id: params[:specialization_id] })
    end
    
    # Filter by location
    if params[:location].present?
      @profiles = @profiles.where("location LIKE ?", "%#{params[:location]}%")
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
