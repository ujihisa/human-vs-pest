# frozen_string_literal: true

Building = Data.define(:player, :id, :loc, :hp) do
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
  }
  def initialize(id:, player:, loc:, hp: nil)
    hp ||= BUILDING_DEFAULTS.fetch(id).hp_f.()
    super(player:, id:, loc:, hp:)
  end

  # ownerは無条件で通行可能なので、ownerでないと仮定する
  def passable?
    BUILDING_DEFAULTS.fetch(id).passable
  end

  def view
    bd = BUILDING_DEFAULTS.fetch(id)
    case player
    when Human, :world
      bd.human_emoji
    when Pest
      bd.pest_emoji
    else
      raise "Must not happen: invalid player #{player}"
    end
  end

  def background_img
    # Dirty hack
    if player == :world
      return "backgrounds/#{id}.png"
    end

    ["backgrounds/#{player.id}_#{id}.png", "backgrounds/#{id}.png"].find {|path|
      File.exist?("app/assets/images/#{path}")
    }
  end
end
