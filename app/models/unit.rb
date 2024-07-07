# frozen_string_literal: true

Unit = Struct.new(:player_id, :loc, :hp) do
  def initialize(player_id:, loc:)
    super(player_id, loc, 8)
  end

  def player
    Player.find(player_id)
  end

  def max_hp(world)
    8
    # base = world.buildings[player_id].find { _1.id == :base }
    # [
    #   8 - world.move_distance(player_id, base.loc, loc),
    #   1,
    # ].max
  end

  # returns [(Integer, Integer)]
  # trailが複数あるときに最大3マスまで連鎖的に対応
  def moveable(world:, max_trail_depth: 3)
    initial_locs = world.neighbours(loc).select {|nloc| !world.not_passable?(player, nloc) }
    moveable_locs = initial_locs.flat_map {|loc|
      building = world.buildings.at(loc)
      if building && building.player == player && building.id == :trail
        [loc] + self.class._explore_trail(world, player, loc, 1, [loc], max_trail_depth)
      else
        [loc]
      end
    }.uniq

    moveable_locs.select do |loc|
      !world.unitss.values.flatten.any? {|unit| unit.loc == loc }
    end
  end

  def self._explore_trail(world, player, loc, depth, visited, max_trail_depth)
    return [] if depth >= max_trail_depth
    visited << loc
    next_locs = world.neighbours(loc).select {|nloc| !world.not_passable?(player, nloc) }
    next_locs.flat_map do |nloc|
      building = world.buildings.at(nloc)
      if building && building.player == player && building.id == :trail && !visited.include?(nloc)
        [nloc] + _explore_trail(world, player, nloc, depth + 1, visited, max_trail_depth)
      else
        [nloc]
      end
    end
  end

  def dead?
    hp <= 0
  end
end
