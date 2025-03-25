class Admin::HeadshotsController < Admin::BaseController
  def index
    @profile_count = Profile.count
    @profiles_with_headshots = Profile.where.not(headshot_url: nil).count
    @profiles_with_placeholder_avatars = Profile.where("headshot_url LIKE ?", "%ui-avatars.com%").count
    @profiles_with_local_images = Profile.where("headshot_url LIKE ?", "/uploads/headshots/%").count
    @profiles_with_google_drive_links = Profile.where("headshot_url LIKE ?", "%drive.google.com%").count
    
    profiles_query = Profile.where("headshot_url LIKE ?", "%drive.google.com%")
                           .or(Profile.where(headshot_url: nil))
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
  
  private
  
  def process_uploaded_image
    uploaded_file = params[:profile][:headshot_image]
    
    # Check if it's a Google Drive URL entered in the file field (text input)
    if uploaded_file.is_a?(String) && uploaded_file.include?('drive.google.com')
      @profile.update(headshot_url: uploaded_file)
      flash[:notice] = "Google Drive URL saved as headshot for #{@profile.name}"
      return
    end
    
    # Ensure uploads directory exists
    storage_dir = Rails.root.join('public', 'uploads', 'headshots')
    FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)
    
    # Create a unique filename based on profile name and timestamp
    filename = "#{@profile.name.parameterize}-#{Time.now.to_i}.jpg"
    local_path = File.join(storage_dir, filename)
    
    begin
      # Save the uploaded file without processing
      File.open(local_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end
      
      # Try to use MiniMagick if available
      begin
        # Check if ImageMagick is installed
        image_magick_installed = system("which convert > /dev/null 2>&1")
        
        if image_magick_installed
          # Verify and process the image with MiniMagick
          image = MiniMagick::Image.open(local_path)
          
          # Resize if necessary
          if image.width > 1000 || image.height > 1000
            image.resize "1000x1000>"
          end
          
          # Convert to jpg and set quality
          image.format "jpg"
          image.quality 85
          image.write local_path
        end
      rescue StandardError => e
        # Log the error but continue with the unprocessed image
        Rails.logger.error("MiniMagick error: #{e.message}")
      end
      
      # Update the profile
      new_url = "/uploads/headshots/#{filename}"
      @profile.update(headshot_url: new_url)
      
      flash[:notice] = "Headshot uploaded for #{@profile.name}"
    rescue StandardError => e
      flash[:alert] = "Error processing image: #{e.message}"
      File.delete(local_path) if File.exist?(local_path)
    end
  end
end