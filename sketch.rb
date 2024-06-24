# frozen_string_literal: true

class World
  # size_x Integer
  # size_y Integer
  # bases {human: [(Integer, Integer)], pest: [(Integer, Integer)]}
  # unitss {human: [(Integer, Integer)], pest: [(Integer, Integer)]}
  # unitss[:human] [(Integer, Integer)]
  # unitss[:pest] [(Integer, Integer)]
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

# class Player
#   def initialize(human_or_pest:)
#     @human_or_pest = human_or_pest
#   end
#   attr_reader :human_or_pest
# end

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
      human: 10,
      pest: 10,
    }
    @woods = {
      human: 0,
      pest: 0,
    }
    @turn = 0
  end
  attr_reader :world, :moneys, :woods, :turn

  def player_actions1
    player_actions = []
    if @moneys[:human] >= 2 && !@world.unitss[:human].any? {|unit| [unit.x, unit.y] == @world.bases[:human] }
      player_actions << [:spawn_unit, nil]
    end
    player_actions
  end

  def player_actions2
    player_actions = []
    if @moneys[:pest] >= 2 && !@world.unitss[:pest].any? {|unit| [unit.x, unit.y] == @world.bases[:pest] }
      player_actions << [:spawn_unit, nil]
    end
    player_actions
  end

  def player_action1!(action)
    case action
    in [:remove_building, [x, y]]
      raise 'Not implemented yet'
    in [:spawn_unit, nil]
      raise 'Invalid money' if @moneys[:human] < 2
      raise 'Invalid base' if @world.unitss[:human].any? {|unit| [unit.x, unit.y] == @world.bases[:human]}
      @moneys[:human] -= 2
      @world.unitss[:human] << Unit.new(x: @world.bases[:human][0], y: @world.bases[:human][1], hp: 10)
    end
  end

  def player_action2!(action)
    case action
    in [:remove_building, [x, y]]
      raise 'Not implemented yet'
    in [:spawn_unit, nil]
      raise 'Invalid money' if @moneys[:pest] < 2
      raise 'Invalid base' if @world.unitss[:pest].any? {|unit| [unit.x, unit.y] == @world.bases[:human]}
      @moneys[:pest] -= 2
      @world.unitss[:pest] << Unit.new(x: @world.bases[:pest][0], y: @world.bases[:pest][1], hp: 10)
    end
  end

  def unit_actions1
    @world.unitss[:human].flat_map {|unit|
      unit.moveable(world: @world).map {|xy|
        [:move_unit, [unit, xy]]
      }
    }
  end

  def unit_actions2
    @world.unitss[:pest].flat_map {|unit|
      unit.moveable(world: @world).map {|xy|
        [:move_unit, [unit, xy]]
      }
    }
  end

  def unit_action1!(action)
    case action
    in [:move_unit, [unit, xy]]
      raise 'Invalid move' unless unit.moveable(world: @world).include?(xy)
      unit.move!(xy)
    end
  end

  def unit_action2!(action)
    case action
    in [:move_unit, [unit, xy]]
      raise 'Invalid move' unless unit.moveable(world: @world).include?(xy)
      unit.move!(xy)
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

3.times do
  pa = game.player_actions1.sample
  game.player_action1!(pa) if pa

  pa = game.player_actions2.sample
  game.player_action2!(pa) if pa

  ua = game.unit_actions1.sample
  game.unit_action1!(ua) if ua

  ua = game.unit_actions2.sample
  game.unit_action2!(ua) if ua

  game.tick!
  game.draw
end
