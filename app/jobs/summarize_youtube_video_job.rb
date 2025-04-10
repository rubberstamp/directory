# frozen_string_literal: true

class SummarizeYoutubeVideoJob < ApplicationJob
  queue_as :default

  # Discard job if Episode record is not found
  discard_on ActiveJob::DeserializationError

  def perform(episode_id)
    episode = Episode.find_by(id: episode_id)
    unless episode
      Rails.logger.warn "SummarizeYoutubeVideoJob: Episode with ID #{episode_id} not found. Skipping."
      return
    end

    Rails.logger.info "SummarizeYoutubeVideoJob: Starting summarization for Episode ##{episode.number} (ID: #{episode_id})"

    begin
      # Log the video ID that we're working with
      Rails.logger.info "SummarizeYoutubeVideoJob: Processing Episode ##{episode.number} with video_id: #{episode.video_id.inspect}"

      # Initialize service with more debugging
      service = YoutubeSummarizerService.new(episode)

      # Call the service to get a summary
      Rails.logger.info "SummarizeYoutubeVideoJob: Calling YouTube summarizer for Episode ##{episode.number}"
      summary = service.call

      # Process the result
      if summary
        # Update the episode with the summary
        episode.update!(summary: summary)
        Rails.logger.info "SummarizeYoutubeVideoJob: Successfully updated summary for Episode ##{episode.number}"
        Rails.logger.debug "SummarizeYoutubeVideoJob: Summary content (first 100 chars): #{summary[0..100]}..."
      else
        Rails.logger.warn "SummarizeYoutubeVideoJob: Received nil summary for Episode ##{episode.number}. Not updating."
        # Create an admin notification or flag in the database?
      end
    rescue YoutubeSummarizerService::SummarizationError => e
      Rails.logger.error "SummarizeYoutubeVideoJob: Failed to summarize Episode ##{episode.number}: #{e.message}"

      # Store the error in the episode record if possible
      begin
        # Add an admin note about the failure
        episode.update(
          summary: "Summarization failed: #{e.message}. Please try again or edit manually."
        )
      rescue => update_error
        Rails.logger.error "SummarizeYoutubeVideoJob: Also failed to update episode with error message: #{update_error.message}"
      end
    rescue => e
      Rails.logger.error "SummarizeYoutubeVideoJob: Unexpected error for Episode ##{episode.number}: #{e.message}\n#{e.backtrace.join("\n")}"

      # Store the error in the episode record if possible
      begin
        # Add an admin note about the failure
        episode.update(
          summary: "Summarization failed with unexpected error. Please check logs and try again."
        )
      rescue => update_error
        Rails.logger.error "SummarizeYoutubeVideoJob: Also failed to update episode with error message: #{update_error.message}"
      end
    end
  end
end
