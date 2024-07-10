# frozen_string_literal: true

Player = Data.define(:id, :emoji, :japanese, :opponent_id) do
  def self.find(id)
    [Human, Pest].find { _1.id == id } or
      raise "Must not happen: Unknown player: #{id}"
  end

  def opponent
    self.class.find(opponent_id)
  end
end

Human = Player.new(id: :human, emoji: '🧍', japanese: '人間', opponent_id: :pest)
Pest = Player.new(id: :pest, emoji: '🐛', japanese: '害虫', opponent_id: :human)
