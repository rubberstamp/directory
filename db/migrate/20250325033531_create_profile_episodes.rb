class CreateProfileEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_episodes do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :episode, null: false, foreign_key: true
      t.string :appearance_type
      t.text :notes
      t.boolean :is_primary_guest, default: false
      t.string :segment_title
      t.integer :segment_start_time # in seconds
      t.integer :segment_end_time # in seconds

      t.timestamps
    end
    
    # Ensure a profile can only appear once per episode
    add_index :profile_episodes, [:profile_id, :episode_id], unique: true, name: 'idx_profile_episodes'
  end
end
