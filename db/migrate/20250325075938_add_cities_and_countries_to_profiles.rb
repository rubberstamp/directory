class AddCitiesAndCountriesToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :cached_city, :string
    add_column :profiles, :cached_country, :string
  end
end
