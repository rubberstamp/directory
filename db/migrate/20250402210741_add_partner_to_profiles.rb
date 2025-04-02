class AddPartnerToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :partner, :boolean, default: false
    add_index :profiles, :partner
  end
end
