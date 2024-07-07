# frozen_string_literal: true

UnitAction = Data.define(:id, :japanese) do
  def self.find(id)
    UNIT_ACTIONS.fetch(id)
  end

  # nil | UnitAction
  def self.reason(game, unit, loc)
    return nil if game.winner

    # if 1 < unit.hp
    #   if game.world.unitss[unit.player.opponent.id].find { loc == _1.loc }
    #     return UnitAction.find(:melee_attack)
    #   end
    # end

    if unit.moveable(world: game.world).include?(loc)
      return UnitAction.find(:move)
    end

    b = game.world.buildings.at(loc)
    if b && b.player != unit.player
      case b.id
      when :tree
        return UnitAction.find(:harvest_woods)
      when :rock
        return UnitAction.find(:mine_ore)
      when :barricade
        return UnitAction.find(:attack_barricade)
      end
    end

    nil
  end
end

UNIT_ACTIONS = {
  move: UnitAction.new(:move, '移動'),
  harvest_woods: UnitAction.new(:harvest_woods, '伐採'),
  mine_ore: UnitAction.new(:mine_ore, '採掘'),
  attack_barricade: UnitAction.new(:attack_barricade, 'バリケードを攻撃'),
}

