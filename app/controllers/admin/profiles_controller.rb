class Admin::ProfilesController < Admin::BaseController
  before_action :set_profile, only: [:show, :edit, :update, :destroy]
  
  def index
    # Default sorting
    sort_param = params[:sort] || 'name_asc'
    
    # Apply sorting
    case sort_param
    when 'name_asc'
      @profiles = Profile.order(name: :asc)
    when 'name_desc'
      @profiles = Profile.order(name: :desc)
    when 'submission_date_desc'
      @profiles = Profile.order(submission_date: :desc)
    when 'submission_date_asc'
      @profiles = Profile.order(submission_date: :asc)
    when 'episode_date_desc'
      @profiles = Profile.order(episode_date: :desc)
    when 'episode_date_asc'
      @profiles = Profile.order(episode_date: :asc)
    else
      @profiles = Profile.order(created_at: :desc)
    end
    
    # Apply search filters if provided
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @profiles = @profiles.where(
        "LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(company) LIKE ? OR LOWER(episode_title) LIKE ?", 
        search_term, search_term, search_term, search_term
      )
    end
    
    # Apply status filter if provided
    if params[:status].present?
      case params[:status]
      when 'guest'
        @profiles = @profiles.where.not(submission_date: nil)
      when 'episode'
        @profiles = @profiles.where.not(episode_url: nil)
      when 'missing_episode'
        @profiles = @profiles.where.not(submission_date: nil).where(episode_url: nil)
      when 'interested'
        @profiles = @profiles.where(interested_in_procurement: true)
      end
    end
    
    # Pagination (would use Kaminari or will_paginate in a real app)
    @profiles = @profiles.all
  end

  def show
  end

  def new
    @profile = Profile.new
  end

  def create
    @profile = Profile.new(profile_params)
    
    if @profile.save
      redirect_to admin_profiles_path, notice: 'Profile was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @profile.update(profile_params)
      redirect_to admin_profiles_path, notice: 'Profile was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @profile.destroy
    redirect_to admin_profiles_path, notice: 'Profile was successfully deleted.'
  end
  
  private
  
  def set_profile
    @profile = Profile.find(params[:id])
  end
  
  def profile_params
    params.require(:profile).permit(
      :name, :headline, :bio, :location, :linkedin_url, 
      :youtube_url, :email, :phone, :image_url,
      :company, :website, :mailing_address, :facebook_url,
      :twitter_url, :instagram_url, :tiktok_url, :testimonial,
      :headshot_url, :interested_in_procurement, :submission_date,
      :deprecated_episode_number, :deprecated_episode_title, 
      :deprecated_episode_url, :deprecated_episode_date,
      :headshot, # ActiveStorage attachment
      specialization_ids: []
    )
  end
end
