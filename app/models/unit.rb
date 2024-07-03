# frozen_string_literal: true

Unit = Struct.new(:player_id, :loc, :hp) do
  def initialize(player_id:, loc:)
    super(player_id, loc, 8)
  end

  def player
    Player.find(player_id)
  end

  # TODO: 拠点との移動距離に依存する
  def max_hp(world)
    base = world.buildings[player_id].find { _1.id == :base }
    [
      8 - world.move_distance(player_id, base.loc, loc),
      1,
    ].max
  end

  # returns [(Integer, Integer)]
  # TODO: 小道が複数あるときにも再帰的に対応。そのためにunit testを追加
  def moveable(world:)
    world.neighbours(loc).select {|loc|
      !world.not_passable?(player, loc)
    }.flat_map {|loc|
      b = world.buildings.at(loc)
      if b && b.player == player && b.id == :trail
        [loc] + world.neighbours(loc).select {|loc|
          !world.not_passable?(player, loc)
        }
      else
        [loc]
      end
    }.select {|loc|
      !world.unitss.values.flatten(1).any? { _1.loc == loc }
    }
  end

  def dead?
    hp <= 0
  end
end
