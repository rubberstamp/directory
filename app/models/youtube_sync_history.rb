class YoutubeSyncHistory < ApplicationRecord
  validates :channel_id, presence: true, uniqueness: true

  # Get or create history entry for a channel
  def self.for_channel(channel_id)
    find_or_create_by(channel_id: channel_id) do |history|
      history.videos_processed = 0
    end
  end

  # Update the sync history after a successful sync
  def update_after_sync(videos_processed)
    self.last_synced_at = Time.current
    self.videos_processed += videos_processed
    save!
  end
end
