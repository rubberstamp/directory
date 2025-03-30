class AddSummaryToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :summary, :text
  end
end
