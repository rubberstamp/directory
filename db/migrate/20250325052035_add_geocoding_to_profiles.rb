class AddGeocodingToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :latitude, :float
    add_column :profiles, :longitude, :float
  end
end
