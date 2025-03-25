class YoutubeVideo
  include ActiveModel::Model
  attr_accessor :id, :title, :description, :thumbnail_url, :published_at, :channel_title
  
  # Find a YouTube video by ID
  def self.find(video_id)
    video = Yt::Video.new(id: video_id)
    
    new(
      id: video.id,
      title: video.title,
      description: video.description,
      thumbnail_url: video.thumbnail_url,
      published_at: video.published_at,
      channel_title: video.channel_title
    )
  rescue Yt::Errors::NoItems => e
    Rails.logger.error "YouTube video not found: #{e.message}"
    nil
  rescue => e
    Rails.logger.error "Error fetching YouTube video: #{e.message}"
    nil
  end
  
  # Search YouTube videos
  def self.search(query, max_results: 10)
    videos = Yt::Collections::Videos.new.where(
      q: query,
      order: 'relevance', 
      max_results: max_results
    )
    
    videos.map do |video|
      new(
        id: video.id,
        title: video.title,
        description: video.description,
        thumbnail_url: video.thumbnail_url,
        published_at: video.published_at,
        channel_title: video.channel_title
      )
    end
  rescue => e
    Rails.logger.error "Error searching YouTube videos: #{e.message}"
    []
  end
  
  # Get video duration in a readable format
  def duration
    video = Yt::Video.new(id: id)
    format_duration(video.duration)
  rescue => e
    nil
  end
  
  # Format ISO 8601 duration to readable format
  private
  
  def format_duration(seconds)
    return nil unless seconds
    
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    seconds = seconds % 60
    
    if hours > 0
      "%d:%02d:%02d" % [hours, minutes, seconds]
    else
      "%d:%02d" % [minutes, seconds]
    end
  end
end