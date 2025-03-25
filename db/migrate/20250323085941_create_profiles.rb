class CreateProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :profiles do |t|
      t.string :name
      t.string :headline
      t.text :bio
      t.string :location
      t.string :specializations
      t.string :linkedin_url
      t.string :youtube_url
      t.string :email
      t.string :phone
      t.string :image_url

      t.timestamps
    end
  end
end
