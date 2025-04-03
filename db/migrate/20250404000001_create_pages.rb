class CreatePages < ActiveRecord::Migration[7.1]
  def change
    create_table :pages do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :content
      t.boolean :published, default: false
      t.integer :position, default: 0
      t.text :meta_description
      t.string :meta_keywords
      t.boolean :show_in_menu, default: false
      t.timestamps
    end
    
    add_index :pages, :slug, unique: true
  end
end