# frozen_string_literal: true

Building = Data.define(:id, :loc, :hp) do
  def initialize(id:, loc:, hp: nil)
    hp ||=
      case id
      when :base, :seeds0, :seeds, :flowers, :fruits, :landmine, :trail, :pond
        nil
      when :tree
        3
      when :rock # 未実装
        3
      when :barricade # 未実装
        3
      else
        raise "Unknown Building type: #{id}"
      end
    super(id:, loc:, hp:)
  end

  # ownerは無条件で通行可能なので、ownerでないと仮定する
  def passable?
    ![:tree, :pond, :rock, :barricade].include?(id)
  end

  def view(player)
    building_table = {
      Human => {
        base: '🏠',
        fruits: '🍓',
        flowers: '🌷',
        seeds: '🌱',
        seeds0: '🌱',
      },
      Pest => {
        base: '🕳',
        fruits: '🍄',
        flowers: '🦠',
        seeds: '🧬',
        seeds0: '🧬',
      },
      :world => {
        tree: '🌲',
        pond: '🌊',
      },
    }
    building_table[player][id]
  end
end
