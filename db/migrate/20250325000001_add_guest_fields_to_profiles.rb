class AddGuestFieldsToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :company, :string
    add_column :profiles, :website, :string
    add_column :profiles, :mailing_address, :string
    add_column :profiles, :facebook_url, :string
    add_column :profiles, :twitter_url, :string
    add_column :profiles, :instagram_url, :string
    add_column :profiles, :tiktok_url, :string
    add_column :profiles, :testimonial, :text
    add_column :profiles, :headshot_url, :string
    add_column :profiles, :interested_in_procurement, :boolean, default: false
    add_column :profiles, :submission_date, :date
  end
end