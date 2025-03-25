class AddCachedFormattedLocationToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :cached_formatted_location, :string
  end
end
