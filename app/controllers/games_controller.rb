# frozen_string_literal: true

require 'async/websocket/adapters/rails'

class WorldTag < Live::View
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
    # builder.tag('div', onclick: forward_event) do
    builder.append(ERB.new(<<~'EOF').result)
      <div style="height: 640px; border: solid 1px black" onclick="live.forward('world', {type: 'click', clientX: event.clientX, clientY: event.clientY});">
        <%- 8.times do |y| %>
          <%- 5.times do |x| %>
            <% padding_top = x.even? ? 64*y : 64*y + 32 %>
            <% padding_right = 48*x %>
            <% background = [*['nil']*10, 'tree', 'tree', 'pond'].sample %>
            <div style="position: absolute; left: 0px, right: 0, bottom: 0, height: 64px; width: 64px; padding: <%= padding_top %>px <%= padding_right %>px;">
              <%= ActionController::Base.helpers.image_tag("backgrounds/#{background}.png", style: 'height: 64px; width: 64px;') %>
              <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%,-50%); font-size: 32px;">
                <%= '🧍' if [x, y] == [3, 2] %>
                <%= '🐛' if [x, y] == [2, 7] %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
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
