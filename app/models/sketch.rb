# frozen_string_literal: true

module Sketch
  module Human
    def self.opponent
      Pest
    end
  end

  module Pest
    def self.opponent
      Human
    end
  end

  class World
    # hexes [[Symbol]]
    # size_x Integer
    # size_y Integer
    # unitss {Human => [(Integer, Integer)], Pest => [(Integer, Integer)]}
    # buildings {Human => {base: [(Integer, Integer)], ...}, ...}
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
        human: [size_x / 2, 0],
        pest: [size_x / 2, size_y - 1],
      }

      trees = Array.new(size_x * size_y / 10) {
        10.times.find {
          xy = [rand(size_x), rand(size_y)]
          if xy != bases[:human] && xy != bases[:pest]
            break xy
          end
        } or raise 'Could not find a suitable tree location'
      }

      ponds = Array.new(size_x * size_y / 20) {
        10.times.find {
          xy = [rand(size_x), rand(size_y)]
          if xy != bases[:human] && xy != bases[:pest] && !trees.include?(xy)
            break xy
          end
        } or raise 'Could not find a suitable pond location'
      }

      hexes = Array.new(size_y) {|y|
        Array.new(size_x) {|x|
          case [x, y]
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
        Human => {
          base: [bases[:human]],
          fruits: [],
          flowers: [],
          seeds: [],
          seeds0: [],
        },
        Pest => {
          base: [bases[:pest]],
          fruits: [],
          flowers: [],
          seeds: [],
          seeds0: [],
        },
      }

      new(
        hexes: hexes,
        size_x: size_x,
        size_y: size_y,
        unitss: {
          Human => [Unit.new(xy: bases[:human], hp: 8)],
          Pest => [Unit.new(xy: bases[:pest], hp: 8)],
        },
        buildings: buildings,
      )
    end

    def hex_at(xy)
      @hexes[xy[0]][xy[1]]
    end

    def neighbours(xy)
      (x, y) = xy
      # hexなので現在位置に応じて非対称
      diffs =
        if x.odd?
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
        [x + dx, y + dy]
      }.select {|nx, ny|
        (0...@size_x).cover?(nx) && (0...@size_y).cover?(ny)
      }
    end

    def not_passable?(xy)
      (x, y) = xy
      @hexes[y][x] == :pond ||
        (@unitss[Human].map(&:xy) == xy) ||
        (@unitss[Pest].map(&:xy) == xy)
    end

    def draw
      main = -> (x, y) {
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
        background = environment_table[@hexes[x][y]]
        background ||=
          @buildings.filter_map {|p, bs|
            bs.filter_map {|b, xys|
              if xys.include?([x, y])
                building_table[p][b]
              end
            }.first
          }.first
        background ||= '　'

        human = @unitss[Human].find { _1.xy == [x, y] }
        pest = @unitss[Pest].find { _1.xy == [x, y] }
        unit =
          if human
            "🧍#{human.hp}"
          elsif pest
            raise "duplicated unit location: #{x}, #{y}" if human
            "🐛#{pest.hp}"
          else
            '　 '
          end
        print "#{background}#{unit}"
      }
      # main = -> (x, y) { print "#{x}, #{y}" }

      (0...@size_y).each do |y|
        print '|'
        (0.step(@size_x - 1, 2)).each do |x|
          print '|.....|' if x > 0
          main.(x, y)
        end
        puts '|'
        (1.step(@size_x - 1, 2)).each do |x|
          print '|.....|'
          main.(x, y)
        end
        puts '|.....|'
      end
      puts('=' * (@size_x * 6 + 1))
    end

    # def find_unit_by_xy(xy)
    #   @unitss.values.flatten(1).find { _1.xy == xy }
    # end
  end

  class Unit
    def initialize(xy:, hp:)
      @xy = xy
      @hp = hp
    end
    attr_reader :xy
    attr_accessor :hp

    # returns [(Integer, Integer)]
    def moveable(world:)
      world.neighbours(@xy).select {|x, y|
        !world.not_passable?([x, y]) &&
          !world.unitss.values.flatten(1).any? { _1.xy == [x, y] }
      }
    end

    def move!(xy)
      @xy = xy
    end

    def dead?
      hp <= 0
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

      @turn = 0
    end
    attr_reader :world, :moneys, :woods, :turn

    # returns [[Symbol, Object]]
    def player_actions(player)
      player_actions = []
      cost = @world.unitss[player].size ** 2

      if @moneys[player] >= cost && !@world.unitss[player].any? {|unit| @world.buildings[player][:base].include?(unit.xy) }
        player_actions << [:spawn_unit, nil]
      end

      player_actions
    end

    def player_action!(player, action)
      case action
      in [:remove_building, [x, y]]
        raise 'Not implemented yet'
      in [:spawn_unit, nil]
        cost = @world.unitss[player].size ** 2

        @moneys[player] -= cost
        @world.unitss[player] << Unit.new(xy: @world.buildings[player][:base][0], hp: 8)
      end
    end

    # returns [[Symbol, Object]]
    def unit_actions(player, unit)
      actions = []

      moves = unit.moveable(world: @world).each {|xy|
        actions << [:move, xy]
      }

      if unit.hp < 8
        actions << [:idle, nil]
      end


      if @world.hex_at(unit.xy) == :tree
        actions << [:harvest_woods, nil]
      end

      if vacant?(unit.xy)
        actions << [:farming, nil]
      end

      if @world.buildings[player][:fruits].include?(unit.xy)
        actions << [:harvest_fruit, nil]
      end

      neighbours = @world.neighbours(unit.xy)
      melee_attack =
        if 2 < unit.hp
          @world.unitss[player.opponent].flat_map {|ounit|
            if neighbours.include?(ounit.xy)
              actions << [:melee_attack, ounit]
            end
          }
        end

      @world.buildings[player.opponent].each do |b, xys|
        if xys.include?(unit.xy)
          actions << [:destroy, nil]
        end
      end

      actions
    end

    private def vacant?(xy)
      if @world.hex_at(xy)
        return false
      end

      buildings = @world.buildings.values.flat_map { _1.values.flatten(1) }
      !buildings.include?(xy)
    end

    def unit_action!(player, unit, action)
      case action
      in [:move, xy]
        unit.move!(xy)
      in [:idle, nil]
        unit.hp = [unit.hp + 3, 8].min
      in [:harvest_woods, nil]
        @woods[player] += 3

        # TODO: Dirty hack
        @world.hexes[unit.xy[0]][unit.xy[1]] = nil
      in [:farming, nil]
        @world.buildings[player][:seeds0] << unit.xy
      in [:harvest_fruit, nil]
        @world.buildings[player][:fruits].delete(unit.xy)
        @moneys[player] += 3
      in [:melee_attack, target_unit]
        # p 'Melee attack!'
        target_unit.hp -= 4

        if target_unit.dead?
          # p 'Killed!'
          @world.unitss[player.opponent].delete(target_unit)
        end

        unit.hp -= 2
      in [:destroy, nil]
        @world.buildings[player.opponent].each do |b, xys|
          xys.each do |xy|
            # there should be exactly one
            if xy == unit.xy
              xys.delete(xy)

              case b
              when :base
                self.draw
                p "#{player}'s victory!"
                exit
              end
            end
          end
        end
      end
    end

    def tick!
      @world.buildings.each do |_, b|
        (b[:fruits], b[:flowers], b[:seeds], b[:seeds0]) = [b[:fruits] + b[:flowers], b[:seeds], b[:seeds0], []]
      end
      @turn += 1
    end

    def draw
      p(
        turn: @turn,
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
        ua = uas.select {|a, _| a == :move }.min_by {|_, xy|
          distance(xy, game.world.buildings[player.opponent][:base][0])
        }
        ua
      end
    end

    private_class_method def self.distance(xy0, xy1)
      Math.sqrt((xy1[0] - xy0[0]) ** 2 + (xy1[1] - xy0[1]) ** 2)
    end
  end

  if __FILE__ == $0
    game = Game.new(world: World.create(size_x: 5, size_y: 8))
    game.draw


    80.times do
      pa = game.player_actions(Human).sample
      game.player_action!(Human, pa) if pa

      pa = game.player_actions(Pest).sample
      game.player_action!(Pest, pa) if pa

      game.world.unitss[Human].each do |u|
        uas = game.unit_actions(Human, u)
        ua = AI.unit_action_for(game, Human, u, uas)
        p ua
        game.unit_action!(Human, u, ua) if ua
      end

      game.world.unitss[Pest].each do |u|
        uas = game.unit_actions(Pest, u)
        ua = AI.unit_action_for(game, Pest, u, uas)
        p ua
        game.unit_action!(Pest, u, ua) if ua
      end

      game.tick!
      game.draw
    end
  end
end
