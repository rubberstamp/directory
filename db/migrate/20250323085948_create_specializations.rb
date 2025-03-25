class CreateSpecializations < ActiveRecord::Migration[8.0]
  def change
    create_table :specializations do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
