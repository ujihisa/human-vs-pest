# frozen_string_literal: true

module AI
  def self.find_menu_action(turn, player, menu_actions)
    menu_actions.to_a.shuffle.each do |action, locs|
      locs = locs.select {|loc|
        # すでに建物がある場所には建設しない
        if turn.game.world.buildings.at(loc) && /build|place/ =~ action.to_s
          next false
        end

        case action
        when :build_barricade
          # y軸マップ中央あたりで、左右両側に少なくとも1つ敵が移動不可能建物があるとき
          centre = turn.game.world.size_y / 2
          if ((centre - 2)..(centre + 2)).include?(loc.y)
            blockers = turn.game.world.neighbours(loc).select {|nloc|
              turn.game.world.not_passable?(player.opponent, nloc)
            }
            if blockers.any? {|l| l.x < loc.x } && blockers.any? {|l| l.x > loc.x }
              rand(10) < 9 # 90%
            end
          end
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
  def self.unit_action_for(game, player, unit, locs)
    return nil if game.winner

    uas = locs.map {|loc| [loc, UnitAction.reason(game, unit, loc)] }

    # HPが1なら、拠点に戻る
    if unit.hp == 1
      if unit.loc == game.world.buildings.of(player.id, :base).loc
        return nil
      else
        ua = uas.select {|_, a| a.id == :move }.min_by {|loc, _|
          game.world.move_distance(player.id, loc, game.world.buildings.of(player.id, :base).loc)
        }
        return ua if ua
      end
    end

    # 次いで近接攻撃
    if ua = uas.find { _1[1].id == :melee_attack }
      # 相手のHPの方が高いときは、5%の確率で攻撃する
      # ここでいう相手とは、loc = ua[0]の位置にいるunitのこと
      if game.world.unitss[player.opponent.id].any? {|u| u.loc == ua[0] && unit.hp < u.hp }
        if rand(100) < 5
          return ua
        end
      else
        # そうでないなら必ず攻撃する
        return ua
      end
    end

    # 相手が自拠点に近づいてきていれば戻る
    min_dist = game.world.unitss[player.opponent.id].map {|u| distance(u.loc, game.world.buildings.of(player.id, :base).loc) }.min
    if min_dist && min_dist < 4
      ua = uas.select {|_, a| a.id == :move }.min_by {|loc, _|
        distance(loc, game.world.buildings.of(player.id, :base).loc)
      }
      return ua if ua
    end

    # 累計ユニット作成数が4を超えたか、あるいは敵ユニット数が0なら、rage mode
    if 4 <= game.total_spawned_units[player.id] or game.world.unitss[player.opponent.id].size == 0
      ua = uas.select {|_, a| [:move, :harvest_woods, :mine_ore, :attack_barricade].include?(a.id) }.min_by {|loc, _|
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

