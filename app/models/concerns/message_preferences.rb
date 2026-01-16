# frozen_string_literal: true

# Handles guest message relationships and forwarding preferences
module MessagePreferences
  extend ActiveSupport::Concern

  included do
    has_many :guest_messages, dependent: :nullify
  end

  # Returns the email to use for message forwarding
  # Uses dedicated forwarding email if set, otherwise falls back to primary email
  def effective_forwarding_email
    return message_forwarding_email if message_forwarding_email.present?
    email
  end
end
