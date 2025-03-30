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
      service = YoutubeSummarizerService.new(episode)
      summary = service.call

      if summary
        episode.update!(summary: summary)
        Rails.logger.info "SummarizeYoutubeVideoJob: Successfully updated summary for Episode ##{episode.number}"
      else
        Rails.logger.warn "SummarizeYoutubeVideoJob: Received nil summary for Episode ##{episode.number}. Not updating."
        # Optionally, handle this case, e.g., mark as failed?
      end
    rescue YoutubeSummarizerService::SummarizationError => e
      Rails.logger.error "SummarizeYoutubeVideoJob: Failed to summarize Episode ##{episode.number}: #{e.message}"
      # Optionally re-raise, retry, or notify admins
      # raise e # Uncomment to make the job fail and potentially retry
    rescue => e
      Rails.logger.error "SummarizeYoutubeVideoJob: Unexpected error for Episode ##{episode.number}: #{e.message}\n#{e.backtrace.join("\n")}"
      # Optionally re-raise, retry, or notify admins
      # raise e # Uncomment to make the job fail and potentially retry
    end
  end
end
