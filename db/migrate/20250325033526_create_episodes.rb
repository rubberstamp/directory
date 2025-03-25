class CreateEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :episodes do |t|
      t.integer :number
      t.string :title
      t.string :video_id
      t.date :air_date
      t.text :notes
      t.string :thumbnail_url
      t.integer :duration_seconds

      t.timestamps
    end
    
    add_index :episodes, :number, unique: true
    add_index :episodes, :video_id, unique: true
  end
end
