# frozen_string_literal: true

MenuAction = Data.define(:id, :japanese, :cost, :build_id, :location_type, :description)

MenuActions = {
  #                :japanese           :cost          :build_id,  :location_type, :description
  build_farm:      ['建設/農地',       { seed: 1 },   :seeds0,    :unit,          '種を植えます。3ターン後に身が実ります'],
  build_trail:     ['建設/小道',       { wood: 1 },   :trail,     :unit,          '小道を設置します。これがあると、1ターンで移動できる距離が増えます (最大3)。ユニットの最大HPを高く保つのに活躍します'],
  build_barricade: ['建設/バリケード', { wood: 2 },   :barricade, :unit,          '自分は通過できるけど、相手は通過できないバリケードを設置します。無人のときに3回攻撃されると壊れます'],
  # plant_tree:      ['苗木を植える',    { seed: 3 },   :sapling,   :unit,          '10ターン後に木になります'],
  spawn_unit:      ['ユニット生産',    { money: :f }, nil,        :base_without_unit, 'ユニットを生産します。作られたユニットは即座に行動できます。コストは毎回高くなっていくので注意'],
  place_bomb:      ['爆弾を置く',      { ore: 3 },    :bomb0,     :unit,          '爆弾を設置します。起爆できるようになるまで、少なくとも1ターンかかります'],
  trigger_bomb:    ['起爆',            {},            nil,        :bomb,          '爆弾を起爆します。起爆すると、敵味方関係なく周囲1マス範囲を全て破壊しつくします'],
}.to_h {|id, args| [id, MenuAction.new(id, *args)] }
def MenuActions.at(game, player)
  transform_values {|v|
    cost = v.cost.transform_values {|amount|
      if amount == :f
        amount = game.cost_to_spawn_unit(player.id)
      else
        amount
      end
    }
    MenuAction.new(id: v.id, japanese: v.japanese, cost: cost, build_id: v.build_id, location_type: v.location_type, description: v.description)
  }
end
MenuActions.freeze
