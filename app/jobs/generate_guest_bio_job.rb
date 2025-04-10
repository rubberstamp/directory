# frozen_string_literal: true

class GenerateGuestBioJob < ApplicationJob
  queue_as :default

  # Discard job if Profile record is not found
  discard_on ActiveJob::DeserializationError

  def perform(profile_id)
    profile = Profile.find_by(id: profile_id)
    unless profile
      Rails.logger.warn "GenerateGuestBioJob: Profile with ID #{profile_id} not found. Skipping."
      return
    end

    # Skip if the profile already has a bio
    if profile.bio.present?
      Rails.logger.info "GenerateGuestBioJob: Profile #{profile.name} (ID: #{profile_id}) already has a bio. Skipping."
      return
    end

    Rails.logger.info "GenerateGuestBioJob: Starting bio generation for #{profile.name} (ID: #{profile_id})"

    begin
      # Initialize service
      service = GuestBioGeneratorService.new(profile)

      # Call the service to get a bio
      Rails.logger.info "GenerateGuestBioJob: Calling bio generator for #{profile.name}"
      bio = service.call

      # Process the result
      if bio
        # Update the profile with the new bio
        profile.update!(bio: bio)
        Rails.logger.info "GenerateGuestBioJob: Successfully updated bio for #{profile.name}"
        Rails.logger.debug "GenerateGuestBioJob: Bio content (first 100 chars): #{bio[0..100]}..."
      else
        Rails.logger.warn "GenerateGuestBioJob: Received nil bio for #{profile.name}. Not updating."
      end
    rescue GuestBioGeneratorService::BioGenerationError => e
      Rails.logger.error "GenerateGuestBioJob: Failed to generate bio for #{profile.name}: #{e.message}"

      # We don't update the existing bio in case of error - we keep the current one
    rescue => e
      Rails.logger.error "GenerateGuestBioJob: Unexpected error for #{profile.name}: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end
