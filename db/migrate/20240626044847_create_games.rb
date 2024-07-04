class CreateGames < ActiveRecord::Migration[7.1]
  def change
    create_table :games do |t|
      t.string :human_you_name
      t.string :pest_you_name
      t.datetime :finished_at

      t.timestamps
    end
  end
end
