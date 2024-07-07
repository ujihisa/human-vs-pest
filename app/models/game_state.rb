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
    raise "Negative amount: #{self}" if amount + n < 0
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
    @total_spawned_units = { human: 1, pest: 1 }
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

  def cost_to_spawn_unit(player_id)
    # (1), 2, 4, 8, 16, ...
    # 2 ** @total_spawned_units[player]

    # (1), 2, 3, 4, 5...
    @total_spawned_units.fetch(player_id)
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
        when :bomb0
          bs[i] = b.with(id: :bomb)
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

if __FILE__ == $0
  require_relative 'world'
  require_relative 'turn'
  require_relative 'location'
  require_relative 'building'
  require_relative 'unit'
  require_relative 'a_i'
  require_relative 'menu_actions'

  turn = Turn.new(
    num: 1,
    game: GameState.new(world: World.create(size_x: 5, size_y: 8)),
  )
  game = turn.game
  turn.draw

  players = [Human, Pest]
  loop do
    players.each do |player|
      while ((action, loc) = AI.find_menu_action(turn, player, turn.menu_actionable_actions(player)))
        turn.menu_action!(player, action, loc)
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
