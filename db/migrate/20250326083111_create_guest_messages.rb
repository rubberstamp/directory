class CreateGuestMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :guest_messages do |t|
      t.string :sender_name
      t.string :sender_email
      t.text :message
      t.references :profile, null: true, foreign_key: true
      t.string :status, default: 'new'
      t.text :admin_notes
      t.datetime :forwarded_at

      t.timestamps
    end
  end
end
