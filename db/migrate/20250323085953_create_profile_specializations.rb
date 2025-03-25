class CreateProfileSpecializations < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_specializations do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :specialization, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :profile_specializations, [:profile_id, :specialization_id], unique: true, name: 'idx_profiles_specializations'
  end
end
