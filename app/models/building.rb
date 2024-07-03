# frozen_string_literal: true

Building = Data.define(:player, :id, :loc, :hp) do
  DEFAULT_BUILDING_HP = {
    tree: -> { rand(1..3) },
    rock: -> { rand(5..9) },
    barricade: -> { 8 },
  }
  def initialize(id:, player:, loc:, hp: nil)
    hp ||= DEFAULT_BUILDING_HP[id]&.call
    super(player:, id:, loc:, hp:)
  end

  # ownerは無条件で通行可能なので、ownerでないと仮定する
  def passable?
    ![:tree, :pond, :rock, :barricade].include?(id)
  end

  def view
    building_table = {
      Human => {
        base: '🏠',
        fruits: '🍓',
        flowers: '🌷',
        seeds: '🌱',
        seeds0: '🌱',
        trail: '🛤',
      },
      Pest => {
        base: '🕳',
        fruits: '🍄',
        flowers: '🦠',
        seeds: '🧬',
        seeds0: '🧬',
        trail: '🛤',
      },
      :world => {
        tree: '🌲',
        pond: '🌊',
      },
    }
    building_table[player][id]
  end

  def background_img
    path = "backgrounds/#{id}.png"
    File.exist?("app/assets/images/#{path}") ? path : nil
  end
end
