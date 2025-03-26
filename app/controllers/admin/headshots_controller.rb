class Admin::HeadshotsController < Admin::BaseController
  def index
    @profile_count = Profile.count
    
    # Count profiles with ActiveStorage headshots
    @profiles_with_activestorage = Profile.joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = profiles.id AND active_storage_attachments.record_type = 'Profile' AND active_storage_attachments.name = 'headshot'").count
    
    # Count profiles with legacy headshot URLs
    @profiles_with_headshots = Profile.where.not(headshot_url: nil).count
    @profiles_with_placeholder_avatars = Profile.where("headshot_url LIKE ?", "%ui-avatars.com%").count
    @profiles_with_local_images = Profile.where("headshot_url LIKE ?", "/uploads/headshots/%").count
    @profiles_with_google_drive_links = Profile.where("headshot_url LIKE ?", "%drive.google.com%").count
    
    # Total profiles with any type of headshot (ActiveStorage or legacy URL)
    @total_profiles_with_headshots = @profiles_with_headshots + @profiles_with_activestorage
    
    # Profiles needing attention: those without any headshot or with Google Drive links
    # but exclude those that already have ActiveStorage attachments
    profiles_query = Profile.left_joins(headshot_attachment: :blob)
                          .where("(profiles.headshot_url LIKE ? OR profiles.headshot_url IS NULL) AND active_storage_attachments.id IS NULL", 
                                "%drive.google.com%")
                          .order(:name)
    
    # Handle pagination with or without kaminari
    if Profile.respond_to?(:page)
      @profiles_needing_attention = profiles_query.page(params[:page]).per(20)
    else
      # Basic pagination if kaminari is not available
      @profiles_needing_attention = profiles_query.limit(20)
    end
  end
  
  def update
    @profile = Profile.find(params[:id])
    
    if params[:headshot_url].present?
      @profile.update(headshot_url: params[:headshot_url])
      flash[:notice] = "Headshot URL updated for #{@profile.name}"
    elsif params[:profile] && params[:profile][:headshot_image]
      process_uploaded_image
    else
      flash[:alert] = "No headshot URL or file provided"
    end
    
    redirect_to admin_headshots_path
  end
  
  def create_placeholder
    @profile = Profile.find(params[:id])
    
    name = CGI.escape(@profile.name)
    placeholder_url = "https://ui-avatars.com/api/?name=#{name}&background=random&color=fff&size=200"
    
    @profile.update(headshot_url: placeholder_url)
    flash[:notice] = "Created placeholder avatar for #{@profile.name}"
    
    redirect_to admin_headshots_path
  end
  
  def run_import
    # This is a non-blocking way to run the rake task
    # It will run in the background and not block the request
    pid = Process.fork do
      system("cd #{Rails.root} && RAILS_ENV=#{Rails.env} bundle exec rake headshots:from_google_drive_api")
      exit
    end
    
    Process.detach(pid)
    
    flash[:notice] = "Google Drive headshot import has been started in the background."
    redirect_to admin_headshots_path
  end
  
  def migrate_to_active_storage
    # This is a non-blocking way to run the rake task
    # It will run in the background and not block the request
    pid = Process.fork do
      system("cd #{Rails.root} && RAILS_ENV=#{Rails.env} bundle exec rake headshots:migrate_to_active_storage")
      exit
    end
    
    Process.detach(pid)
    
    flash[:notice] = "Headshot migration to ActiveStorage has been started in the background."
    redirect_to admin_headshots_path
  end
  
  private
  
  def process_uploaded_image
    uploaded_file = params[:profile][:headshot_image]
    
    # Check if it's a Google Drive URL entered in the file field (text input)
    if uploaded_file.is_a?(String) && uploaded_file.include?('drive.google.com')
      @profile.update(headshot_url: uploaded_file)
      flash[:notice] = "Google Drive URL saved as headshot for #{@profile.name}"
      return
    end
    
    begin
      # Attach the file using ActiveStorage
      @profile.headshot.attach(uploaded_file)
      
      # Keep headshot_url for compatibility with existing code
      flash[:notice] = "Headshot uploaded for #{@profile.name}"
    rescue StandardError => e
      flash[:alert] = "Error processing image: #{e.message}"
    end
  end
end