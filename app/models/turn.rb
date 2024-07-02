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

  MenuAction = Data.define(:id, :japanese, :cost, :location_type)

  MENU_ACTIONS = {
    #                 :japanese          :cost          :location_type
    farming:         ['農業',            { seed: 1 },   :unit],
    # build_trail:     ['建設/小道',       { wood: 1 },   :unit],
    # build_barricade: ['建設/バリケード', { wood: 2 },   :unit],
    # build_landmine:  ['建設/地雷',       { ore: 3 },    :unit],
    spawn_unit:      ['ユニット生産',    { money: :f }, :base],
  }.to_h {|id, (a, b, c)| [id, MenuAction.new(id: id, japanese: a, cost: b, location_type: c)] }
  def MENU_ACTIONS.at(game, player)
    transform_values {|v|
      cost = v.cost.transform_values {|amount|
        if amount == :f
          amount = game.cost_to_spawn_unit(player)
        else
          amount
        end
      }
      MenuAction.new(id: v.id, japanese: v.japanese, cost: cost, location_type: v.location_type)
    }
  end
  MENU_ACTIONS.freeze

  # { Symbol => [Location] }
  def menu_actionable_actions(player)
    return {} if @game.winner

    MENU_ACTIONS.at(@game, player).select {|_, menu_action|
      menu_action.cost.all? {|k, amount|
        @game.resources[player][k].amount >= amount
      }
    }.transform_values {|m|
      case m.location_type
      when :unit
        @game.world.unitss[player].map(&:loc).select {|loc|
          @game.world.buildings.at(loc).nil?
        }
      when :base
        [@game.world.buildings.of(player, :base).loc].select {|loc|
          !@game.world.unitss[player].map(&:loc).include?(loc)
        }
      else
        raise "Invalid :location_type: #{v[:location_type]}"
      end
    }.reject {|k, locs|
      locs.empty?
    }.to_h
  end

  def menu_action!(player, action, loc)
    MENU_ACTIONS.at(@game, player)[action].cost.each do |k, amount|
      @game.resources[player][k] = @game.resources[player][k].add_amount(-amount)
    end

    case action
    when :farming
      @game.world.buildings[player] << Building.new(player: player, id: :seeds0, loc: loc)
    when :spawn_unit
      new_unit = Unit.new(player: player, loc: @game.world.buildings.of(player, :base).loc, hp: 8)
      @game.world.unitss[player] << new_unit
      @game.total_spawned_units[player] += 1
      @actionable_units[player] += [new_unit]
    else
      p "Not implemented yet: #{action}"
    end
  end

  def unit_passive_action!(player, unit)
    opponent = player.opponent
    case @game.world.buildings.at(unit.loc)
    in Building(player: ^player, id: :fruits) => b
      @messages << "#{player.japanese}: #{b.id}を収穫しました"
      @game.world.buildings.delete_at(unit.loc)
      @game.world.buildings[player] << b.with(id: :seeds0)

      @game.resources[player][:money] = @game.resources[player][:money].add_amount(3)
      @game.resources[player][:seed] = @game.resources[player][:seed].add_amount(1)
    in Building(player: ^(player.opponent)) => b
      @messages << "#{player.japanese}: #{b.id}を略奪しました"
      @game.resources[player][:money] = @game.resources[player][:money].add_amount(1)
      @game.world.buildings.delete_at(unit.loc)
    else
      # do nothing
    end
  end

  def unit_action!(player, unit, loc, action)
    raise 'must not happen: The game is already finished' if @game.winner
    raise 'must not happen: The unit is not actionable' unless @actionable_units[player].include?(unit)

    @messages << "#{player.japanese}: #{unit.loc.inspect}にいるユニットが #{action} しました"

    case action
    when :move
      unit.move!(loc)
      unit_passive_action!(player, unit)
    when :harvest_woods
      @game.resources[player][:wood] = @game.resources[player][:wood].add_amount(1)

      # TODO: 木のHPを減らす
      @game.world.buildings.delete_at(loc)
    when :farming
      @game.resources[player][:seed] = @game.resources[player][:seed].add_amount(-1)
      @game.world.buildings[player] << Building.new(player: player, id: :seeds0, loc: loc)
    when :melee_attack
      target_unit = @game.world.unitss[player.opponent].find { _1.loc == loc }
      if unit.hp == target_unit.hp
        unit.hp = 1
        target_unit.hp = 1
      else
        damage = (unit.hp - target_unit.hp).abs
        unit.hp -= damage
        target_unit.hp -= damage
      end

      if unit.dead?
        @messages << "#{player.japanese}: #{unit.loc.inspect}にいるユニットが死亡しました"
        @game.world.unitss[player].delete(unit)
      end
      if target_unit.dead?
        @messages << "#{player.opponent.japanese}: #{target_unit.loc.inspect}にいるユニットが死亡しました"
        @game.world.unitss[player.opponent].delete(target_unit)
      end
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
      t = Turn.new(num: @num + 1, game: @game)
      t.game.world.unitss.each do |p, units|
        units.each do |u|
          t.unit_passive_action!(p, u)
        end
      end
      t
    end
  end
end
