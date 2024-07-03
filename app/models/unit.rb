# frozen_string_literal: true

Unit = Struct.new(:player_id, :loc, :hp) do
  def player
    Player.find(player_id)
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