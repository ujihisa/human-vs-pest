class CreateGameMatches < ActiveRecord::Migration[7.1]
  def change
    create_table :game_matches do |t|
      t.string :human_you_name
      t.string :pest_you_name
      t.datetime :finished_at

      t.timestamps
    end
  end
end
