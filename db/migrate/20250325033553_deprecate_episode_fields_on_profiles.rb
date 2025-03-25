class DeprecateEpisodeFieldsOnProfiles < ActiveRecord::Migration[8.0]
  def up
    # We'll keep these columns but rename them to make it clear they're deprecated
    rename_column :profiles, :episode_number, :deprecated_episode_number
    rename_column :profiles, :episode_title, :deprecated_episode_title
    rename_column :profiles, :episode_url, :deprecated_episode_url
    rename_column :profiles, :episode_date, :deprecated_episode_date
    
    # Add a migration note
    puts "MIGRATION NOTE: Old episode fields have been renamed with 'deprecated_' prefix."
    puts "Please migrate data using the 'podcast:migrate_episode_data' rake task."
  end
  
  def down
    # Restore original column names if rolling back
    rename_column :profiles, :deprecated_episode_number, :episode_number
    rename_column :profiles, :deprecated_episode_title, :episode_title
    rename_column :profiles, :deprecated_episode_url, :episode_url
    rename_column :profiles, :deprecated_episode_date, :episode_date
  end
end
