# frozen_string_literal: true

class Turn
  def initialize(num:, game:)
    @num = num
    @game = game

    @actionable_units = @game.world.unitss.to_h {|p_id, us| [p_id, us.dup] }
    @messages = []
  end
  attr_reader :num, :game, :actionable_units, :messages

  def unit_actionable_locs(player, unit)
    return [] if @game.winner
    return [] if !@actionable_units[player.id].include?(unit)

    locs = (@game.world.neighbours(unit.loc) + unit.moveable(world: @game.world)).uniq

    locs.select {|loc| !!UnitAction.reason(@game, unit, loc) }
  end

  # { Symbol => [Location] }
  def menu_actionable_actions(player)
    return {} if @game.winner

    MenuActions.at(@game, player).select {|_, menu_action|
      menu_action.cost.all? {|k, amount|
        @game.resources[player.id][k].amount >= amount
      }
    }.transform_values {|m|
      case m.location_type
      when :unit
        @game.world.unitss[player.id].map(&:loc).select {|loc|
          # 自分の拠点だけは壊せない
          @game.world.buildings.of(player.id, :base).loc != loc
        }
      when :base
        [@game.world.buildings.of(player.id, :base).loc].select {|loc|
          !@game.world.unitss[player.id].map(&:loc).include?(loc)
        }
      when :bomb
        @game.world.buildings[player.id].select { _1.id == :bomb }.map(&:loc)
      else
        raise "Invalid :location_type: #{v[:location_type]}"
      end
    }.reject {|k, locs|
      locs.empty?
    }.to_h
  end

  def menu_action!(player, action, loc)
    MenuActions.at(@game, player)[action].cost.each do |k, amount|
      @game.resources[player.id][k] = @game.resources[player.id][k].add_amount(-amount)
    end

    case action
    when :build_farm
      if b = @game.world.buildings.at(loc) and b.id != :base
        @messages << "#{player.japanese}: #{b.id}が邪魔なのでとりあえず撤去しました"
        @game.world.buildings.delete_at(loc)
      end

      @messages << "#{player.japanese}: #{loc.inspect}を農地にしました"
      @game.world.buildings[player.id] << Building.new(player_id: player.id, id: :seeds0, loc: loc)
    when :build_trail
      @messages << "#{player.japanese}: #{loc.inspect}を小道にしました"
      @game.world.buildings[player.id] << Building.new(player_id: player.id, id: :trail, loc: loc)
    when :place_bomb
      @messages << "#{player.japanese}: #{loc.inspect}に爆弾を設置しました"
      @game.world.buildings[player.id] << Building.new(player_id: player.id, id: :bomb0, loc: loc)
    when :trigger_bomb
      @messages << "#{player.japanese}: #{loc.inspect}の爆弾を起爆しました!"
      @game.world.buildings.delete_at(loc)
      [loc, *@game.world.neighbours(loc)].each do |nloc|
        next if @game.world.buildings.at(nloc)&.id == :pond
        if b = @game.world.buildings.delete_at(nloc)
          @messages << "#{player.japanese}: #{b.player.japanese} の #{b.id}を破壊しました"
        end
        if u = @game.world.unitss.values.flatten(1).find { _1.loc == nloc }
          @messages << "#{player.japanese}: #{u.player.japanese} の ユニットが死亡しました"
          @game.world.unitss[u.player.id].delete(u)
        end
      end
    when :spawn_unit
      @messages << "#{player.japanese}: #{loc.inspect}にユニットを生産しました。即行動できます"

      new_unit = Unit.new(player_id: player.id, loc: @game.world.buildings.of(player.id, :base).loc)
      @game.world.unitss[player.id] << new_unit
      @game.total_spawned_units[player.id] += 1
      @actionable_units[player.id] += [new_unit]
    else
      p "Not implemented yet: #{action}"
    end

    if @game.winner
      @messages << "#{game.winner.japanese} が勝利しました!"
      @actionable_units = { human: [], pest: [] }
    end
  end

  def unit_passive_action!(player, unit)
    opponent = player.opponent
    case @game.world.buildings.at(unit.loc)
    in Building(player_id: ^(player.id), id: :fruits) => b
      @messages << "#{player.japanese}: #{b.id}を収穫しました"
      @game.world.buildings.delete_at(unit.loc)
      @game.world.buildings[player.id] << b.with(id: :seeds0)

      @game.resources[player.id][:money] = @game.resources[player.id][:money].add_amount(1)
      @game.resources[player.id][:seed] = @game.resources[player.id][:seed].add_amount(1)
    in Building(player_id: ^(player.opponent.id)) => b
      @messages << "#{player.japanese}: #{b.id}を破壊しました"
      @game.world.buildings.delete_at(unit.loc)
    else
      # do nothing
    end
  end

  def unit_action!(player, unit, loc, action_id)
    raise 'must not happen: The game is already finished' if @game.winner
    raise 'must not happen: The unit is not actionable' unless @actionable_units[player.id].include?(unit)

    action = UnitAction.find(action_id)
    @messages << "#{player.japanese}: #{unit.loc.inspect}にいるユニットが#{action.japanese}しました"

    case action.id
    when :move
      unit.loc = loc
      unit_passive_action!(player, unit)
      unit.hp = [unit.hp, unit.max_hp(@game.world)].min
    when :harvest_woods
      @game.resources[player.id][:wood] = @game.resources[player.id][:wood].add_amount(1)
      building = @game.world.buildings.at(loc)

      @game.world.buildings.delete_at(loc)
      if 1 < building.hp
        @game.world.buildings[player.id] << building.with(hp: building.hp - 1)
      end
    when :mine_ore
      @game.resources[player.id][:ore] = @game.resources[player.id][:ore].add_amount(1)
      building = @game.world.buildings.at(loc)

      @game.world.buildings.delete_at(loc)
      if 1 < building.hp
        @game.world.buildings[player.id] << building.with(hp: building.hp - 1)
      end
    when :build_farm
      @game.resources[player.id][:seed] = @game.resources[player.id][:seed].add_amount(-1)
      @game.world.buildings[player.id] << Building.new(player_id: player.id, id: :seeds0, loc: loc)
    when :melee_attack
      target_unit = @game.world.unitss[player.opponent.id].find { _1.loc == loc }
      if unit.hp == target_unit.hp
        unit.hp = 1
        target_unit.hp = 1
      else
        damage = [unit.hp, target_unit.hp].min
        unit.hp -= damage
        target_unit.hp -= damage
      end

      if unit.dead?
        @messages << "#{player.japanese}: #{unit.loc.inspect}にいるユニットが死亡しました"
        @game.world.unitss[player.id].delete(unit)
      end
      if target_unit.dead?
        @messages << "#{player.opponent.japanese}: #{target_unit.loc.inspect}にいるユニットが死亡しました"
        @game.world.unitss[player.opponent.id].delete(target_unit)
      end
    end

    @actionable_units[player.id] -= [unit]

    if @game.winner
      @messages << "#{game.winner.japanese} が勝利しました!"
      @actionable_units = { human: [], pest: [] }
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
      @actionable_units.each do |player_id, units|
        player = Player.find(player_id)
        units.each do |u|
          @messages << "#{player.japanese}: #{u.loc.inspect}にいるユニットが回復しました"
          u.hp = [u.hp + 3, u.max_hp(@game.world)].min
        end
      end
      @game.tick!
      t = Turn.new(num: @num + 1, game: @game)
      t.game.world.unitss.each do |p_id, units|
        p = Player.find(p_id)
        units.each do |u|
          t.unit_passive_action!(p, u)
        end
      end
      t
    end
  end
end
