# frozen_string_literal: true

class Profile < ApplicationRecord
  # Include concerns for better code organization
  include MessagePreferences
  include Advertisable
  include ImageAttachable
  include PodcastAppearances
  include Geocodable

  # Associations
  has_many :profile_specializations, dependent: :destroy
  has_many :specializations, through: :profile_specializations

  # Validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :validate_website_if_present

  # Scopes for filtering
  scope :guests, -> { where(status: "guest") }
  scope :partners, -> { where(partner: true) }
  scope :podcast_guests, -> { where.not(submission_date: nil) }
  scope :interested_in_procurement, -> { where(interested_in_procurement: true) }
  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }

  # Name search scope - searches by guest name
  scope :search_by_name, ->(query) {
    return all if query.blank?
    where("name LIKE :q", q: "%#{query}%")
  }

  # Location search scope - searches location, cached_city, and cached_country
  scope :in_location, ->(query) {
    where("location LIKE :q OR cached_city LIKE :q OR cached_country LIKE :q", q: "%#{query}%")
  }

  # Filter by specialization
  scope :with_specialization, ->(specialization_id) {
    return all if specialization_id.blank? || specialization_id.to_i <= 0
    joins(:profile_specializations)
      .where(profile_specializations: { specialization_id: specialization_id })
      .distinct
  }

  # Filter by guest type
  scope :filtered_by_guest_type, ->(filter) {
    case filter
    when "partners" then partners
    when "podcast_guests" then podcast_guests
    when "procurement" then interested_in_procurement
    else all
    end
  }

  # Default ordering for listings
  scope :default_order, -> { order(partner: :desc, name: :asc) }

  # Generate an AI bio for this profile based on their podcast appearances
  # Only generates if the profile has no existing bio
  def generate_ai_bio
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

  private

  def validate_website_if_present
    return if website.blank?

    if website.match?(/\A(https?:\/\/)/)
      begin
        uri = URI.parse(website)
        errors.add(:website, "must be a valid URL") unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError
        errors.add(:website, "must be a valid URL")
      end
    end
  end
end
