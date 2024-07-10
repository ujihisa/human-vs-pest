# frozen_string_literal: true

require 'forwardable'

Building = Data.define(:player_id, :id, :loc, :hp, :_bd) do
  BuildingDefault = Data.define(:id, :human_emoji, :pest_emoji, :passable, :init_hp, :desc)

  defaults = [
    [:tree,      '🌲', '🌲', false, 1..3, 'HPの数だけ伐採できます。伐採すると木材が得られます'],
    [:rock,      '🪨', '🪨', false, 3..5, 'HPの数だけ採掘できます。採掘すると鉱石が得られます'],
    [:barricade, '🚧', '🕸', false, 3,    '自分は通れるけど相手だけ通行不能です。初期HPは3で、HPの数だけ攻撃を耐えます。'],
    [:pond,      '🌊', '🌊', false, nil,  '通行不能です'],
    [:base,      '🏠', '🕳', true,  nil,  'これを失った陣営がゲームオーバーです。自拠点の上でターンを終了すると、そのユニットはHPが4回復します。'],
    [:fruits,    '🍓', '🍄', true,  nil,  '自陣営のものならば、ユニットがそこに立つだけで自動で収穫してくれます。収穫すると、種とお金が得られます。<br>収穫後は勝手に🌱に戻ります。'],
    [:flowers,   '🌷', '🦠', true,  nil,  '1ターン後に収穫可能です'],
    [:seeds,     '🌱', '🧬', true,  nil,  '2ターン後に収穫可能です'],
    [:seeds0,    '🌱', '🧬', true,  nil,  '3ターン後に収穫可能です'],
    [:trail,     '🛤', '🛤', true,  nil,  '自陣営のみ、1ターンで移動できる距離が増えます (最大3)'],
    [:bomb0,     '💣', '💣', true,  1,    '次ターンから、任意のタイミングで起爆できます'],
    [:bomb,      '💣', '💣', true,  1,    '起爆すると、敵味方関係なく周囲1マス範囲を全て破壊しつくします'],
    # [:sapling,   '🌱', '🌱', true,  nil,  '10ターン後に木になります'],
  ]

  BUILDING_DEFAULTS = defaults.map {|id, human_emoji, pest_emoji, passable, init_hp, desc|
    [id, BuildingDefault.new(id, human_emoji, pest_emoji, passable, init_hp, desc)]
  }.to_h

  extend Forwardable
  def_delegators(:_bd, :human_emoji, :pest_emoji, :passable, :desc)

  def initialize(id:, player_id:, loc:, hp: nil, _bd: nil)
    # 引数の_bdはwith()のために必要だけど、単に無視する。idを主としたい。
    _bd =  BUILDING_DEFAULTS.fetch(id)

    hp ||=
      case _bd.init_hp
      when Range
        rand(_bd.init_hp)
      else
        _bd.init_hp
      end

    super(player_id: player_id, id:, loc:, hp:, _bd:)
  end

  def player
    return nil if player_id == :world
    Player.find(player_id)
  end

  # ownerは無条件で通行可能なので、ownerでないと仮定する
  def passable?
    BUILDING_DEFAULTS.fetch(id).passable
  end

  def view
    case player_id
    when :human, :world
      _bd.human_emoji
    when :pest
      _bd.pest_emoji
    else
      raise "Must not happen: invalid player_id #{player_id}"
    end
  end

  def background_img
    ["backgrounds/#{player_id}_#{id}.png", "backgrounds/#{id}.png"].find {|path|
      File.exist?("app/assets/images/#{path}")
    }
  end
end
