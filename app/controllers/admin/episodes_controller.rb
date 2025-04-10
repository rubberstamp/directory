class Admin::EpisodesController < Admin::BaseController
  before_action :set_episode, only: [ :show, :edit, :update, :destroy, :attach_profile, :detach_profile ]
  require "csv"
  require "yt"

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
      redirect_to admin_episode_path(@episode), notice: "Episode was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @episode.update(episode_params)
      redirect_to admin_episode_path(@episode), notice: "Episode was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @episode.destroy
    redirect_to admin_episodes_path, notice: "Episode was successfully destroyed."
  end

  def attach_profile
    profile_id = params[:profile_id]
    is_primary = params[:is_primary] == "1"
    appearance_type = params[:appearance_type].presence || "Guest"

    # Check if profile exists
    profile = Profile.find_by(id: profile_id)

    if profile.nil?
      redirect_to edit_admin_episode_path(@episode), alert: "Profile not found."
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
      redirect_to edit_admin_episode_path(@episode), alert: "Profile association not found."
    end
  end

  def import
    # Check if file was uploaded
    unless params[:file].present?
      redirect_to admin_episodes_path, alert: "Please select a CSV file to import"
      return
    end

    # Check file format
    unless params[:file].content_type == "text/csv"
      redirect_to admin_episodes_path, alert: "Please upload a valid CSV file"
      return
    end

    # Read and encode CSV
    csv_text = params[:file].read.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    begin
      csv = CSV.parse(csv_text, headers: true)
    rescue CSV::MalformedCSVError => e
      redirect_to admin_episodes_path, alert: "CSV parsing error: #{e.message}"
      return
    end

    # Validate headers
    required_columns = [ "Episode Number", "Episode Title", "Video ID" ]
    headers = csv.headers.compact.map(&:strip)
    missing_columns = required_columns - headers
    if missing_columns.any?
      redirect_to admin_episodes_path, alert: "Missing required columns: #{missing_columns.join(', ')}"
      return
    end

    # Process CSV
    created_count = 0
    updated_count = 0
    skipped_count = 0
    guest_count = 0
    errors = []
    update_existing = params[:update_existing] == "1"

    # Use a transaction to ensure data consistency
    ActiveRecord::Base.transaction do
      csv.each_with_index do |row, index|
        begin
          # Skip empty rows
          next if row.values_at(*required_columns).all?(&:blank?)

          # Extract data from row
          video_id = extract_video_id(row["Video ID"])
          number = row["Episode Number"].to_i
          title = row["Episode Title"]

          # Optional fields
          air_date = parse_date(row["Episode Date"]) if row["Episode Date"].present?
          notes = row["Notes"]
          duration_seconds = row["Duration"].to_i if row["Duration"].present?
          thumbnail_url = row["Thumbnail URL"]
          guest_name = row["Guest Name"]

          # Check if episode already exists (by video_id or number)
          existing_by_video = Episode.find_by(video_id: video_id)
          existing_by_number = Episode.find_by(number: number)
          existing_episode = nil
          match_type = nil

          # Determine which existing episode to use
          if existing_by_video && existing_by_number && existing_by_video.id == existing_by_number.id
            # Same episode found by both criteria
            existing_episode = existing_by_video
            match_type = "video_id and number"
          elsif existing_by_video
            # Found by video_id
            existing_episode = existing_by_video
            match_type = "video_id"
          elsif existing_by_number
            # Found by number
            existing_episode = existing_by_number
            match_type = "number"
          end

          if existing_episode && update_existing
            # Update existing episode
            update_data = {}

            # If match is by number only, update video_id too
            if match_type == "number"
              update_data[:video_id] = video_id
            end

            # If match is by video_id only, number might be changing
            if match_type == "video_id" && existing_episode.number != number
              # Check if the new number is already used by another episode
              if Episode.where(number: number).where.not(id: existing_episode.id).exists?
                errors << "Row #{index + 2}: Cannot update episode ##{existing_episode.number} to number #{number} - number already in use"
                skipped_count += 1
                next
              end
              update_data[:number] = number
            end

            # Always update these fields if provided
            update_data[:title] = title
            update_data[:air_date] = air_date if air_date.present?
            update_data[:notes] = notes if notes.present?
            update_data[:duration_seconds] = duration_seconds if duration_seconds.present?
            update_data[:thumbnail_url] = thumbnail_url if thumbnail_url.present?

            if existing_episode.update(update_data)
              updated_count += 1
            else
              errors << "Row #{index + 2}: Failed to update episode ##{existing_episode.number} (matched by #{match_type}): #{existing_episode.errors.full_messages.join(', ')}"
            end

            # Use the existing episode for guest linking
            episode = existing_episode
          elsif existing_episode
            # Skip updating existing episode if update_existing is false
            skipped_count += 1
            next
          else
            # Create new episode
            episode_data = {
              number: number,
              title: title,
              video_id: video_id
            }
            episode_data[:air_date] = air_date if air_date.present?
            episode_data[:notes] = notes if notes.present?
            episode_data[:duration_seconds] = duration_seconds if duration_seconds.present?
            episode_data[:thumbnail_url] = thumbnail_url if thumbnail_url.present?

            episode = Episode.new(episode_data)

            if episode.save
              created_count += 1
            else
              errors << "Row #{index + 2}: Failed to create episode ##{number}: #{episode.errors.full_messages.join(', ')}"
              next
            end
          end

          # Link guest to episode if guest name is provided
          if guest_name.present?
            profile = Profile.find_by("LOWER(name) LIKE LOWER(?)", "%#{guest_name}%")

            if profile.nil?
              errors << "Row #{index + 2}: Profile not found for guest '#{guest_name}'"
            else
              # Check if association already exists
              existing_association = ProfileEpisode.find_by(profile: profile, episode: episode)

              if existing_association.nil?
                # Create new association
                profile_episode = ProfileEpisode.new(
                  profile: profile,
                  episode: episode,
                  appearance_type: "Main Guest",
                  is_primary_guest: true
                )

                if profile_episode.save
                  guest_count += 1
                else
                  errors << "Row #{index + 2}: Failed to link guest '#{guest_name}' to episode ##{episode.number}: #{profile_episode.errors.full_messages.join(', ')}"
                end
              end
            end
          end
        rescue => e
          errors << "Row #{index + 2}: Unexpected error - #{e.message}"
        end
      end
    end

    # Redirect with success/error message
    if errors.any?
      flash[:alert] = "Import completed with #{errors.count} issues. Created: #{created_count}, Updated: #{updated_count}, Skipped: #{skipped_count}, Linked guests: #{guest_count}."
      session[:import_errors] = errors
    else
      flash[:notice] = "Successfully imported episodes. Created: #{created_count}, Updated: #{updated_count}, Skipped: #{skipped_count}, Linked guests: #{guest_count}."
    end

    redirect_to admin_episodes_path
  end

  def template
    # Create a CSV template for download
    csv_data = CSV.generate do |csv|
      csv << [ "Guest Name", "Episode Number", "Episode Title", "Video ID", "Episode Date", "Notes", "Duration", "Thumbnail URL" ]
      # Add a few example rows
      csv << [ "John Doe", "42", "How to Optimize Procurement", "abcd1234xyz", "2025-01-15", "Example notes", "1800", "https://example.com/thumbnail.jpg" ]
      csv << [ "Jane Smith", "43", "Finance Best Practices", "efgh5678abc", "2025-01-22", "More example notes", "2400", "" ]
    end

    send_data csv_data,
              type: "text/csv",
              filename: "episodes_import_template.csv",
              disposition: "attachment"
  end

  def export
    # Get episodes to export (filtered if needed)
    episodes = Episode.all

    # Apply filters if provided
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      episodes = episodes.where(
        "LOWER(title) LIKE ? OR CAST(number AS TEXT) LIKE ?",
        search_term, search_term
      )
    end

    # Sort by number by default
    episodes = episodes.order(number: :asc)

    # Generate CSV
    csv_data = CSV.generate do |csv|
      # Add headers
      csv << [ "Guest Name", "Episode Number", "Episode Title", "Video ID", "Episode Date", "Notes", "Duration", "Thumbnail URL" ]

      # Add episode data
      episodes.each do |episode|
        # Get primary guest name if available
        primary_guest = episode.primary_guest
        guest_name = primary_guest&.name

        # Format data
        row = [
          guest_name,
          episode.number,
          episode.title,
          episode.video_id,
          episode.air_date&.strftime("%Y-%m-%d"),
          episode.notes,
          episode.duration_seconds,
          episode.thumbnail_url
        ]

        csv << row
      end
    end

    # Send file
    send_data csv_data,
              type: "text/csv",
              filename: "episodes_export_#{Date.today.strftime("%Y%m%d")}.csv",
              disposition: "attachment"
  end

  def sync_youtube
    channel_id = params[:channel_id] || SyncYoutubeChannelJob::PROCUREMENT_CHANNEL_ID
    max_videos = (params[:max_videos] || 25).to_i
    update_existing = params[:update_existing] != "false"

    options = {
      max_videos: max_videos,
      update_existing: update_existing,
      sync_thumbnails: true
    }

    # Queue the job to run in the background
    if params[:run_now] == "true"
      # Run synchronously for immediate feedback
      begin
        stats = SyncYoutubeChannelJob.perform_now(channel_id, options)
        flash[:notice] = "YouTube sync completed! Created: #{stats[:created]}, Updated: #{stats[:updated]}, Skipped: #{stats[:skipped]}, Errors: #{stats[:errors]}"
      rescue => e
        flash[:alert] = "Error syncing YouTube channel: #{e.message}"
        Rails.logger.error "YouTube sync error: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    else
      # Run asynchronously
      SyncYoutubeChannelJob.perform_later(channel_id, options)
      flash[:notice] = "YouTube sync job has been queued and will run in the background."
    end

    redirect_to admin_episodes_path
  end

  def summarize
    @episode = Episode.find(params[:id])

    # Check if video_id is present
    if @episode.video_id.blank?
      redirect_to admin_episode_path(@episode), alert: "Cannot summarize: Episode ##{@episode.number} has no video ID."
      return
    end

    # Check if it's a placeholder
    if @episode.video_id.start_with?("EP")
      redirect_to admin_episode_path(@episode), alert: "Cannot summarize: Episode ##{@episode.number} has a placeholder video ID (#{@episode.video_id})."
      return
    end

    # Extract and validate the video ID
    video_id = extract_video_id(@episode.video_id)
    if video_id.nil? || video_id.length != 11
      redirect_to admin_episode_path(@episode), alert: "Cannot summarize: Episode ##{@episode.number} has an invalid YouTube video ID format (#{@episode.video_id})."
      return
    end

    # Queue the summarization job
    @episode.summarize_later
    redirect_to admin_episode_path(@episode), notice: "Summarization job queued for Episode ##{@episode.number} with video ID #{video_id}."
  end

  private
    # Extract the video ID from various YouTube URL formats
    def extract_video_id(input)
      return nil if input.blank?

      # Clean up the input
      input = input.strip

      # If it's already a clean video ID (11 characters) with no URL components
      if input.length == 11 && !input.include?("/") && !input.include?(":") && !input.include?(".")
        return input
      end

      # Try various methods to extract the ID

      # Method 1: Standard watch URLs
      if input.include?("youtube.com/watch?v=")
        match = input.match(/youtube\.com\/watch\?v=([^&]{11})/)
        if match && match[1]
          return match[1]
        end
      end

      # Method 2: Shortened youtu.be URLs
      if input.include?("youtu.be/")
        match = input.match(/youtu\.be\/([^?&\/]{11})/)
        if match && match[1]
          return match[1]
        end
      end

      # Method 3: Embed URLs
      if input.include?("youtube.com/embed/")
        match = input.match(/youtube\.com\/embed\/([^?&\/]{11})/)
        if match && match[1]
          return match[1]
        end
      end

      # Method 4: General regex for any URL format (fallback)
      if input.match?(/\A(https?:\/\/)/)
        regex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/
        match = input.match(regex)
        if match && match[1]
          return match[1]
        end
      end

      # If all extraction methods fail but input is 11 characters, it might be an ID
      if input.length == 11
        return input
      end

      # Return nil to indicate failure
      nil
    end

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
        :thumbnail_url,
        :summary # Allow summary to be updated via form if needed
      )
    end

    def extract_video_id(input)
      # Return as-is if it's already a clean video ID
      return input if input.length == 11 && !input.include?("/")

      # Extract from YouTube URL
      if input.match?(/\A(https?:\/\/)/)
        video_id_match = input.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)&.captures&.first
        return video_id_match if video_id_match
      end

      # Return the input as fallback
      input
    end

    def parse_date(date_string)
      begin
        Date.parse(date_string)
      rescue ArgumentError
        # Return nil if date can't be parsed
        nil
      end
    end
end
