# frozen_string_literal: true

class Turn
  def initialize(num:, game:)
    @num = num
    @game = game

    @actionable_units = @game.world.unitss.transform_values(&:dup).dup
    @actionable_buildings = @game.world.buildings.transform_values(&:dup).dup
    @messages = []
  end
  attr_reader :num, :game, :actionable_units, :actionable_buildings, :messages

  def unit_actionable_locs(player, unit)
    return [] if @game.winner
    return [] if !@actionable_units[player].include?(unit)

    locs = @game.world.reachable(unit.loc)

    locs.select {|loc| !!@game.reason_unit_action(player, unit, loc) }
  end

  def building_action!(player, building)
    case building.type
    when :base
      cost = @game.cost_to_spawn_unit(player)

      @game.moneys[player] -= cost
      new_unit = Unit.new(loc: @game.world.buildings.of(player, :base).loc, hp: 8)
      @game.world.unitss[player] << new_unit
      @game.total_spawned_units[player] += 1

      @actionable_units[player] += [new_unit]
    end
    @actionable_buildings[player] -= [building]
  end


  def unit_action!(player, unit, loc)
    raise 'must not happen: The game is already finished' if @game.winner
    raise 'must not happen: The unit is not actionable' unless @actionable_units[player].include?(unit)

    action = @game.reason_unit_action(player, unit, loc)
    raise "reason_unit_action returned nil for #{loc.inspect}" unless action

    @messages << "#{player.japanese}: #{unit.loc.inspect}にいるユニットが #{action} しました"

    case action
    when :move
      unit.move!(loc)
    when :harvest_woods
      @game.woods[player] += 3
      @game.world.hexes[loc.y][loc.x] = nil
    when :farming
      @game.world.buildings[player] << Building.new(type: :seeds0, loc: loc)
    when :harvest_fruit
      @game.world.buildings.delete_at(loc)
      @game.moneys[player] += 3
    when :melee_attack
      target_unit = @game.world.unitss[player.opponent].find { _1.loc == loc }
      target_unit.hp -= 4

      if target_unit.dead?
        @game.world.unitss[player.opponent].delete(target_unit)
      end

      unit.hp -= 2
    when :destroy
      @game.world.buildings.delete_at(loc)
    end

    @actionable_units[player] -= [unit]

    if @game.winner
      @messages << "#{game.winner.japanese} が勝利しました!"
      @actionable_units = { Human => [], Pest => [] }
    end
  end

  def draw
    puts "Turn #{@num}"
    puts @messages
    @game.draw
  end

  def next
    if @game.winner
      raise 'must not happen: The game is already finished'
    else
      @actionable_units.each do |player, units|
        units.each do |u|
          @messages << "#{player.japanese}: #{u.loc.inspect}にいるユニットが回復しました"
          u.hp = [u.hp + 3, 8].min
        end
      end
      @game.tick!
      Turn.new(num: @num + 1, game: @game)
    end
  end
end
