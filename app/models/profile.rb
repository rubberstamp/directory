class Profile < ApplicationRecord
  has_many :profile_specializations, dependent: :destroy
  has_many :specializations, through: :profile_specializations
  
  has_many :profile_episodes, dependent: :destroy
  has_many :episodes, through: :profile_episodes
  
  has_many :guest_messages, dependent: :nullify
  
  has_one_attached :headshot
  
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  # Don't validate social media URLs
  # Instead of validating URLs, we'll handle the formatting in the import process
  # This will allow us to import profiles with non-standard URL formats
  
  # Only validate website if it's not blank and looks like a URL
  validate :validate_website_if_present
  
  # Geocoding for map functionality
  geocoded_by :full_address
  
  # Skip geocoding flag for use by the background job
  attr_accessor :skip_geocoding
  
  # Queue background job for geocoding instead of doing it synchronously
  after_validation :queue_geocoding, if: ->(obj) { !obj.skip_geocoding && (obj.location_changed? || obj.mailing_address_changed?) }
  
  # Store city and country in database to avoid geocoding on read
  before_save :store_city_and_country, if: ->(obj) { !obj.skip_geocoding && (obj.latitude_changed? || obj.longitude_changed?) }
  
  def store_city_and_country
    # Only perform geocoding if we have coordinates but no cached city/country
    if latitude.present? && longitude.present? && (cached_city.blank? || cached_country.blank?)
      begin
        result = Geocoder.search([latitude, longitude]).first
        if result && result.address.is_a?(Hash)
          self.cached_city = result.address['city'] if result.address['city'].present?
          self.cached_country = result.address['country'] if result.address['country'].present?
        elsif result && result.address.is_a?(String)
          address_parts = result.address.split(', ')
          if address_parts.size >= 2
            self.cached_city = address_parts[-3] # Often city is 3rd from the end
            self.cached_country = address_parts[-1] # Country is usually last
          end
        end
      rescue => e
        Rails.logger.error "Error geocoding for location cache (profile #{id}): #{e.message}"
      end
    end
  end
  
  # YouTube channel URL
  YOUTUBE_CHANNEL_URL = "https://www.youtube.com/@procurementexpress9417/videos"
  
  # DEPRECATED: These methods are deprecated but kept for backward compatibility
  # They will be removed in a future version
  def formatted_episode_url
    return nil if self[:deprecated_episode_url].blank?
    
    # If the URL is already a full URL, return it
    return self[:deprecated_episode_url] if self[:deprecated_episode_url].match?(/\A(https?:\/\/)/)
    
    # Otherwise, assume it's a video ID and build the URL
    "https://www.youtube.com/watch?v=#{self[:deprecated_episode_url]}"
  end
  
  # DEPRECATED: will be removed in a future version
  def episode_embed_url
    return nil if self[:deprecated_episode_url].blank?
    
    # Extract video ID from URL if it's a full URL
    if self[:deprecated_episode_url].match?(/\A(https?:\/\/)/)
      video_id = self[:deprecated_episode_url].match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)&.captures&.first
      return "https://www.youtube.com/embed/#{video_id}" if video_id
    else
      # Assume deprecated_episode_url is just the video ID
      return "https://www.youtube.com/embed/#{self[:deprecated_episode_url]}"
    end
    
    nil
  end
  
  # DEPRECATED: will be removed in a future version
  def has_podcast_episode?
    # Check for legacy fields first
    return true if self[:deprecated_episode_url].present? || 
                   self[:deprecated_episode_number].present? || 
                   self[:deprecated_episode_title].present?
    
    # Then check for new association
    episodes.any?
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
  
  # Get a full address for geocoding
  # Prioritize location field over mailing address to avoid mixed-location issues
  def full_address
    # If location is present, use it exclusively for mapping purposes
    return location if location.present?
    
    # Otherwise fall back to mailing address
    mailing_address
  end
  
  # Get formatted location using geocoding data
  def formatted_location
    # First try to use the cached city and country
    if cached_city.present? && cached_country.present?
      return "#{cached_city}, #{cached_country}"
    elsif cached_city.present?
      return cached_city
    elsif cached_country.present?
      return cached_country
    end
    
    # If no cached values, calculate it and store in memory
    @formatted_location ||= calculate_formatted_location
  end
  
  # Class method to get profiles with images (headshots or image_url)
  def self.with_images
    # When using OR with ActiveRecord, both sides need to have the same structure
    # Including the same joins and where conditions
    
    # Profiles with headshot_url or image_url
    with_url_images = where("headshot_url IS NOT NULL OR image_url IS NOT NULL")
    
    # Profiles with ActiveStorage attachments
    with_attached_images = 
      joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = profiles.id 
            AND active_storage_attachments.record_type = 'Profile' 
            AND active_storage_attachments.name = 'headshot'")
    
    # Return the union of both queries
    with_url_images.or(with_attached_images)
  end
  
  # Get headshot URL (supports both legacy headshot_url and ActiveStorage)
  def headshot_url_or_attached
    # Return attached headshot if it exists
    return Rails.application.routes.url_helpers.rails_blob_path(headshot, only_path: true) if headshot.attached?
    
    # Otherwise return the legacy URL
    headshot_url
  end
  
  # Returns the email to use for message forwarding
  def effective_forwarding_email
    # Use the dedicated forwarding email if present
    return message_forwarding_email if message_forwarding_email.present?
    
    # Fall back to the primary email address
    email
  end
  
  # Calculate the formatted location (city and country)
  def calculate_formatted_location
    # If we have cached_city and cached_country, use those
    if cached_city.present? && cached_country.present?
      return "#{cached_city}, #{cached_country}"
    elsif cached_city.present?
      return cached_city
    elsif cached_country.present?
      return cached_country
    end
    
    # If we have lat/lng but no cached city/country, try to get them once
    if latitude.present? && longitude.present? && (cached_city.blank? && cached_country.blank?)
      # Try to get geocoded location data
      begin
        result = Geocoder.search([latitude, longitude]).first
        if result
          # Check if we have an address hash with city and country
          if result.address.is_a?(Hash) && result.address['city'].present? && result.address['country'].present?
            self.cached_city = result.address['city']
            self.cached_country = result.address['country']
            return "#{cached_city}, #{cached_country}"
          # Check if we have an address hash with just city
          elsif result.address.is_a?(Hash) && result.address['city'].present?
            self.cached_city = result.address['city']
            return cached_city
          # Check if we have an address hash with just country
          elsif result.address.is_a?(Hash) && result.address['country'].present?
            self.cached_country = result.address['country']
            return cached_country
          # If address is a string, extract city and country if possible
          elsif result.address.is_a?(String)
            address_parts = result.address.split(', ')
            # Try to get city and country from the address string
            if address_parts.size >= 2
              self.cached_city = address_parts[-3] # Often city is 3rd from the end
              self.cached_country = address_parts[-1] # Country is usually last
              return "#{cached_city}, #{cached_country}"
            end
          end
          # Save the cached values if we looked them up
          self.save if self.changed?
        end
      rescue => e
        # Log error but continue with fallback
        Rails.logger.error "Error geocoding location for profile #{id}: #{e.message}"
      end
    end
    
    # Fallback to the location field if geocoding failed or wasn't attempted
    return location if location.present?
    
    # Don't show any address if we can't extract city and country
    nil
  end
  
  private
  
  def validate_website_if_present
    return if website.blank?
    
    # Only validate if it starts with http:// or https://
    if website.match?(/\A(https?:\/\/)/)
      begin
        uri = URI.parse(website)
        errors.add(:website, "must be a valid URL") unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError
        errors.add(:website, "must be a valid URL")
      end
    end
  end
  
  # Queue geocoding as a background job
  def queue_geocoding
    # Skip if we already have coordinates and they haven't changed
    return if latitude.present? && longitude.present? && 
              !latitude_changed? && !longitude_changed? &&
              !location_changed? && !mailing_address_changed?
    
    # Only queue if we have an ID (not a new record being created)
    if persisted?
      GeocodeProfileJob.perform_later(id)
    else
      # For new records, we'll queue after they're saved
      @queue_geocoding_after_create = true
    end
  end
  
  # Queue geocoding after create
  after_create :queue_geocoding_on_create
  
  def queue_geocoding_on_create
    if @queue_geocoding_after_create && full_address.present?
      GeocodeProfileJob.perform_later(id)
      @queue_geocoding_after_create = false
    end
  end
  
  # Generate an AI bio for this profile based on their podcast appearances
  # Only generates if the profile has no existing bio
  def generate_ai_bio
    # Only generate if the profile has podcast episodes and no existing bio
    if episodes.any? && bio.blank?
      GenerateGuestBioJob.perform_later(id)
      true
    else
      false
    end
  end
  
  # Queue the bio generation job to run later
  # Only queues if the profile has no existing bio
  def generate_ai_bio_later
    if bio.blank?
      GenerateGuestBioJob.perform_later(id)
      true
    else
      false
    end
  end
end