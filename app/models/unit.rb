# frozen_string_literal: true

Unit = Struct.new(:player_id, :loc, :hp) do
  def initialize(player_id:, loc:)
    super(player_id, loc, 8)
  end

  def player
    Player.find(player_id)
  end

  # 拠点との移動距離に依存する
  def max_hp(world)
    base = world.buildings[player_id].find { _1.id == :base }
    [
      8 - world.move_distance(player_id, base.loc, loc),
      1,
    ].max
  end

  # returns [(Integer, Integer)]
  def moveable(world:)
    visited = []
    stack = [loc]
    moveable_locs = []

    until stack.empty?
      current_loc = stack.pop
      next if visited.include?(current_loc)
      visited << current_loc

      neighbours = world.neighbours(current_loc).select do |neighbour|
        !visited.include?(neighbour) && !world.not_passable?(player, neighbour)
      end

      moveable_locs.concat(neighbours)

      neighbours.each do |neighbour|
        building = world.buildings.at(neighbour)
        stack << neighbour if building&.player == player && building.id == :trail
      end
    end

    moveable_locs.select do |loc|
      !world.unitss.values.flatten(1).any? { _1.loc == loc }
    end
  end

  def dead?
    hp <= 0
  end
end
