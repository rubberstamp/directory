class EpisodesController < ApplicationController
  def index
    # Only show episodes that have at least one associated profile
    @episodes = Episode.joins(:profile_episodes).distinct.order(air_date: :desc)
    
    # Filter by search term if provided
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @episodes = @episodes.where(
        "LOWER(title) LIKE ? OR CAST(number AS TEXT) LIKE ?", 
        search_term, search_term
      )
    end
    
    # Filter by year if provided
    if params[:year].present?
      year = params[:year].to_i
      @episodes = @episodes.where("strftime('%Y', air_date) = ?", year.to_s)
    end
    
    # Group episodes by year for the filter dropdown
    # Also only include years from episodes with associated profiles
    @years = Episode.joins(:profile_episodes).distinct
                   .select("strftime('%Y', air_date) as year")
                   .distinct.map { |e| e.year.to_i }.sort.reverse
  end

  def show
    @episode = Episode.find(params[:id])
    
    # Check if the episode has any associated profiles
    if @episode.profiles.empty?
      flash[:alert] = "This episode is not currently available."
      redirect_to episodes_path and return
    end
    
    @primary_guest = @episode.profile_episodes.find_by(is_primary_guest: true)&.profile
    @other_guests = @episode.profile_episodes.where(is_primary_guest: false).includes(:profile)
  end
end
