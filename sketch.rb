# frozen_string_literal: true

class World
  # size_x Integer
  # size_y Integer
  # bases {human: [(Integer, Integer)], pest: [(Integer, Integer)]}
  # unitss {human: [(Integer, Integer)], pest: [(Integer, Integer)]}
  # trees [(Integer, Integer)]
  # ponds [(Integer, Integer)]
  def initialize(size_x:, size_y:, bases:, unitss:, trees:, ponds:)
    @size_x = size_x
    @size_y = size_y
    @bases = bases
    @unitss = unitss
    @trees = trees
    @ponds = ponds
  end
  attr_reader :size_x, :size_y, :bases, :unitss, :trees, :ponds

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

    new(
      size_x: size_x,
      size_y: size_y,
      bases: bases,
      unitss: {
        human: [Unit.new(x: bases[:human][0], y: bases[:human][1], hp: 10)],
        pest: [Unit.new(x: bases[:pest][0], y: bases[:pest][1], hp: 10)],
      },
      trees: trees,
      ponds: ponds,
    )
  end

  def not_passable
    @ponds + @unitss[:human].map {|unit| [unit.x, unit.y]} + @unitss[:pest].map {|unit| [unit.x, unit.y]}
  end

  def draw
    @size_y.times do |y|
      print '|'
      @size_x.times do |x|
        building =
          case [x, y]
          when @bases[:human]
            '🏠'
          when @bases[:pest]
            '🪺'
          when *@ponds
            '🌊'
          when *@trees
            '🌲'
          else
            '　'
          end
        unit =
          case [x, y]
          when *@unitss[:human].map {|unit| [unit.x, unit.y]}
            '🧍'
          when *@unitss[:pest].map {|unit| [unit.x, unit.y]}
            '🐛'
          else
            '　'
          end
        print "#{building}#{unit}|"
      end
      puts
      puts('.' * (@size_x * 5 + 1))
    end
    puts('=' * (@size_x * 5 + 1))
  end
end

class Unit
  def initialize(x:, y:, hp:)
    @x = x
    @y = y
    @hp = hp
  end
  attr_reader :x, :y, :hp

  # returns [(Integer, Integer)]
  def moveable(world:)
    [
      [x - 1, y],
      [x + 1, y],
      [x, y - 1],
      [x, y + 1],
      [x - 1, y + 1],
      [x, y + 1],
      [x + 1, y + 1],
    ].select {|x, y|
      [x, y] != [@x, @y] &&
        0 <= x && x < world.size_x && 0 <= y && y < world.size_y &&
        !world.not_passable.include?([x, y])
    }
  end

  def move!(xy)
    @x = xy[0]
    @y = xy[1]
  end
end

class Game
  def initialize(world:)
    @world = world
    @moneys = {
      human: 0,
      pest: 0,
    }
    @woods = {
      human: 0,
      pest: 0,
    }
    @turn = 0
  end
  attr_reader :world, :moneys, :woods, :turn

  # returns [[Symbol, Object]]
  def player_actions(player)
    player_actions = []
    if @moneys[player] >= 2 && !@world.unitss[player].any? {|unit| [unit.x, unit.y] == @world.bases[player] }
      player_actions << [:spawn_unit, nil]
    end
    player_actions
  end

  def player_action!(player, action)
    case action
    in [:remove_building, [x, y]]
      raise 'Not implemented yet'
    in [:spawn_unit, nil]
      raise 'Invalid money' if @moneys[player] < 2
      raise 'Invalid base' if @world.unitss[player].any? {|unit| [unit.x, unit.y] == @world.bases[player]}
      @moneys[player] -= 2
      @world.unitss[player] << Unit.new(x: @world.bases[player][0], y: @world.bases[player][1], hp: 10)
    end
  end

  # returns [[Symbol, Object]]
  def unit_actions(player)
    @world.unitss[player].to_h {|unit|
      moves = unit.moveable(world: @world).map {|xy|
        [:move, xy]
      }
      harvest_woods =
        if @world.trees.include?([unit.x, unit.y])
          [[:harvest_wood, nil]]
        else
          []
        end
      [unit, moves + harvest_woods]
    }
  end

  def unit_action!(player, unit, action)
    case action
    in [:move, xy]
      unit.move!(xy)
    in [:harvest_wood, nil]
      @woods[player] += 3
      @world.trees.delete([unit.x, unit.y])
    end
  end

  def tick!
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

game = Game.new(world: World.create(size_x: 4, size_y: 8))
game.draw

10.times do
  pa = game.player_actions(:human).sample
  game.player_action!(:human, pa) if pa

  pa = game.player_actions(:pest).sample
  game.player_action!(:pest, pa) if pa

  uas_by_unit = game.unit_actions(:human)
  uas_by_unit.each do |u, uas|
    ua = uas.find { _1 == :harvest_wood }
    ua ||= uas.sample
    game.unit_action!(:human, u, ua) if ua
  end

  uas_by_unit = game.unit_actions(:pest)
  uas_by_unit.each do |u, uas|
    ua = uas.find { _1 == :harvest_wood }
    ua ||= uas.sample
    game.unit_action!(:pest, u, ua) if ua
  end

  game.tick!
  game.draw
end
