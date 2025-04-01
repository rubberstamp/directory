class Admin::ProfilesController < Admin::BaseController
  before_action :set_profile, only: [:show, :edit, :update, :destroy]
  require 'csv'
  
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
      @profiles = Profile.order(deprecated_episode_date: :desc)
    when 'episode_date_asc'
      @profiles = Profile.order(deprecated_episode_date: :asc)
    else
      @profiles = Profile.order(created_at: :desc)
    end
    
    # Apply search filters if provided
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @profiles = @profiles.where(
        "LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(company) LIKE ? OR LOWER(deprecated_episode_title) LIKE ?", 
        search_term, search_term, search_term, search_term
      )
    end
    
    # Apply status filter if provided
    if params[:status].present?
      case params[:status]
      when 'guest'
        @profiles = @profiles.where(status: 'guest')
      when 'applicant'
        @profiles = @profiles.where(status: 'applicant')
      when 'episode'
        @profiles = @profiles.where.not(deprecated_episode_url: nil)
      when 'missing_episode'
        @profiles = @profiles.where.not(submission_date: nil).where(deprecated_episode_url: nil)
      when 'interested'
        @profiles = @profiles.where(interested_in_procurement: true)
      when 'missing_location'
        @profiles = @profiles.where(latitude: nil).or(@profiles.where(longitude: nil))
      when 'on_map'
        @profiles = @profiles.where.not(latitude: nil).where.not(longitude: nil)
      when 'not_on_map'
        @profiles = @profiles.where("latitude IS NULL OR longitude IS NULL")
      end
    end
    
    # Check for import errors
    if params[:import_errors].present?
      @import_errors = Rails.cache.read("profile_import_errors_#{params[:import_errors]}")
      # Delete the cache entry to prevent it from being accessed again
      Rails.cache.delete("profile_import_errors_#{params[:import_errors]}") if @import_errors
    end
    
    # Pagination using Kaminari
    @profiles = @profiles.page(params[:page]).per(20)
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
  
  def geocode
    @profile = Profile.find(params[:id])
    
    if @profile.location.blank? && @profile.mailing_address.blank?
      redirect_to admin_profile_path(@profile), alert: 'Profile needs a location or mailing address to be geocoded.'
      return
    end
    
    # Queue geocoding job
    GeocodeProfileJob.perform_later(@profile.id)
    
    redirect_to admin_profile_path(@profile), notice: 'Geocoding job has been queued. Location will be updated shortly.'
  end
  
  # Batch geocoding
  def geocode_all
    # Find all profiles that have location or mailing address but no coordinates
    profiles = Profile.where("(location IS NOT NULL AND location != '') OR (mailing_address IS NOT NULL AND mailing_address != '')")
                    .where("latitude IS NULL OR longitude IS NULL")
    
    if profiles.empty?
      redirect_to admin_profiles_path, alert: 'No profiles found that need geocoding.'
      return
    end
    
    # Queue geocoding jobs for each profile
    count = 0
    profiles.each do |profile|
      GeocodeProfileJob.perform_later(profile.id)
      count += 1
    end
    
    redirect_to admin_profiles_path, notice: "Geocoding jobs have been queued for #{count} profiles."
  end
  
  def export
    # Get profiles to export (with the same filters as index)
    profiles = Profile.all
    
    # Apply sorting
    sort_param = params[:sort] || 'name_asc'
    case sort_param
    when 'name_asc'
      profiles = profiles.order(name: :asc)
    when 'name_desc'
      profiles = profiles.order(name: :desc)
    when 'submission_date_desc'
      profiles = profiles.order(submission_date: :desc)
    when 'submission_date_asc'
      profiles = profiles.order(submission_date: :asc)
    when 'episode_date_desc'
      profiles = profiles.order(deprecated_episode_date: :desc)
    when 'episode_date_asc'
      profiles = profiles.order(deprecated_episode_date: :asc)
    else
      profiles = profiles.order(created_at: :desc)
    end
    
    # Apply search filters if provided
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      profiles = profiles.where(
        "LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(company) LIKE ? OR LOWER(deprecated_episode_title) LIKE ?", 
        search_term, search_term, search_term, search_term
      )
    end
    
    # Apply status filter if provided
    if params[:status].present?
      case params[:status]
      when 'guest'
        profiles = profiles.where(status: 'guest')
      when 'applicant'
        profiles = profiles.where(status: 'applicant')
      when 'episode'
        profiles = profiles.where.not(deprecated_episode_url: nil)
      when 'missing_episode'
        profiles = profiles.where.not(submission_date: nil).where(deprecated_episode_url: nil)
      when 'interested'
        profiles = profiles.where(interested_in_procurement: true)
      when 'missing_location'
        profiles = profiles.where(latitude: nil).or(profiles.where(longitude: nil))
      when 'on_map'
        profiles = profiles.where.not(latitude: nil).where.not(longitude: nil)
      when 'not_on_map'
        profiles = profiles.where("latitude IS NULL OR longitude IS NULL")
      end
    end
    
    # Generate CSV
    csv_data = CSV.generate do |csv|
      # Add headers
      csv << [
        "ID", "Name", "Email", "Phone", "Company", "Title", "Location",
        "Latitude", "Longitude", "Formatted Location",
        "Bio", "Website", "LinkedIn URL", "Twitter URL", "Facebook URL",
        "Instagram URL", "TikTok URL", "YouTube URL",
        "Status", "Practice Size", "Podcast Objectives",
        "Submission Date", "Interested in Procurement",
        "Episode Number", "Episode Title", "Episode URL", "Episode Date"
      ]
      
      # Add profile data
      profiles.each do |profile|
        # Format data
        row = [
          profile.id,
          profile.name,
          profile.email,
          profile.phone,
          profile.company,
          profile.headline,
          profile.location,
          profile.latitude,
          profile.longitude,
          profile.formatted_location,
          profile.bio,
          profile.website,
          profile.linkedin_url,
          profile.twitter_url,
          profile.facebook_url,
          profile.instagram_url,
          profile.tiktok_url,
          profile.youtube_url,
          profile.status,
          profile.practice_size,
          profile.podcast_objectives,
          profile.submission_date&.strftime("%Y-%m-%d"),
          profile.interested_in_procurement ? "Yes" : "No",
          profile.deprecated_episode_number,
          profile.deprecated_episode_title,
          profile.deprecated_episode_url,
          profile.deprecated_episode_date&.strftime("%Y-%m-%d")
        ]
        
        csv << row
      end
    end
    
    # Send file
    send_data csv_data, 
              type: "text/csv", 
              filename: "profiles_export_#{Date.today.strftime("%Y%m%d")}.csv",
              disposition: "attachment"
  end
  
  def import
    # Check if file was uploaded
    unless params[:file].present?
      redirect_to admin_profiles_path, alert: "Please select a CSV file to import"
      return
    end

    # Check file format
    unless params[:file].content_type == "text/csv"
      redirect_to admin_profiles_path, alert: "Please upload a valid CSV file"
      return
    end

    # Read and encode CSV
    csv_text = params[:file].read.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    begin
      csv = CSV.parse(csv_text, headers: true)
    rescue CSV::MalformedCSVError => e
      redirect_to admin_profiles_path, alert: "CSV parsing error: #{e.message}"
      return
    end

    # Track stats
    created_count = 0
    updated_count = 0
    skipped_count = 0
    errors = []

    # Process CSV
    ActiveRecord::Base.transaction do
      csv.each_with_index do |row, index|
        begin
          # Skip empty rows
          next if row.values_at("Name", "Email").all?(&:blank?)
          
          # Extract ID if present (for updates)
          profile_id = row["ID"].presence
          
          if profile_id.present?
            # Try to find existing profile
            profile = Profile.find_by(id: profile_id)
            
            if profile.nil?
              errors << "Row #{index + 2}: Profile with ID #{profile_id} not found"
              skipped_count += 1
              next
            end
            
            # Update existing profile
            update_data = extract_profile_data_from_row(row)
            
            if profile.update(update_data)
              updated_count += 1
            else
              errors << "Row #{index + 2}: Failed to update profile '#{row['Name']}': #{profile.errors.full_messages.join(', ')}"
              skipped_count += 1
            end
          else
            # Create new profile
            profile_data = extract_profile_data_from_row(row)
            
            # Email is required - validate presence
            if profile_data[:email].blank?
              errors << "Row #{index + 2}: Email is required for new profiles"
              skipped_count += 1
              next
            end
            
            # Check if a profile with this email already exists
            existing_profile = Profile.find_by(email: profile_data[:email])
            if existing_profile
              errors << "Row #{index + 2}: A profile with email '#{profile_data[:email]}' already exists (ID: #{existing_profile.id})"
              skipped_count += 1
              next
            end
            
            profile = Profile.new(profile_data)
            
            if profile.save
              created_count += 1
            else
              errors << "Row #{index + 2}: Failed to create profile '#{row['Name']}': #{profile.errors.full_messages.join(', ')}"
              skipped_count += 1
            end
          end
        rescue => e
          errors << "Row #{index + 2}: Unexpected error - #{e.message}"
          skipped_count += 1
        end
      end
    end

    # Redirect with success/error message
    if errors.any?
      flash[:alert] = "Import completed with #{errors.count} issues. Created: #{created_count}, Updated: #{updated_count}, Skipped: #{skipped_count}."
      
      # Store errors in a temporary file instead of session to avoid cookie overflow
      error_id = SecureRandom.hex(8)
      Rails.cache.write("profile_import_errors_#{error_id}", errors, expires_in: 1.hour)
      
      redirect_to admin_profiles_path(import_errors: error_id)
    else
      flash[:notice] = "Successfully imported profiles. Created: #{created_count}, Updated: #{updated_count}, Skipped: #{skipped_count}."
      redirect_to admin_profiles_path
    end
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
      :status, :practice_size, :podcast_objectives,
      specialization_ids: []
    )
  end
  
  # Extract profile data from CSV row
  def extract_profile_data_from_row(row)
    data = {
      name: row["Name"],
      email: row["Email"],
      phone: row["Phone"],
      company: row["Company"],
      headline: row["Title"],
      location: row["Location"],
      bio: row["Bio"],
      website: row["Website"],
      linkedin_url: row["LinkedIn URL"],
      twitter_url: row["Twitter URL"],
      facebook_url: row["Facebook URL"],
      instagram_url: row["Instagram URL"],
      tiktok_url: row["TikTok URL"],
      youtube_url: row["YouTube URL"],
      deprecated_episode_number: row["Episode Number"],
      deprecated_episode_title: row["Episode Title"],
      deprecated_episode_url: row["Episode URL"],
      status: row["Status"],
      practice_size: row["Practice Size"],
      podcast_objectives: row["Podcast Objectives"],
    }
    
    # Parse date fields
    data[:submission_date] = parse_date(row["Submission Date"]) if row["Submission Date"].present?
    data[:deprecated_episode_date] = parse_date(row["Episode Date"]) if row["Episode Date"].present?
    
    # Parse boolean fields
    if row["Interested in Procurement"].present?
      data[:interested_in_procurement] = row["Interested in Procurement"].to_s.downcase == "yes"
    end
    
    # Remove nil values to avoid overwriting existing data with nil
    data.compact
  end
  
  # Parse date from string
  def parse_date(date_string)
    begin
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end
  end
end
