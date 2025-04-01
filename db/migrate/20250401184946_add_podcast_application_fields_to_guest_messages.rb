class AddPodcastApplicationFieldsToGuestMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :guest_messages, :location, :string
    add_column :guest_messages, :practice_size, :string
    add_column :guest_messages, :specialty, :string
    add_column :guest_messages, :is_podcast_application, :boolean, default: false
  end
end