class CreateYoutubeSyncHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :youtube_sync_histories do |t|
      t.string :channel_id
      t.datetime :last_synced_at
      t.integer :videos_processed

      t.timestamps
    end
  end
end
