class AddSubjectToGuestMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :guest_messages, :subject, :string
  end
end
