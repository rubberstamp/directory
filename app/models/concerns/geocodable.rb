# frozen_string_literal: true

# Handles geocoding functionality for mapping profiles
module Geocodable
  extend ActiveSupport::Concern

  included do
    geocoded_by :full_address

    # Skip geocoding flag for use by the background job
    attr_accessor :skip_geocoding

    # Queue background job for geocoding instead of doing it synchronously
    after_validation :queue_geocoding, if: ->(obj) {
      !obj.skip_geocoding && (obj.location_changed? || obj.mailing_address_changed?)
    }

    # Store city and country in database to avoid geocoding on read
    before_save :store_city_and_country, if: ->(obj) {
      !obj.skip_geocoding && (obj.latitude_changed? || obj.longitude_changed?)
    }

    # Queue geocoding after create for new records
    after_create :queue_geocoding_on_create
  end

  # Get a full address for geocoding
  # Prioritize location field over mailing address to avoid mixed-location issues
  def full_address
    return location if location.present?
    mailing_address
  end

  # Get formatted location using cached geocoding data
  def formatted_location
    if cached_city.present? && cached_country.present?
      return "#{cached_city}, #{cached_country}"
    elsif cached_city.present?
      return cached_city
    elsif cached_country.present?
      return cached_country
    end

    @formatted_location ||= calculate_formatted_location
  end

  # Calculate the formatted location (city and country)
  def calculate_formatted_location
    if cached_city.present? && cached_country.present?
      return "#{cached_city}, #{cached_country}"
    elsif cached_city.present?
      return cached_city
    elsif cached_country.present?
      return cached_country
    end

    # If we have lat/lng but no cached city/country, try to get them once
    if latitude.present? && longitude.present? && cached_city.blank? && cached_country.blank?
      fetch_and_cache_location
    end

    # Fallback to the location field if geocoding failed or wasn't attempted
    return location if location.present?
    nil
  end

  # Store city and country from reverse geocoding
  def store_city_and_country
    return unless latitude.present? && longitude.present?
    return if cached_city.present? && cached_country.present?

    begin
      result = Geocoder.search([latitude, longitude]).first
      extract_city_and_country_from_result(result)
    rescue => e
      Rails.logger.error "Error geocoding for location cache (profile #{id}): #{e.message}"
    end
  end

  private

  def queue_geocoding
    return if latitude.present? && longitude.present? &&
              !latitude_changed? && !longitude_changed? &&
              !location_changed? && !mailing_address_changed?

    if persisted?
      GeocodeProfileJob.perform_later(id)
    else
      @queue_geocoding_after_create = true
    end
  end

  def queue_geocoding_on_create
    if @queue_geocoding_after_create && full_address.present?
      GeocodeProfileJob.perform_later(id)
      @queue_geocoding_after_create = false
    end
  end

  def fetch_and_cache_location
    result = Geocoder.search([latitude, longitude]).first
    return unless result

    extract_city_and_country_from_result(result)

    if cached_city.present? && cached_country.present?
      save if changed?
      return "#{cached_city}, #{cached_country}"
    elsif cached_city.present?
      save if changed?
      return cached_city
    elsif cached_country.present?
      save if changed?
      return cached_country
    end

    nil
  rescue => e
    Rails.logger.error "Error geocoding location for profile #{id}: #{e.message}"
    nil
  end

  def extract_city_and_country_from_result(result)
    return unless result

    if result.address.is_a?(Hash)
      self.cached_city = result.address["city"] if result.address["city"].present?
      self.cached_country = result.address["country"] if result.address["country"].present?
    elsif result.address.is_a?(String)
      address_parts = result.address.split(", ")
      if address_parts.size >= 2
        self.cached_city = address_parts[-3]
        self.cached_country = address_parts[-1]
      end
    end
  end
end
