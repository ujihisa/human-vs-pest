class CreateGames < ActiveRecord::Migration[7.1]
  def change
    create_table :games do |t|
      t.datetime :finished_at

      t.timestamps
    end
  end
end
