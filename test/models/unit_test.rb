# frozen_string_literal: true

require 'minitest/autorun'

class TestUnit < Minitest::Test
  def setup
    GameState # autoload

    buildings = {
      human: [
        Building.new(Human, :base, Location.new(2, 0), nil),
        Building.new(Human, :trail, Location.new(2, 0), nil)
      ],
      pest: [
        Building.new(Pest, :base, Location.new(2, 7), nil),
      ],
    }
    @unit = Unit.new(player_id: :human, loc: Location.new(2, 0))
    @world = World.new(size_x: 5, size_y: 8, unitss: {human: [@unit], pest: []}, buildings: buildings)
  end

  def test_initialize
    assert_equal :human, @unit.player_id
    assert_equal Location.new(2, 0), @unit.loc
    assert_equal 8, @unit.hp
  end

  def test_max_hp
    # |　　 |.....|🏠　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　🧍8|.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|🕳　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # ===============================
    @unit.loc = Location.new(1, 1)
    assert_equal 6, @unit.max_hp(@world)
  end

  def test_moveable
    # |　　 |.....|🏠　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　🧍8|.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|🛤　 |.....|　　 |.....|
    # |　　 |.....|🛤　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|　　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # |　　 |.....|🕳　 |.....|　　 |
    # |.....|　　 |.....|　　 |.....|
    # ===============================
    @world.buildings[:human] << Building.new(player_id: :human, id: :trail, loc: Location.new(1, 2))
    @world.buildings[:human] << Building.new(player_id: :human, id: :trail, loc: Location.new(2, 3))
    @unit.loc = Location.new(1, 1)

    expected_locations =
      [[1, 0], [0, 1], [2, 1], [0, 2], [1, 2], [2, 2], [0, 3], [1, 3], [2, 3], [3, 2], [3, 3], [2, 4]].
      map { Location.new(_1, _2) }
    assert_equal expected_locations, @unit.moveable(world: @world)
  end

  def test_dead
    refute @unit.dead?
    @unit.hp = 0
    assert @unit.dead?
  end
end
