# frozen_string_literal: true

require 'async/websocket/adapters/rails'

class WorldTag < Live::View
  def initialize(...)
    super(...)
  end

  def bind(page)
    super # @page = page

    Async do
      while @page
        update!
        sleep 1
      end
    end
  end

  def render(builder)
    # builder.tag('div', onclick: forward_event) do
      builder.append(<<~"EOF")
        #{rand}
      EOF
  end

  def handle(event)
    pp event
    case event[:type]
    when 'click'
      update!
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
