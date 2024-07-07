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

    whitelist = bases.values.flat_map {|l| _neighbours(l, size_x, size_y) }

    vacant_locs = [*0...size_x].product([*0...size_y]).map { Location.new(*_1) } - whitelist
    vacant_locs.shuffle!
    trees = vacant_locs.shift(size_x * size_y * 0.2)
    ponds = vacant_locs.shift(size_x * size_y * 0.1)
    rocks = vacant_locs.shift(size_x * size_y * 0.1)

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
  # * trailのときはさらに次までいけるが、1ターンで最大でも3マスまで
  # * treeなどはHP分だけターン数を消費
  def move_distance(player_id, loc0, loc1)
    return 0 if loc0 == loc1
    player = Player.find(player_id)

    q = PriorityQueue.new
    q.push([0, 0, loc0])  # [f, depth, loc]
    g_score = { loc0 => 0 } # スタートからの最小コストの推定、ようするにここまでに必要なターン数
    f_score = { loc0 => heuristic(loc0, loc1, 0) } # g + ゴールからの最小コストの推定h

    until q.empty?
      (_, depth, current) = q.pop

      return g_score[current] if current == loc1

      neighbours(current).each do |nloc|
        new_g_score = g_score[current]
        building = buildings.at(nloc)
        next if not_passable?(player, nloc) && building.hp.nil?

        if building&.player == player && building&.id == :trail
          case depth
          when 0
            # これから移動しはじめる
            new_g_score += 1
            new_depth = depth + 1
          when 1
            new_depth = depth + 1
          when 2
            # 3マスごとに初期化
            new_depth = 0
          else
            raise "Must not happen: depth: #{depth}"
          end
        else
          if depth == 0
            # 普通のケース
            new_g_score += 1
          else
            # trailから出たときのこと。trailに入った時点でターンを支払っているので、ここでは無料
          end
          new_depth = 0 # trailじゃないから初期化
        end

        # 追加の移動ターンを計算するため、not_passable?でhpがある場合はそのHP分だけ追加のターンを使う
        if not_passable?(player, nloc) && building&.hp
          new_g_score += building.hp
        end

        if !g_score.key?(nloc) || new_g_score < g_score[nloc]
          # 明らかに改善するケース
          g_score[nloc] = new_g_score
          f_score[nloc] = new_g_score + heuristic(nloc, loc1, new_depth)
          q.push([f_score[nloc], new_depth, nloc])
        elsif new_g_score == g_score[nloc]
          new_f_score = new_g_score + heuristic(nloc, loc1, new_depth)
          if new_f_score < f_score[nloc]
            # ターン数は同じだけどdepthが小さそうなケース
            q.push([f_score[nloc], new_depth, nloc])
          end
        end
      end
    end

    raise "Must not happen: unreachable"
  end

  private def heuristic(loc0, loc1, depth)
    bonus = depth == 0 ? 0 : (1 - depth/3r)
    Math.sqrt((loc1.x - loc0.x) ** 2 + (loc1.y - loc0.y) ** 2) - bonus
  end

  def self._neighbours(loc, size_x, size_y)
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
      (0...size_x).cover?(loc.x) && (0...size_y).cover?(loc.y)
    }
  end

  def neighbours(loc)
    raise "Missing loc" unless loc

    World._neighbours(loc, @size_x, @size_y)
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

  class PriorityQueue
    def initialize
      @es = [nil]
    end

    def push(element)
      @es << element
      bubble_up(@es.size - 1)
    end

    def pop
      exchange(1, @es.size - 1)
      max = @es.pop
      bubble_down(1)
      max
    end

    def empty?
      @es.size == 1
    end

    private def bubble_up(index)
      parent_index = index / 2
      return if index <= 1
      return if @es[parent_index].first <= @es[index].first
      exchange(index, parent_index)
      bubble_up(parent_index)
    end

    private def bubble_down(index)
      child_index = index * 2
      return if child_index > @es.size - 1
      not_the_last_element = child_index < @es.size - 1
      (left, right) = [@es[child_index], @es[child_index + 1]]
      child_index += 1 if not_the_last_element && right.first < left.first
      return if @es[index].first <= @es[child_index].first
      exchange(index, child_index)
      bubble_down(child_index)
    end

    private def exchange(source, target)
      (@es[source], @es[target]) = [@es[target], @es[source]]
    end
  end
  private_constant :PriorityQueue
end
