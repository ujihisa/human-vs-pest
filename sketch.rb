# frozen_string_literal: true

class World
  # size_x Integer
  # size_y Integer
  # base1 (Integer, Integer)
  # base2 (Integer, Integer)
  # units1 [(Integer, Integer)]
  # units2 [(Integer, Integer)]
  # trees [(Integer, Integer)]
  # ponds [(Integer, Integer)]
  def initialize(size_x:, size_y:, base1:, base2:, units1:, units2:, trees:, ponds:)
    @size_x = size_x
    @size_y = size_y
    @base1 = base1
    @base2 = base2
    @units1 = units1
    @units2 = units2
    @trees = trees
    @ponds = ponds
  end
  attr_reader :size_x, :size_y, :base1, :base2, :units1, :units2, :trees, :ponds

  def self.create(size_x:, size_y:)
    base1 = [size_x / 2, 0]
    base2 = [size_x / 2, size_y - 1]

    trees = Array.new(size_x * size_y / 10) {
      10.times.find {
        xy = [rand(size_x), rand(size_y)]
        if xy != base1 && xy != base2
          break xy
        end
      } or raise 'Could not find a suitable tree location'
    }

    ponds = Array.new(size_x * size_y / 20) {
      10.times.find {
        xy = [rand(size_x), rand(size_y)]
        if xy != base1 && xy != base2 && !trees.include?(xy)
          break xy
        end
      } or raise 'Could not find a suitable pond location'
    }

    new(
      size_x: size_x,
      size_y: size_y,
      base1: base1,
      base2: base2,
      units1: [Unit.new(x: base1[0], y: base1[1], hp: 10)],
      units2: [Unit.new(x: base2[0], y: base2[1], hp: 10)],
      trees: trees,
      ponds: ponds,
    )
  end

  def not_passable
    @ponds + @units1.map {|unit| [unit.x, unit.y]} + @units2.map {|unit| [unit.x, unit.y]}
  end

  def draw
    @size_y.times do |y|
      print '|'
      @size_x.times do |x|
        building =
          case [x, y]
          when @base1
            '🏠'
          when @base2
            '🪺'
          when *@ponds
            '🌊'
          when *@trees
            '🌲'
          end
        unit =
          case [x, y]
          when *@units1.map {|unit| [unit.x, unit.y]}
            '🧍'
          when *@units2.map {|unit| [unit.x, unit.y]}
            '🐛'
          end

        case [building, unit]
        in [nil, nil]
          print ' 　 '
        in [nil, unit]
          print " #{unit} "
        in [building, nil]
          print " #{building} "
        in [building, unit]
          print "[#{unit}]"
        else
          raise 'Must not happen'
        end
      end
      puts '|'
    end
    puts('-' * (@size_x * 4 + 2))
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
    @money1 = 10
    @money2 = 10
    @wood1 = 0
    @wood2 = 0
    @turn = 0
  end
  attr_reader :world, :money1, :money2, :wood1, :wood2, :turn

  def player_actions1
    player_actions = []
    if @money1 >= 2 && !@world.units1.any? {|unit| [unit.x, unit.y] == @world.base1}
      player_actions << [:spawn_unit, nil]
    end
    player_actions
  end

  def player_actions2
    player_actions = []
    if @money2 >= 2 && !@world.units2.any? {|unit| [unit.x, unit.y] == @world.base2}
      player_actions << [:spawn_unit, nil]
    end
    player_actions
  end

  def player_action1!(action)
    case action
    in [:remove_building, [x, y]]
      raise 'Not implemented yet'
    in [:spawn_unit, nil]
      raise 'Invalid money' if @money1 < 2
      raise 'Invalid base' if @world.units1.any? {|unit| [unit.x, unit.y] == @world.base1}
      @money1 -= 2
      @world.units1 << Unit.new(x: @world.base1[0], y: @world.base1[1], hp: 10)
    end
  end

  def player_action2!(action)
    case action
    in [:remove_building, [x, y]]
      raise 'Not implemented yet'
    in [:spawn_unit, nil]
      raise 'Invalid money' if @money2 < 2
      raise 'Invalid base' if @world.units2.any? {|unit| [unit.x, unit.y] == @world.base1}
      @money2 -= 2
      @world.units2 << Unit.new(x: @world.base2[0], y: @world.base2[1], hp: 10)
    end
  end

  def unit_actions1
    @world.units1.flat_map {|unit|
      unit.moveable(world: @world).map {|xy|
        [:move_unit, [unit, xy]]
      }
    }
  end

  def unit_actions2
    @world.units2.flat_map {|unit|
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
    puts "Money1: #{@money1}, Wood1: #{@wood1}"
    puts "Money2: #{@money2}, Wood2: #{@wood2}"
    puts "Turn: #{@turn}"
    @world.draw
  end
end

game = Game.new(world: World.create(size_x: 10, size_y: 10))
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
