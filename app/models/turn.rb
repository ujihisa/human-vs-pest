# frozen_string_literal: true

class Turn
  def initialize(num:, game:)
    @num = num
    @game = game

    @actionable_units = @game.world.unitss.transform_values(&:dup).dup
    @messages = []
  end
  attr_reader :num, :game, :actionable_units, :messages

  # neighbours系actionのみ
  def unit_actionable_locs(player, unit)
    return [] if @game.winner
    return [] if !@actionable_units[player].include?(unit)

    locs = @game.world.neighbours(unit.loc)

    locs.select {|loc| !!@game.reason_unit_action(player, unit, loc) }
  end

  MENU_ACTIONS = {
    farming:         { japanese: '農業',            consume: { seed: 1 }, valid_location_type: :unit },
    build_trail:     { japanese: '建設/小道',       consume: { wood: 1 }, valid_location_type: :unit },
    build_barricade: { japanese: '建設/バリケード', consume: { wood: 2 }, valid_location_type: :unit },
    build_landmine:  { japanese: '建設/地雷',       consume: { ore: 3 }, valid_location_type: :unit },
    spawn_unit:      { japanese: 'ユニット生産',    consume: { money: 1 }, valid_location_type: :base }, # TODO: 金額を可変に
  }
  # { Symbol => [Location] }
  def menu_actionable_actions(player)
    return [] if @game.winner

    MENU_ACTIONS.select {|_, hash|
      hash[:consume].all? {|k, v| @game.resources[player][k].amount >= v }
    }.transform_values {|v|
      case v[:valid_location_type]
      when :unit
        @game.world.unitss[player].map(&:loc).select {|loc|
          @game.world.buildings.at(loc).nil?
        }
      when :base
        [@game.world.buildings.of(player, :base).loc].select {|loc|
          !@game.world.unitss[player].map(&:loc).include?(loc)
        }
      else
        raise "Invalid :valid_location_type: #{v[:valid_location_type]}"
      end
    }.reject {|k, locs|
      locs.empty?
    }.to_h
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
  end


  def unit_action!(player, unit, loc, action)
    raise 'must not happen: The game is already finished' if @game.winner
    raise 'must not happen: The unit is not actionable' unless @actionable_units[player].include?(unit)

    @messages << "#{player.japanese}: #{unit.loc.inspect}にいるユニットが #{action} しました"

    case action
    when :move
      unit.move!(loc)

      # ついでに収穫 / 略奪
      opponent = player.opponent
      case @game.world.buildings.at(loc)
      in [^player, Building(type: :fruits)]
        @messages << "#{player.japanese}: ついでにそのまま収穫しました"
        @game.world.buildings.delete_at(loc)
        @game.resources[player][:money] = @game.resources[player][:money].add_amount(3)
        @game.resources[player][:seed] = @game.resources[player][:seed].add_amount(2)
      in [^(player.opponent), b]
        @messages << "#{player.japanese}: ついでにそのまま#{b.type}を略奪しました"
        @game.world.buildings.delete_at(loc)
      else
        # do nothing
      end
    when :harvest_woods
      @game.resources[player][:wood] = @game.resources[player][:wood].add_amount(3)
      @game.world.hexes[loc.y][loc.x] = nil
    when :farming
      @game.resources[player][:seed] = @game.resources[player][:seed].add_amount(-1)
      @game.world.buildings[player] << Building.new(type: :seeds0, loc: loc)
    when :melee_attack
      target_unit = @game.world.unitss[player.opponent].find { _1.loc == loc }
      target_unit.hp -= 4

      if target_unit.dead?
        @game.world.unitss[player.opponent].delete(target_unit)
      end

      unit.hp -= 2
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
