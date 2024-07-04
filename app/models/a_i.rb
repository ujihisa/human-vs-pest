# frozen_string_literal: true

module AI
  def self.find_menu_action(turn, player, menu_actions)
    menu_actions.each do |action, locs|
      locs = locs.select {|loc|
        case action
        when :barricade
          false
        when :place_bomb, :trigger_bomb
          neighbours = turn.game.world.neighbours(loc)

          if neighbours.include?(turn.game.world.buildings.of(player.id, :base).loc)
            false
          elsif neighbours.include?(turn.game.world.buildings.of(player.opponent.id, :base).loc)
            true
          end
        else
          true
        end
      }
      return [action, locs.sample] if !locs.empty?
    end
    nil
  end

  # [Location, UnitAction] | nil
  def self.unit_action_for(game, player, u, locs)
    return nil if game.winner

    uas = locs.map {|loc| [loc, UnitAction.reason(game, u, loc)] }

    # セルフケア最優先
    if u.hp <= u.max_hp(game.world) / 2
      return nil
    end

    # 次いで近接攻撃
    if ua = uas.find { _1[1].id == :melee_attack }
      return ua
    end

    # 相手が自拠点に近づいてきていれば戻る
    min_dist = game.world.unitss[player.opponent.id].map {|u| distance(u.loc, game.world.buildings.of(player.id, :base).loc) }.min
    if min_dist && min_dist < 4
      ua = uas.select {|_, a| a.id == :move }.min_by {|loc, _|
        distance(loc, game.world.buildings.of(player.id, :base).loc)
      }
      return ua if ua
    end

    # 相手よりHP合計が多ければrage mode
    if game.world.unitss[player.opponent.id].sum(&:hp) < game.world.unitss[player.id].sum(&:hp)
      ua = uas.select {|_, a| [:move, :harvest_woods, :mine_ore].include?(a.id) }.min_by {|loc, _|
        game.world.move_distance(player.id, loc, game.world.buildings.of(player.opponent.id, :base).loc)
      }
      ua
    else
      # じわじわ成長を狙う
      ua = uas.reject {|_, a| a.id != :move }.sample
      ua ||= uas.sample
      ua
    end
  end

  private_class_method def self.distance(loc0, loc1)
    Math.sqrt((loc1.x - loc0.x) ** 2 + (loc1.y - loc0.y) ** 2)
  end
end
