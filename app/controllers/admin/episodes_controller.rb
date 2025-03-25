class Admin::EpisodesController < Admin::BaseController
  before_action :set_episode, only: [:show, :edit, :update, :destroy, :attach_profile, :detach_profile]

  def index
    @episodes = Episode.all.order(air_date: :desc)
    
    # Filter by search term if provided
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @episodes = @episodes.where(
        "LOWER(title) LIKE ? OR CAST(number AS TEXT) LIKE ?", 
        search_term, search_term
      )
    end
    
    # Paginate if Kaminari is available
    @episodes = @episodes.page(params[:page]).per(20) if @episodes.respond_to?(:page)
  end

  def show
  end

  def new
    @episode = Episode.new
  end

  def edit
    # Get all profiles for the dropdown
    @profiles = Profile.order(:name)
    
    # Get profiles already associated with this episode
    @associated_profiles = @episode.profiles
  end

  def create
    @episode = Episode.new(episode_params)

    if @episode.save
      redirect_to admin_episode_path(@episode), notice: 'Episode was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @episode.update(episode_params)
      redirect_to admin_episode_path(@episode), notice: 'Episode was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @episode.destroy
    redirect_to admin_episodes_path, notice: 'Episode was successfully destroyed.'
  end
  
  def attach_profile
    profile_id = params[:profile_id]
    is_primary = params[:is_primary] == "1"
    appearance_type = params[:appearance_type].presence || "Guest"
    
    # Check if profile exists
    profile = Profile.find_by(id: profile_id)
    
    if profile.nil?
      redirect_to edit_admin_episode_path(@episode), alert: 'Profile not found.'
      return
    end
    
    # If this is set as primary, clear other primary guests if needed
    if is_primary
      @episode.profile_episodes.where(is_primary_guest: true).update_all(is_primary_guest: false)
    end
    
    # Check if association already exists
    existing = @episode.profile_episodes.find_by(profile_id: profile_id)
    
    if existing
      # Update existing association
      existing.update(
        is_primary_guest: is_primary,
        appearance_type: appearance_type
      )
      redirect_to edit_admin_episode_path(@episode), notice: "Profile '#{profile.name}' role updated."
    else
      # Create new association
      profile_episode = @episode.profile_episodes.new(
        profile_id: profile_id,
        is_primary_guest: is_primary,
        appearance_type: appearance_type
      )
      
      if profile_episode.save
        redirect_to edit_admin_episode_path(@episode), notice: "Profile '#{profile.name}' attached."
      else
        redirect_to edit_admin_episode_path(@episode), alert: "Failed to attach profile: #{profile_episode.errors.full_messages.join(', ')}"
      end
    end
  end
  
  def detach_profile
    profile_id = params[:profile_id]
    
    # Find and destroy the association
    profile_episode = @episode.profile_episodes.find_by(profile_id: profile_id)
    
    if profile_episode
      profile_name = profile_episode.profile.name
      profile_episode.destroy
      redirect_to edit_admin_episode_path(@episode), notice: "Profile '#{profile_name}' detached."
    else
      redirect_to edit_admin_episode_path(@episode), alert: 'Profile association not found.'
    end
  end

  private
    def set_episode
      @episode = Episode.find(params[:id])
    end

    def episode_params
      params.require(:episode).permit(
        :number, 
        :title, 
        :video_id, 
        :air_date, 
        :duration_seconds, 
        :notes,
        :thumbnail_url
      )
    end
end