class AddPodcastEpisodeDetailsToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :episode_number, :integer
    add_column :profiles, :episode_title, :string
    add_column :profiles, :episode_url, :string
    add_column :profiles, :episode_date, :date
  end
end
