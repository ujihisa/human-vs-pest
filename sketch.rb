# frozen_string_literal: true

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
  # size_x Integer
  # size_y Integer
  # unitss {Human => [(Integer, Integer)], Pest => [(Integer, Integer)]}
  # environments {trees: [(Integer, Integer)], ponds: [(Integer, Integer)]}
  # buildings {Human => {base: [(Integer, Integer)], ...}, ...}
  def initialize(size_x:, size_y:, unitss:, environments:, buildings:)
    @size_x = size_x
    @size_y = size_y
    @unitss = unitss
    @environments = environments
    @buildings = buildings
  end
  attr_reader :size_x, :size_y, :unitss, :environments, :buildings

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
      size_x: size_x,
      size_y: size_y,
      unitss: {
        Human => [Unit.new(xy: bases[:human], hp: 10)],
        Pest => [Unit.new(xy: bases[:pest], hp: 10)],
      },
      environments: {
        trees: trees,
        ponds: ponds,
      },
      buildings: buildings,
    )
  end

  def neighbours(xy0)
    [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
      [-1, 1],
      [0, 1],
      [1, 1],
    ].map {|x, y|
      [xy0[0] + x, xy0[1] + y]
    }.select {|x, y|
      0 <= x && x < @size_x && 0 <= y && y < @size_y
    }
  end

  def not_passable
    @environments[:ponds] + @unitss[Human].map(&:xy) + @unitss[Pest].map(&:xy)
  end

  def draw
    @size_y.times do |y|
      print '|'
      @size_x.times do |x|
        environment_table = {
          ponds: '🌊',
          trees: '🌲',
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
        unit_table = {
          Human => '🧍',
          Pest => '🐛',
        },
        background =
          @environments.filter_map {|type, xys|
            if xys.include?([x, y])
              environment_table[type]
            end
          }.first
        background ||=
          @buildings.filter_map {|p, bs|
            bs.filter_map {|b, xys|
              if xys.include?([x, y])
                building_table[p][b]
              end
            }.first
          }.first
        background ||= '　'
        unit =
          case [x, y]
          when *@unitss[Human].map(&:xy)
            '🧍'
          when *@unitss[Pest].map(&:xy)
            '🐛'
          else
            '　'
          end
        print "#{background}#{unit}|"
      end
      puts
      puts('.' * (@size_x * 5 + 1))
    end
    puts('=' * (@size_x * 5 + 1))
  end
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
      !world.not_passable.include?([x, y])
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
      @world.unitss[player] << Unit.new(xy: @world.buildings[player][:base][0], hp: 10)
    end
  end

  # returns [[Symbol, Object]]
  def unit_actions(player)
    @world.unitss[player].to_h {|unit|
      actions = []

      moves = unit.moveable(world: @world).each {|xy|
        actions << [:move, xy]
      }

      if @world.environments[:trees].include?(unit.xy)
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
          @world.unitss[player.opponent].flat_map {|unit|
            if neighbours.include?(unit.xy)
              actions << [:melee_attack, unit]
            end
          }
        end

      @world.buildings[player.opponent].each do |b, xys|
        if xys.include?(unit.xy)
          actions << [:destroy, nil]
        end
      end

      [unit, actions]
    }
  end

  private def vacant?(xy)
    buildings = @world.buildings.values.flat_map { _1.values.flatten(1) }
    environments = @world.environments.values
    !(environments + buildings).include?(xy)
  end

  def unit_action!(player, unit, action)
    case action
    in [:move, xy]
      unit.move!(xy)
    in [:harvest_woods, nil]
      @woods[player] += 3
      @world.environments[:trees].delete(unit.xy)
    in [:farming, nil]
      @world.buildings[player][:seeds0] << unit.xy
    in [:harvest_fruit, nil]
      @world.buildings[player][:fruits].delete(unit.xy)
      @moneys[player] += 3
    in [:melee_attack, target_unit]
      # p 'Melee attack!'
      target_unit.hp -= 5

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
    )
    @world.draw
  end
end

game = Game.new(world: World.create(size_x: 5, size_y: 8))
game.draw

module AI
  def self.unit_action_for(game, player, u, uas)
    ua = uas.find { [:destroy, :melee_attack].include?(_1[0]) }
    ua ||=
      if game.world.unitss[player].size < 2
        uas.sample
      else
        uas.select {|a, _| a == :move }.min_by {|_, xy|
          distance(xy, game.world.buildings[player.opponent][:base][0])
        }
      end
    ua
  end

  private_class_method def self.distance(xy0, xy1)
    Math.sqrt((xy1[0] - xy0[0]) ** 2 + (xy1[1] - xy0[1]) ** 2)
  end
end

50.times do
  pa = game.player_actions(Human).sample
  game.player_action!(Human, pa) if pa

  pa = game.player_actions(Pest).sample
  game.player_action!(Pest, pa) if pa

  uas_by_unit = game.unit_actions(Human)
  uas_by_unit.each do |u, uas|
    ua = AI.unit_action_for(game, Human, u, uas)
    game.unit_action!(Human, u, ua) if ua
  end

  uas_by_unit = game.unit_actions(Pest)
  uas_by_unit.each do |u, uas|
    ua = AI.unit_action_for(game, Pest, u, uas)
    game.unit_action!(Pest, u, ua) if ua
  end

  game.tick!
  game.draw
end
