class AddContentFormatToPages < ActiveRecord::Migration[8.0]
  def change
    add_column :pages, :content_format, :string, default: 'html'
    
    # Set existing pages to use HTML format
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE pages
          SET content_format = 'html'
          WHERE content_format IS NULL
        SQL
      end
    end
  end
end
