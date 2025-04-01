class AddGuestApplicationFields < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :status, :string, default: 'guest'
    add_column :profiles, :practice_size, :string
    add_column :profiles, :podcast_objectives, :text
    add_index :profiles, :status
  end
end
