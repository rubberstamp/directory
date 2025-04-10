class ProfileEpisode < ApplicationRecord
  belongs_to :profile
  belongs_to :episode

  validates :profile_id, uniqueness: { scope: :episode_id, message: "can only appear once per episode" }

  # Appearance types
  APPEARANCE_TYPES = [
    "Main Guest",
    "Co-Host",
    "Panel Member",
    "Special Guest",
    "Expert Commentary",
    "Interview Subject"
  ]

  # Get the segment time in MM:SS format
  def segment_start_formatted
    return nil unless segment_start_time
    minutes = segment_start_time / 60
    seconds = segment_start_time % 60
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end

  def segment_end_formatted
    return nil unless segment_end_time
    minutes = segment_end_time / 60
    seconds = segment_end_time % 60
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end

  # Get the segment timestamp for YouTube (for linking directly to the segment)
  def segment_youtube_timestamp
    return nil unless segment_start_time
    "t=#{segment_start_time}s"
  end

  # Get the complete YouTube URL with timestamp
  def segment_youtube_url
    return nil unless episode&.youtube_url && segment_start_time
    "#{episode.youtube_url}&#{segment_youtube_timestamp}"
  end
end
