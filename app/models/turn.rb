# frozen_string_literal: true

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
      raise 'must not happen: The game is already finished'
    else
      @game.tick!
      Turn.new(num: @num + 1, game: @game)
    end
  end
end

