# frozen_string_literal: true

Player = Data.define(:id, :japanese, :opponent_id) do
  def self.find(id)
    [Human, Pest].find { _1.id == id } or
      raise "Must not happen: Unknown player: #{id}"
  end

  def opponent
    self.class.find(opponent_id)
  end
end

Human = Player.new(id: :human, japanese: '人間', opponent_id: :pest)
Pest = Player.new(id: :pest, japanese: '害虫', opponent_id: :human)

UnitAction = Data.define(:id, :japanese) do
  def self.find(id)
    UNIT_ACTIONS.fetch(id)
  end

  # nil | UnitAction
  def self.reason(game, unit, loc)
    return nil if game.winner

    if 1 < unit.hp
      if game.world.unitss[unit.player.opponent].find { loc == _1.loc }
        return UnitAction.find(:melee_attack)
      end
    end

    if unit.moveable(world: game.world).include?(loc)
      return UnitAction.find(:move)
    end

    b = game.world.buildings.at(loc)
    if b
      case b.id
      when :tree
        return UnitAction.find(:harvest_woods)
      end
    end

    nil
  end
end

UNIT_ACTIONS = {
  move: UnitAction.new(:move, '移動'),
  melee_attack: UnitAction.new(:melee_attack, '近接攻撃'),
  harvest_woods: UnitAction.new(:harvest_woods, '伐採'),
}

class World
  # size_x Integer
  # size_y Integer
  # unitss {Human => [(Integer, Integer)], Pest => [(Integer, Integer)]}
  # buildings {Human => [Building], ...}
  def initialize(size_x:, size_y:, unitss:, buildings:)
    @size_x = size_x
    @size_y = size_y
    @unitss = unitss
    @buildings = buildings
  end
  attr_reader :size_x, :size_y, :unitss, :buildings

  def self.create(size_x:, size_y:)
    bases = {
      human: Location.new(size_x / 2, 0),
      pest: Location.new(size_x / 2, size_y - 1),
    }

    vacant_locs = [*0...size_x].product([*1...size_y.-(1)]).map { Location.new(*_1) }
    vacant_locs.shuffle!
    trees = vacant_locs.shift(size_x * size_y / 8)
    ponds = vacant_locs.shift(size_x * size_y / 10)

    buildings = {
      Human => [
        Building.new(player: Human, id: :base, loc: bases[:human]),
      ],
      Pest => [
        Building.new(player: Pest, id: :base, loc: bases[:pest]),
      ],
      :world => [
        *trees.map { Building.new(player: :world, id: :tree, loc: _1) },
        *ponds.map { Building.new(player: :world, id: :pond, loc: _1) },
      ]
    }
    # Returns Building
    def buildings.at(loc)
      self.values.flatten(1).find { _1.loc == loc }
    end
    def buildings.delete_at(loc)
      self.each do |_, bs|
        return if bs.reject! { _1.loc == loc }
      end
      raise "Nothing was deleted #{loc}"
    end
    def buildings.of(player, bid)
      self[player].find { _1.id == bid }
    end

    new(
      size_x: size_x,
      size_y: size_y,
      unitss: {
        Human => [Unit.new(player_id: :human, loc: bases[:human], hp: 8)],
        Pest => [Unit.new(player_id: :pest, loc: bases[:pest], hp: 8)],
      },
      buildings: buildings,
    )
  end

  def neighbours(loc)
    raise "Missing loc" unless loc

    # hexなので現在位置に応じて非対称
    diffs =
      if loc.x.odd?
        [
          [0, -1],

          [-1, 0],
          [1, 0],

          [-1, 1], # これ
          [0, 1],
          [1, 1], # これ
        ]
      else
        [
          [-1, -1], # これ
          [0, -1],
          [1, -1], # これ

          [-1, 0],
          [1, 0],

          [0, 1],
        ]
      end

    diffs.map {|dx, dy|
      Location.new(loc.x + dx, loc.y + dy)
    }.select {|loc|
      loc in Location(nx, ny)
      (0...@size_x).cover?(nx) && (0...@size_y).cover?(ny)
    }
  end

  def not_passable?(player, loc)
    raise "Missing player" unless player
    raise "Missing loc" unless loc

    b = @buildings.at(loc)
    if b && player != b.player && !b.passable?
      return true
    end
  end

  # [[String]]
  def hexes_view(exclude_background:)
    Array.new(@size_y) {|y|
      Array.new(@size_x) {|x|
        loc = Location.new(x, y)
        b = @buildings.at(loc)
        background =
          if b
            if exclude_background && b.background_img
              '　'
            else
              b.view
            end
          else
            '　'
          end

        human = @unitss[Human].find { _1.loc == Location.new(x, y) }
        pest = @unitss[Pest].find { _1.loc == Location.new(x, y) }
        unit =
          if human
            "🧍#{human.hp}"
          elsif pest
            raise "duplicated unit location: #{x}, #{y}" if human
            "🐛#{pest.hp}"
          else
            '　 '
          end
        "#{background}#{unit}"

        # "#{x}, #{y}"
      }
    }
  end

  def draw
    hexes_view = hexes_view(exclude_background: false)

    (0...@size_y).each do |y|
      print '|'
      (0.step(@size_x - 1, 2)).each do |x|
        print '|.....|' if x > 0
        print hexes_view[y][x]
      end
      puts '|'
      (1.step(@size_x - 1, 2)).each do |x|
        print '|.....|'
        print hexes_view[y][x]
      end
      puts '|.....|'
    end
    puts('=' * (@size_x * 6 + 1))
  end
end

Unit = Struct.new(:player_id, :loc, :hp) do
  def player
    Player.find(player_id)
  end

  # returns [(Integer, Integer)]
  # TODO: 小道が複数あるときにも再帰的に対応。そのためにunit testを追加
  def moveable(world:)
    world.neighbours(loc).select {|loc|
      !world.not_passable?(player, loc)
    }.flat_map {|loc|
      b = world.buildings.at(loc)
      if b && b.player == player && b.id == :trail
        [loc] + world.neighbours(loc).select {|loc|
          !world.not_passable?(player, loc)
        }
      else
        [loc]
      end
    }.select {|loc|
      !world.unitss.values.flatten(1).any? { _1.loc == loc }
    }
  end

  def dead?
    hp <= 0
  end
end

Resource = Data.define(:id, :emoji)
RESOURCES = {
  seed: Resource.new(id: :seed, emoji: '🌱'),
  wood: Resource.new(id: :wood, emoji: '🪵'),
  ore: Resource.new(id: :ore, emoji: '🪨'),
  money: Resource.new(id: :money, emoji: '💰'),
}.freeze


PlayerResource = Data.define(:resource_id, :amount) do
  def resource
    RESOURCES[resource_id]
  end

  def add_amount(n)
    self.class.new(resource_id: resource_id, amount: amount + n)
  end

  def view
    if 5 < amount
      "#{resource.emoji}x#{amount}"
    else
      "#{resource.emoji}" * amount
    end
  end
end

class GameState
  def initialize(world:)
    @world = world
    @resources = {
      Human => {
        seed: PlayerResource.new(resource_id: :seed, amount: 1),
        wood: PlayerResource.new(resource_id: :wood , amount: 10),
        ore: PlayerResource.new(resource_id: :ore, amount: 0),
        money: PlayerResource.new(resource_id: :money, amount: 0),
      },
      Pest => {
        seed: PlayerResource.new(resource_id: :seed, amount: 1),
        wood: PlayerResource.new(resource_id: :wood , amount: 0),
        ore: PlayerResource.new(resource_id: :ore, amount: 0),
        money: PlayerResource.new(resource_id: :money, amount: 0),
      }
    }
    @total_spawned_units = { Human => 1, Pest => 1 }
  end
  attr_reader :world, :resources, :turn, :total_spawned_units

  # Returns `nil` if the game is still ongoing
  def winner
    if @world.buildings.of(Human, :base).nil?
      Pest
    elsif @world.buildings.of(Pest, :base).nil?
      Human
    else
      nil
    end
  end

  # (1), 2, 4, 8, 16, ...
  def cost_to_spawn_unit(player)
    2 ** @total_spawned_units[player]
  end

  def tick!
    @world.buildings.each do |_, bs|
      bs.each.with_index do |b, i|
        case b.id
        when :seeds0
          bs[i] = b.with(id: :seeds)
        when :seeds
          bs[i] = b.with(id: :flowers)
        when :flowers
          bs[i] = b.with(id: :fruits)
        end
      end
    end
  end

  def draw
    p(
      resources: @resources.transform_values {|rs| rs.values.map(&:amount) },
      # num_units: @world.unitss.transform_values(&:size),
    )
    @world.draw
  end
end

module AI
  # [Location, UnitAction] | nil
  def self.unit_action_for(game, player, u, locs)
    uas = locs.map {|loc| [loc, UnitAction.reason(game, u, loc)] }

    # セルフケア最優先
    if u.hp < 3
      return nil
    end

    # 次いで近接攻撃
    if ua = uas.find { [:melee_attack].include?(_1[1].id) }
      return ua
    end

    # 相手が自拠点に近づいてきていれば戻る
    min_dist = game.world.unitss[player.opponent].map {|u| distance(u.loc, game.world.buildings.of(player, :base).loc) }.min
    if min_dist && min_dist < 4
      ua = uas.select {|_, a| a.id == :move }.min_by {|loc, _|
        distance(loc, game.world.buildings.of(player, :base).loc)
      }
      return ua if ua
    end

    # 相手より人数が多ければrage mode
    if game.world.unitss[player.opponent].size < game.world.unitss[player].size
      ua = uas.select {|_, a| a.id == :move }.min_by {|loc, _|
        distance(loc, game.world.buildings.of(player.opponent, :base).loc)
      }
      ua
    else
      # じわじわ成長を狙う
      ua = uas.select {|_, a| a.id != :move }.sample
      ua ||= uas.sample
      ua
    end
  end

  private_class_method def self.distance(loc0, loc1)
    Math.sqrt((loc1.x - loc0.x) ** 2 + (loc1.y - loc0.y) ** 2)
  end
end

if __FILE__ == $0
  require_relative 'turn'
  require_relative 'location'
  require_relative 'building'

  turn = Turn.new(
    num: 1,
    game: GameState.new(world: World.create(size_x: 5, size_y: 8)),
  )
  game = turn.game
  turn.draw

  players = [Human, Pest]
  loop do
    players.each do |player|
      while ((action, locs) = turn.menu_actionable_actions(player).first) # TODO: sample
        turn.menu_action!(player, action, locs.sample)
      end

      turn.actionable_units[player.id].each do |u|
        locs = turn.unit_actionable_locs(player, u)
        (loc, ua) = AI.unit_action_for(game, player, u, locs)
        turn.unit_action!(player, u, loc, ua.id) if ua
      end
    end
    turn.draw

    break if game.winner
    turn = turn.next
  end
end
