# frozen_string_literal: true

class World
  # size_x Integer
  # size_y Integer
  # unitss {human: [(Integer, Integer)], pest: [(Integer, Integer)]}
  # buildings {human: [Building], ...}
  def initialize(size_x:, size_y:, unitss:, buildings:)
    @size_x = size_x
    @size_y = size_y
    @unitss = unitss

    # Returns Building
    def buildings.at(loc)
      self.values.flatten(1).find { _1.loc == loc }
    end
    def buildings.delete_at(loc)
      self.each do |_, bs|
        return if bs.reject! { _1.loc == loc }
      end
      nil
    end
    def buildings.of(player_id, bid)
      self[player_id].find { _1.id == bid }
    end

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
    trees = vacant_locs.shift(size_x * size_y * 0.2)
    ponds = vacant_locs.shift(size_x * size_y * 0.1)
    rocks = vacant_locs.shift(size_x * size_y * 0.05)

    buildings = {
      human: [
        Building.new(player_id: :human, id: :base, loc: bases[:human]),
      ],
      pest: [
        Building.new(player_id: :pest, id: :base, loc: bases[:pest]),
      ],
      world: [
        *trees.map { Building.new(player_id: :world, id: :tree, loc: _1) },
        *ponds.map { Building.new(player_id: :world, id: :pond, loc: _1) },
        *rocks.map { Building.new(player_id: :world, id: :rock, loc: _1) },
      ]
    }
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
  # * trailはターン数を消費しない
  # * treeはHP分だけターン数を消費する
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
        building = buildings.at(nloc)

        next if not_passable?(player, nloc) && building.hp.nil?

        visited[nloc] =
          if building&.player == player && building&.id == :trail
            dist
          else
            dist + 1
          end

        # 追加の移動ターンを計算するため、not_passable?でhpがある場合はそのHP分だけ追加のターンを使う
        if not_passable?(player, nloc) && building&.hp
          visited[nloc] += building.hp
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

