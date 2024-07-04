# frozen_string_literal: true

MenuAction = Data.define(:id, :japanese, :cost, :location_type, :description)

MenuActions = {
  #                :japanese           :cost          :location_type, :description
  build_farm:      ['建設/農地',       { seed: 1 },   :unit,          '種を植えます。3ターン後に身が実ります'],
  build_trail:     ['建設/小道',       { wood: 1 },   :unit,          '小道を設置します。これがあると、1ターンで移動できる距離が増えます。ユニットの最大HPを高く保つのに活躍します'],
  build_barricade: ['建設/バリケード', { wood: 2 },   :unit,          '未実装!'],
  place_bomb:      ['設置/爆弾',       { ore: 3 },    :unit,          '爆弾を設置します。次ターンから、任意のタイミングで起爆できます'],
  spawn_unit:      ['ユニット生産',    { money: :f }, :base_without_unit, 'ユニットを生産します。作られたユニットは即座に行動できます。コストは毎回高くなっていくので注意'],
  trigger_bomb:    ['爆弾起爆',        {},            :bomb,          '爆弾を起爆します。起爆すると、敵味方関係なく周囲1マス範囲を全て破壊しつくします'],
}.to_h {|id, (a, b, c, d)| [id, MenuAction.new(id, a, b, c, d)] }
def MenuActions.at(game, player)
  transform_values {|v|
    cost = v.cost.transform_values {|amount|
      if amount == :f
        amount = game.cost_to_spawn_unit(player.id)
      else
        amount
      end
    }
    MenuAction.new(id: v.id, japanese: v.japanese, cost: cost, location_type: v.location_type, description: v.description)
  }
end
MenuActions.freeze