class AddAdsFieldsToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :active_for_ads, :boolean, default: false, null: false
    add_column :profiles, :ranking_score, :integer
  end
end
