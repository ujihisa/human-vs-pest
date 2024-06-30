# frozen_string_literal: true

module Sketch
  # +→ x
  # ↓
  # y
  #
  # 二次元配列で表現するときは必ずy, xの順になる点に注意
  Location = Data.define(:x, :y) do
    def inspect
      "(#{x}, #{y})"
    end
  end

  module Human
    def self.opponent
      Pest
    end

    def self.japanese
      '人間'
    end
  end

  module Pest
    def self.opponent
      Human
    end

    def self.japanese
      '害虫'
    end
  end

  Building = Data.define(:type, :loc)

  class World
    # hexes [[Symbol]]
    # size_x Integer
    # size_y Integer
    # unitss {Human => [(Integer, Integer)], Pest => [(Integer, Integer)]}
    # buildings {Human => [Building], ...}
    def initialize(hexes:, size_x:, size_y:, unitss:, buildings:)
      @hexes = hexes
      @size_x = size_x
      @size_y = size_y
      @unitss = unitss
      @buildings = buildings
    end
    attr_reader :hexes, :size_x, :size_y, :unitss, :buildings

    def self.create(size_x:, size_y:)
      bases = {
        human: Location.new(size_x / 2, 0),
        pest: Location.new(size_x / 2, size_y - 1),
      }

      trees = Array.new(size_x * size_y / 10) {
        10.times.find {
          loc = Location.new(rand(size_x), rand(size_y))
          if loc != bases[:human] && loc != bases[:pest]
            break loc
          end
        } or raise 'Could not find a suitable tree location'
      }

      ponds = Array.new(size_x * size_y / 20) {
        10.times.find {
          loc = Location.new(rand(size_x), rand(size_y))
          if loc != bases[:human] && loc != bases[:pest] && !trees.include?(loc)
            break loc
          end
        } or raise 'Could not find a suitable pond location'
      }

      hexes = Array.new(size_y) {|y|
        Array.new(size_x) {|x|
          case Location.new(x, y)
          when *trees
            :tree
          when *ponds
            :pond
          else
            nil
          end
        }
      }

      buildings = {
        Human => [Building.new(type: :base, loc: bases[:human])],
        Pest => [Building.new(type: :base, loc: bases[:pest])],
      }
      # Returns (Player, Building)
      def buildings.at(loc)
        self.filter_map {|p, bs|
          b = bs.find { _1.loc == loc }
          [p, b] if b
        }.first
      end
      def buildings.delete_at(loc)
        self.each do |_, bs|
          return if bs.reject! { _1.loc == loc }
        end
        raise "Nothing was deleted #{loc}"
      end
      def buildings.of(player, type)
        self[player].find { _1.type == type }
      end

      new(
        hexes: hexes,
        size_x: size_x,
        size_y: size_y,
        unitss: {
          Human => [Unit.new(loc: bases[:human], hp: 8)],
          Pest => [Unit.new(loc: bases[:pest], hp: 8)],
        },
        buildings: buildings,
      )
    end

    def hex_at(loc)
      raise "Missing loc" unless loc

      @hexes[loc.y][loc.x]
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

    def not_passable?(loc)
      raise "Missing loc" unless loc

      @hexes[loc.y][loc.x] == :pond ||
        (@unitss[Human].map(&:loc) == loc) ||
        (@unitss[Pest].map(&:loc) == loc)
    end

    # [[String]]
    def hexes_view
      environment_table = {
        pond: '🌊',
        tree: '🌲',
      }
      building_table = {
        Human => {
          base: '🏠',
          fruits: '🍓',
          flowers: '🌷',
          seeds: '🌱',
          seeds0: '🌱',
        },
        Pest => {
          base: '🪺',
          fruits: '🍄',
          flowers: '🦠',
          seeds: '🧬',
          seeds0: '🧬',
        }
      }

      Array.new(@size_y) {|y|
        Array.new(@size_x) {|x|
          background = environment_table[@hexes[y][x]]
          background ||= @buildings.at(Location.new(x, y))&.then {|p, b| building_table[p][b.type] }
          background ||= '　'

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
      hexes_view = hexes_view()

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

    # def find_unit_by_xy(loc)
    #   @unitss.values.flatten(1).find { _1.loc == loc }
    # end
  end

  class Unit
    def initialize(loc:, hp:)
      @loc = loc
      @hp = hp
    end
    attr_reader :loc
    attr_accessor :hp

    # returns [(Integer, Integer)]
    def moveable(world:)
      world.neighbours(@loc).select {|loc|
        !world.not_passable?(loc) &&
          !world.unitss.values.flatten(1).any? { _1.loc == loc }
      }
    end

    def move!(loc)
      @loc = loc
    end

    def dead?
      hp <= 0
    end
  end

  class Turn
    def initialize(num:, game:)
      @num = num
      @game = game

      @actionable_units = @game.world.unitss.transform_values(&:dup).dup
      @messages = []
    end
    attr_reader :num, :game, :actionable_units, :messages

    def unit_action!(player, unit, action)
      @messages << "#{player.japanese}: #{unit.loc.inspect}にいるユニットが #{action} しました"

      @game.unit_action!(player, unit, action)
      @actionable_units[player] -= [unit]

      if @game.winner
        @messages << "#{game.winner.japanese} が勝利しました!"
        @actionable_units = { Human => [], Pest => [] }
      end
    end

    def draw
      puts "Turn #{@num}"
      puts @messages
      @game.draw
    end

    def next
      if @game.winner
        nil
      else
        @game.tick!
        Turn.new(num: @num + 1, game: @game)
      end
    end
  end

  class Game
    def initialize(world:)
      @world = world
      @moneys = {
        Human => 0,
        Pest => 0,
      }
      @woods = {
        Human => 0,
        Pest => 0,
      }
    end
    attr_reader :world, :moneys, :woods, :turn

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

    # returns [[Symbol, Object]]
    def building_actions(player)
      building_actions = []
      cost = @world.unitss[player].size ** 2

      if @moneys[player] >= cost && !@world.unitss[player].map(&:loc).include?(@world.buildings.of(player, :base).loc)
        building_actions << [:spawn_unit, nil]
      end

      building_actions
    end

    def building_action!(player, action)
      case action
      in [:remove_building, Location(x, y)]
        raise 'Not implemented yet'
      in [:spawn_unit, nil]
        cost = @world.unitss[player].size ** 2

        @moneys[player] -= cost
        @world.unitss[player] << Unit.new(loc: @world.buildings.of(player, :base).loc, hp: 8)
      end
    end

    # returns [[Symbol, Location]]
    def unit_actions(player, unit)
      return [] if self.winner

      actions = []

       unit.moveable(world: @world).each {|loc|
        actions << [:move, loc]
      }

      if @world.hex_at(unit.loc) == :tree
        actions << [:harvest_woods, unit.loc]
      end

      if vacant?(unit.loc)
        actions << [:farming, unit.loc]
      end

      if @world.buildings.of(player, :fruits)&.loc == unit.loc
        actions << [:harvest_fruit, unit.loc]
      end

      neighbours = @world.neighbours(unit.loc)
      melee_attack =
        if 2 < unit.hp
          @world.unitss[player.opponent].flat_map {|ounit|
            if neighbours.include?(ounit.loc)
              actions << [:melee_attack, ounit.loc]
            end
          }
        end

      (p, _) = @world.buildings.at(unit.loc)
      if p == player.opponent
        actions << [:destroy, unit.loc]
      end

      actions
    end

    private def vacant?(loc)
      if @world.hex_at(loc)
        return false
      end

      @world.buildings.at(loc).nil?
    end

    def unit_action!(player, unit, action)
      case action
      in [:move, loc]
        unit.move!(loc)
      in [:harvest_woods, loc]
        @woods[player] += 3
        @world.hexes[loc.y][loc.x] = nil
      in [:farming, loc]
        @world.buildings[player] << Building.new(type: :seeds0, loc: loc)
      in [:harvest_fruit, loc]
        @world.buildings.delete_at(loc)
        @moneys[player] += 3
      in [:melee_attack, loc]
        target_unit = @world.unitss[player.opponent].find { _1.loc == loc }
        # p 'Melee attack!'
        target_unit.hp -= 4

        if target_unit.dead?
          # p 'Killed!'
          @world.unitss[player.opponent].delete(target_unit)
        end

        unit.hp -= 2
      in [:destroy, loc]
        @world.buildings.delete_at(loc)
      end
    end

    def tick!
      # TODO: 何もしなかったユニットの回復処理を書く

      @world.buildings.each do |_, bs|
        bs.each.with_index do |b, i|
          case b.type
          when :seeds0
            bs[i] = Building.new(type: :seeds, loc: b.loc)
          when :seeds
            bs[i] = Building.new(type: :flowers, loc: b.loc)
          when :flowers
            bs[i] = Building.new(type: :fruits, loc: b.loc)
          end
        end
      end
    end

    def draw
      p(
        moneys: @moneys,
        woods: @woods,
        # num_units: @world.unitss.transform_values(&:size),
      )
      @world.draw
    end
  end

  module AI
    def self.unit_action_for(game, player, u, uas)
      # 破壊と近接攻撃は無条件で最優先
      ua = uas.find { [:destroy, :melee_attack].include?(_1[0]) }
      return ua if ua

      if game.world.unitss[player].size < 3
        # 成長を狙うタイミング
        ua = uas.select {|a, _| a != :move }.sample
        ua ||= uas.sample
        ua
      else
        # 一気に攻撃するタイミング
        ua = uas.select {|a, _| a == :move }.min_by {|_, loc|
          distance(loc, game.world.buildings.of(player.opponent, :base).loc)
        }
        ua
      end
    end

    private_class_method def self.distance(loc0, loc1)
      Math.sqrt((loc1.x - loc0.x) ** 2 + (loc1.y - loc0.y) ** 2)
    end
  end

  if __FILE__ == $0
    turn = Turn.new(
      num: 1,
      game: Game.new(world: World.create(size_x: 5, size_y: 8)),
    )
    game = turn.game
    turn.draw

    players = [Human, Pest]
    while turn = turn.next do
      players.each do |player|
        pa = game.building_actions(player).sample
        game.building_action!(player, pa) if pa

        turn.actionable_units[player].each do |u|
          uas = game.unit_actions(player, u)
          ua = AI.unit_action_for(game, player, u, uas)
          turn.unit_action!(player, u, ua) if ua
        end
      end
      turn.draw
    end
  end
end
