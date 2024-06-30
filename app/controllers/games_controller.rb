# frozen_string_literal: true

require 'async/websocket/adapters/rails'

class WorldTag < Live::View
  @@turn = Sketch::Turn.new(num: 1, game: Sketch::Game.new(world: Sketch::World.create(size_x: 5, size_y: 8)))
  @@game = @@turn.game
  @@human_focus = nil
  @@human_flush = nil
  @@autoplaying = false

  def initialize(...)
    super(...)
  end

  def bind(page)
    super # @page = page

    # Async do
    #   while @page
    #     update!
    #     sleep 1
    #   end
    # end
  end

  def render(builder)
    builder.append(ERB.new(File.read('app/views/games/_world.html.erb')).result_with_hash(
      {
        turn: @@turn,
        game: @@game,
        human_focus: @@human_focus,
        human_flush: @@human_flush,
        hexes_view: @@game.world.hexes_view,
      },
    ))
  end

  def handle(event)
    @@human_flush = nil

    pp event
    case event[:type]
    when 'click'
      (x, y) = [event[:x], event[:y]]
      if @@human_focus&.loc == Sketch::Location.new(x, y)
        @@human_focus = nil
      elsif human = @@game.world.unitss[Sketch::Human].find { _1.loc == Sketch::Location.new(x, y) }
        @@human_focus = human
      elsif @@human_focus&.moveable(world: @@game.world)&.include?(Sketch::Location.new(x, y))
        @@human_focus.move!(Sketch::Location.new(x, y))
        @@human_focus = nil
      elsif @@human_focus
        @@human_flush = "そのマスには何もできません: #{{
          focus: @@human_focus.to_json,
          moveable: @@human_focus.moveable(world: @@game.world),
          neighbours: @@game.world.neighbours(@@human_focus.loc),
          loc: Sketch::Location.new(x, y),
        }}"
      else
        @human_flush = 'Must not happen'
      end
      update!
    when 'autoplay'
      return if @@autoplaying
      @@autoplaying = true
      Async do
        player = Sketch::Human
        until winner = @@game.winner do
          pa = @@game.building_actions(player).sample
          @@game.building_action!(player, pa) if pa
          update!; sleep 0.1

          @@turn.actionable_units[player].each do |u|
            uas = @@game.unit_actions(player, u)
            ua = Sketch::AI.unit_action_for(@@game, player, u, uas)
            @@turn.unit_action!(player, u, ua) if ua
          end
          update!; sleep 0.1

          player = player.opponent

          if player == Sketch::Human
            @@game.tick!
            @@turn = @@turn.next
            sleep 0.5
          end
        end
        update!
      end
    end
  end
end

class GamesController < ApplicationController
  before_action :set_game, only: %i[ show ]

  # GET /games or /games.json
  def index
    @games = Game.all
  end

  # GET /games/1 or /games/1.json
  def show
    @world_tag = WorldTag.new('world')
  end

  skip_before_action :verify_authenticity_token, only: :live

  RESOLVER = Live::Resolver.allow(WorldTag)
  def live
    self.response = Async::WebSocket::Adapters::Rails.open(request) do |connection|
      Live::Page.new(RESOLVER).run(connection)
    end
  end

  # GET /games/new
  def new
    @game = Game.new
  end

  # POST /games or /games.json
  def create
    @game = Game.new(game_params)

    respond_to do |format|
      if @game.save
        format.html { redirect_to game_url(@game), notice: "Game was successfully created." }
        format.json { render :show, status: :created, location: @game }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_game
      @game = Game.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def game_params
      params.require(:game).permit(:player_name)
    end
end
