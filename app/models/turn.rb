# frozen_string_literal: true

class Turn
  def initialize(num:, game:)
    @num = num
    @game = game

    @actionable_units = @game.world.unitss.to_h {|p_id, us| [p_id, us.dup] }
    @messages = []
  end
  attr_reader :num, :game, :actionable_units, :messages

  private def postprocess_death(unit)
    @messages << "#{unit.player.japanese}: ユニット#{unit.loc.inspect}が死亡しました"
    @game.world.unitss[unit.player_id].delete(unit)
    @actionable_units[unit.player_id].delete(unit)
  end

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
        base_loc = @game.world.buildings.of(player.id, :base).loc
        @game.world.unitss[player.id].map(&:loc).select {|loc|
          # 自分の拠点だけは上書き設置できない
          base_loc != loc
        }
      when :base_without_unit
        base_loc = @game.world.buildings.of(player.id, :base).loc
        # ユニットがいたらダメ
        @game.world.unitss[player.id].map(&:loc).include?(base_loc) ? [] : [base_loc]
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
      if b = @game.world.buildings.at(loc)
        @messages << "#{player.japanese}: #{b.view}#{loc.inspect}を破壊して、農地にしました"
        @game.world.buildings.delete_at(loc)
      else
        @messages << "#{player.japanese}: #{loc.inspect}を農地にしました"
      end

      @game.world.buildings[player.id] << Building.new(player_id: player.id, id: :seeds0, loc: loc)
    when :build_trail
      if b = @game.world.buildings.at(loc)
        @messages << "#{player.japanese}: #{b.view}#{loc.inspect}を破壊して、小道にしました"
        @game.world.buildings.delete_at(loc)
      else
        @messages << "#{player.japanese}: #{loc.inspect}を小道にしました"
      end

      @game.world.buildings[player.id] << Building.new(player_id: player.id, id: :trail, loc: loc)
    when :build_barricade
      if b = @game.world.buildings.at(loc)
        @messages << "#{player.japanese}: #{b.view}#{loc.inspect}を破壊して、バリケードにしました"
        @game.world.buildings.delete_at(loc)
      else
        @messages << "#{player.japanese}: #{loc.inspect}をバリケードにしました"
      end

      @game.world.buildings[player.id] << Building.new(player_id: player.id, id: :barricade, loc: loc)
    when :place_bomb
      if b = @game.world.buildings.at(loc)
        @messages << "#{player.japanese}: #{b.view}#{loc.inspect}を破壊して、爆弾を設置しました"
        @game.world.buildings.delete_at(loc)
      else
        @messages << "#{player.japanese}: #{loc.inspect}に爆弾を設置しました"
      end
      @game.world.buildings[player.id] << Building.new(player_id: player.id, id: :bomb0, loc: loc)
    when :trigger_bomb
      @messages << "#{player.japanese}: #{loc.inspect}の爆弾を起爆しました!"
      @game.world.buildings.delete_at(loc)
      [loc, *@game.world.neighbours(loc)].each do |nloc|
        next if @game.world.buildings.at(nloc)&.id == :pond
        if b = @game.world.buildings.delete_at(nloc)
          @messages << "#{player.japanese}: #{b.player.japanese} の #{b.view}を破壊しました"
        end
        if u = @game.world.unitss.values.flatten(1).find { _1.loc == nloc }
          u.hp = 0
          postprocess_death(u)
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
      @messages << "#{player.japanese}: #{b.view}を破壊しました"
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
      # unit.hp = [unit.hp, unit.max_hp(@game.world)].min
      if b = @game.world.buildings.at(loc) and b.player == player
        # ノーダメージ
      else
        unit.hp = [unit.hp - 1, 1].max
      end
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
    when :attack_barricade
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

      postprocess_death(unit) if unit.dead?
      postprocess_death(target_unit) if target_unit.dead?
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
      @game.tick!
      t = Turn.new(num: @num + 1, game: @game)

      t.game.world.unitss.each do |p_id, units|
        p = Player.find(p_id)

        units.each do |u|
          if u.loc == t.game.world.buildings.of(p.id, :base).loc && u.hp < u.max_hp(t.game.world)
            new_hp = [u.hp + 5, u.max_hp(t.game.world)].min
            t.messages << "#{p.japanese}: 拠点でユニットが回復しました (HP #{u.hp} -> #{new_hp})"
            u.hp = new_hp
          end

          t.unit_passive_action!(p, u)
        end
      end
      t
    end
  end
end
