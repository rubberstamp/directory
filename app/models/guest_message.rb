class GuestMessage < ApplicationRecord
  belongs_to :profile, optional: true
  
  validates :sender_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true
  
  # Only validate these fields when it's a podcast application
  with_options if: :is_podcast_application? do |app|
    app.validates :location, presence: true
    app.validates :specialty, presence: true
    app.validates :practice_size, presence: true
  end
  
  # Define status constants
  STATUSES = {
    new: 'new',
    read: 'read',
    forwarded: 'forwarded',
    replied: 'replied',
    archived: 'archived'
  }
  
  # Scopes for filtering
  scope :new_messages, -> { where(status: STATUSES[:new]) }
  scope :read_messages, -> { where(status: STATUSES[:read]) }
  scope :forwarded_messages, -> { where(status: STATUSES[:forwarded]) }
  scope :for_guest, ->(profile_id) { where(profile_id: profile_id) }
  scope :general_inquiries, -> { where(profile_id: nil) }
  
  def new?
    status == STATUSES[:new]
  end
  
  def mark_as_read!
    update(status: STATUSES[:read])
  end
  
  def mark_as_forwarded!
    update(status: STATUSES[:forwarded], forwarded_at: Time.current)
  end
  
  def guest_name
    profile&.name || "General Inquiry"
  end
  
  def forward_manually
    return false unless can_be_forwarded?
    true
  end
  
  def can_be_forwarded?
    profile && profile.allow_messages? && profile.message_forwarding_email.present?
  end
  
  def is_podcast_application?
    is_podcast_application
  end
end
