# frozen_string_literal: true

# Handles advertising-related functionality for profiles
# Used for generating ad feeds (Google Ads, etc.)
module Advertisable
  extend ActiveSupport::Concern

  included do
    scope :active_for_ads, -> { where(active_for_ads: true) }
  end

  # Returns a URL suitable for ad feeds for the profile image.
  # Prefers ActiveStorage attachment if present, falling back to legacy headshot_url.
  def ad_image_url
    if headshot.attached?
      Rails.application.routes.url_helpers.url_for(headshot)
    elsif headshot_url.present?
      headshot_url
    else
      ActionController::Base.helpers.asset_url("podcast_placeholder.jpg")
    end
  rescue StandardError
    nil
  end

  # Returns the final URL for ad click-through
  def ad_final_url
    host = resolve_ad_host

    if respond_to?(:slug) && slug.present?
      Rails.application.routes.url_helpers.profile_url(slug, host: host, utm_source: "googleads")
    else
      Rails.application.routes.url_helpers.profile_url(id, host: host, utm_source: "googleads")
    end
  end

  # Returns specializations formatted for ad feeds
  def ad_specializations
    if respond_to?(:specializations) && specializations.any?
      specializations.pluck(:name).join(", ")
    else
      self[:specializations].to_s
    end
  end

  private

  def resolve_ad_host
    host = "example.com"

    if Rails.application.config.x.respond_to?(:default_host) && Rails.application.config.x.default_host.present?
      host = Rails.application.config.x.default_host
    elsif Rails.application.routes.default_url_options[:host].present?
      host = Rails.application.routes.default_url_options[:host]
    elsif ENV["DEFAULT_HOST"].present?
      host = ENV["DEFAULT_HOST"]
    end

    host.to_s
  end
end
