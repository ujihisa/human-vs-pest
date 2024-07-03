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
      if game.world.unitss[unit.player.opponent.id].find { loc == _1.loc }
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
  # unitss {human: [(Integer, Integer)], pest: [(Integer, Integer)]}
  # buildings {human: [Building], ...}
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
      human: [
        Building.new(player: Human, id: :base, loc: bases[:human]),
      ],
      pest: [
        Building.new(player: Pest, id: :base, loc: bases[:pest]),
      ],
      world: [
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
    def buildings.of(player_id, bid)
      self[player_id].find { _1.id == bid }
    end

    new(
      size_x: size_x,
      size_y: size_y,
      unitss: {
        human: [Unit.new(player_id: :human, loc: bases[:human])],
        pest: [Unit.new(player_id: :pest, loc: bases[:pest])],
      },
      buildings: buildings,
    )
  end

  # loc0からloc1にunitがmoveするのに必要なターン数
  # trailはターン数を消費しない
  def move_distance(player_id, loc0, loc1)
    return 0 if loc0 == loc1
    player = Player.find(player_id)

    q = [loc0]
    visited = { loc0 => 0 }
    until q.empty?
      loc = q.shift
      dist = visited[loc]

      neighbours(loc).each do |nloc|
        next if visited[nloc]
        next if not_passable?(player, nloc)

        building = buildings.at(nloc)
        visited[nloc] =
          if building&.player == player && building&.id == :trail
            dist
          else
            dist + 1
          end
        return visited[nloc] if nloc == loc1
        q << nloc
      end
    end

    raise "Must not happen: unreachable"
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

        human = @unitss[:human].find { _1.loc == Location.new(x, y) }
        pest = @unitss[:pest].find { _1.loc == Location.new(x, y) }
        unit =
          if human
            "🧍#{human.hp}"
            # "🧍#{move_distance(:human, @buildings.of(:human, :base).loc, loc)}"
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
      "#{resource.emoji}x#{amount} "
    else
      "#{resource.emoji}" * amount
    end
  end
end

class GameState
  def initialize(world:)
    @world = world
    @resources = {
      human: {
        seed: PlayerResource.new(resource_id: :seed, amount: 1),
        wood: PlayerResource.new(resource_id: :wood , amount: 0),
        ore: PlayerResource.new(resource_id: :ore, amount: 0),
        money: PlayerResource.new(resource_id: :money, amount: 0),
      },
      pest: {
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
    if @world.buildings.of(:human, :base).nil?
      Pest
    elsif @world.buildings.of(:pest, :base).nil?
      Human
    else
      nil
    end
  end

  def cost_to_spawn_unit(player)
    # (1), 2, 4, 8, 16, ...
    # 2 ** @total_spawned_units[player]

    # (1), 2, 3, 4, 5...
    @total_spawned_units[player]
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
    )
    @world.draw
  end
end

module AI
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
      ua = uas.select {|_, a| a.id == :move }.min_by {|loc, _|
        game.world.move_distance(player.id, loc, game.world.buildings.of(player.opponent.id, :base).loc)
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
  require_relative 'unit'

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
        break if game.winner
      end
    end
    turn.draw

    break if game.winner
    turn = turn.next
  end
end
