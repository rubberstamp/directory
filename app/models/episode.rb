class Episode < ApplicationRecord
  has_many :profile_episodes, dependent: :destroy
  has_many :profiles, through: :profile_episodes
  
  validates :number, presence: true, uniqueness: true
  validates :title, presence: true
  validates :video_id, presence: true, uniqueness: true
  
  # YouTube channel URL
  YOUTUBE_CHANNEL_URL = "https://www.youtube.com/@procurementexpress9417/videos"
  
  # Format YouTube URL for viewing
  def youtube_url
    return nil if video_id.blank?
    
    # If it's a placeholder ID (starting with EP), return nil
    return nil if video_id.start_with?("EP")
    
    # If it's already a full URL, return it
    return video_id if video_id.match?(/\A(https?:\/\/)/)
    
    # Otherwise, assume it's a video ID and build the URL
    "https://www.youtube.com/watch?v=#{video_id}"
  end
  
  # Generate YouTube embed URL
  def embed_url
    return nil if video_id.blank?
    
    # If it's a placeholder ID (starting with EP), return nil
    return nil if video_id.start_with?("EP")
    
    # Extract video ID from URL if it's a full URL
    if video_id.match?(/\A(https?:\/\/)/)
      video_id_match = video_id.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)&.captures&.first
      return "https://www.youtube.com/embed/#{video_id_match}" if video_id_match
    else
      # Assume video_id is just the video ID
      return "https://www.youtube.com/embed/#{video_id}"
    end
    
    nil
  end
  
  # Find the primary guest for this episode
  def primary_guest
    profile_episodes.find_by(is_primary_guest: true)&.profile
  end
  
  # Return formatted duration
  def duration_formatted
    return nil unless duration_seconds
    
    minutes = duration_seconds / 60
    seconds = duration_seconds % 60
    
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end
  
  # Fetch YouTube video data
  def fetch_youtube_data
    return false if video_id.blank? || video_id.start_with?("EP")
    
    begin
      yt_video = Yt::Video.new(id: clean_video_id)
      
      # Update episode with YouTube data
      self.title = yt_video.title if self.title.blank?
      self.duration_seconds = yt_video.duration
      self.notes = yt_video.description if self.notes.blank?
      self.thumbnail_url = yt_video.thumbnail_url(:high)
      
      save
      return true
    rescue Yt::Errors::NoItems => e
      Rails.logger.error "YouTube video not found: #{e.message}"
      return false
    rescue => e
      Rails.logger.error "Error fetching YouTube data: #{e.message}"
      return false
    end
  end
  
  def thumbnail_url_or_default
    if thumbnail_url.present?
      thumbnail_url
    elsif video_id.start_with?("EP")
      # Use a placeholder image for non-YouTube episodes
      "/images/podcast_placeholder.jpg"
    else 
      "https://img.youtube.com/vi/#{clean_video_id}/maxresdefault.jpg"
    end
  end
  
  private
  
  def clean_video_id
    # Return a default ID for placeholder video IDs
    return "dQw4w9WgXcQ" if video_id.start_with?("EP")
    
    if video_id.match?(/\A(https?:\/\/)/)
      video_id.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)&.captures&.first || video_id
    else
      video_id
    end
  end
end
