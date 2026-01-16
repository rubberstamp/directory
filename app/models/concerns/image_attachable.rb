# frozen_string_literal: true

# Handles image/headshot attachments and legacy URL support
module ImageAttachable
  extend ActiveSupport::Concern

  included do
    has_one_attached :headshot
  end

  class_methods do
    # Get profiles with images (headshots or image_url)
    def with_images
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
  end

  # Get headshot URL (supports both legacy headshot_url and ActiveStorage)
  def headshot_url_or_attached
    return Rails.application.routes.url_helpers.rails_blob_path(headshot, only_path: true) if headshot.attached?
    headshot_url
  end
end
