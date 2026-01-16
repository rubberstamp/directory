# frozen_string_literal: true

# Handles podcast episode associations and related queries
module PodcastAppearances
  extend ActiveSupport::Concern

  YOUTUBE_CHANNEL_URL = "https://www.youtube.com/@procurementexpress9417/videos"

  included do
    has_many :profile_episodes, dependent: :destroy
    has_many :episodes, through: :profile_episodes
  end

  # Get all episodes ordered by air date (most recent first)
  def episodes_by_date
    episodes.order(air_date: :desc)
  end

  # Get main episodes where this profile is the primary guest
  def primary_guest_episodes
    profile_episodes.where(is_primary_guest: true).includes(:episode).map(&:episode)
  end

  # Get panel/co-host episodes where this profile is not the primary guest
  def secondary_appearances
    profile_episodes.where(is_primary_guest: false).includes(:episode)
  end

  # Get the most recent episode featuring this guest
  def latest_episode
    episodes_by_date.first
  end

  # Get the profile_episode join record for a specific episode
  def appearance_on(episode)
    profile_episodes.find_by(episode: episode)
  end

  # DEPRECATED: These methods are kept for backward compatibility
  # They will be removed in a future version

  # DEPRECATED: Returns formatted episode URL from legacy field
  def formatted_episode_url
    return nil if self[:deprecated_episode_url].blank?

    if self[:deprecated_episode_url].match?(/\A(https?:\/\/)/)
      self[:deprecated_episode_url]
    else
      "https://www.youtube.com/watch?v=#{self[:deprecated_episode_url]}"
    end
  end

  # DEPRECATED: Returns embed URL from legacy field
  def episode_embed_url
    return nil if self[:deprecated_episode_url].blank?

    if self[:deprecated_episode_url].match?(/\A(https?:\/\/)/)
      video_id = self[:deprecated_episode_url].match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)&.captures&.first
      return "https://www.youtube.com/embed/#{video_id}" if video_id
    else
      return "https://www.youtube.com/embed/#{self[:deprecated_episode_url]}"
    end

    nil
  end

  # DEPRECATED: Checks if profile has any podcast episode
  def has_podcast_episode?
    return true if self[:deprecated_episode_url].present? ||
                   self[:deprecated_episode_number].present? ||
                   self[:deprecated_episode_title].present?
    episodes.any?
  end
end
