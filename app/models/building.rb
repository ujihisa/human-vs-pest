# frozen_string_literal: true

Building = Data.define(:player_id, :id, :loc, :hp) do
  BuildingDefault = Data.define(:id, :human_emoji, :pest_emoji, :passable, :hp_f)
  BUILDING_DEFAULTS = {
    tree:      BuildingDefault.new(:tree,      '🌲', '🌲', false, -> { rand(1..3) }),
    rock:      BuildingDefault.new(:rock,      '🪨', '🪨', false, -> { rand(5..9) }),
    barricade: BuildingDefault.new(:barricade, '🚧', '🕸', false, -> { 8 }),
    pond:      BuildingDefault.new(:pond,      '🌊', '🌊', false, -> { nil }),
    base:      BuildingDefault.new(:base,      '🏠', '🕳', true,  -> { nil }),
    fruits:    BuildingDefault.new(:fruits,    '🍓', '🍄', true,  -> { nil }),
    flowers:   BuildingDefault.new(:flowers,   '🌷', '🦠', true,  -> { nil }),
    seeds:     BuildingDefault.new(:seeds,     '🌱', '🧬', true,  -> { nil }),
    seeds0:    BuildingDefault.new(:seeds0,    '🌱', '🧬', true,  -> { nil }),
    trail:     BuildingDefault.new(:trail,     '🛤', '🛤', true,  -> { nil }),
    bomb0:     BuildingDefault.new(:trail,     '💣', '💣', true,  -> { 1 }),
    bomb:      BuildingDefault.new(:trail,     '💣', '💣', true,  -> { 1 }),
  }
  def initialize(id:, player_id:, loc:, hp: nil)
    hp ||= BUILDING_DEFAULTS.fetch(id).hp_f.()
    super(player_id: player_id, id:, loc:, hp:)
  end

  def player
    return :world if player_id == :world
    Player.find(player_id)
  end

  # ownerは無条件で通行可能なので、ownerでないと仮定する
  def passable?
    BUILDING_DEFAULTS.fetch(id).passable
  end

  def view
    bd = BUILDING_DEFAULTS.fetch(id)
    case player_id
    when :human, :world
      bd.human_emoji
    when :pest
      bd.pest_emoji
    else
      raise "Must not happen: invalid player_id #{player_id}"
    end
  end

  def background_img
    ["backgrounds/#{player_id}_#{id}.png", "backgrounds/#{id}.png"].find {|path|
      File.exist?("app/assets/images/#{path}")
    }
  end
end
