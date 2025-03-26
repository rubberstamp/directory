class AddMessagePreferencesToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :allow_messages, :boolean, default: true
    add_column :profiles, :message_forwarding_email, :string
    add_column :profiles, :auto_forward_messages, :boolean, default: false
  end
end
