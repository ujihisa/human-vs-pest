# frozen_string_literal: true

require 'async/queue'
require 'async/websocket/adapters/rails'

class WorldTag < Live::View
  @@turn = Turn.new(num: 1, game: GameState.new(world: World.create(size_x: 5, size_y: 8)))
  @@completed = { Human => false, Pest => false }
  @@autoplaying = false
  @@ai_stared = false
  @@subscribers = {}

  # both static and websocket
  def initialize(...)
    super(...)

    @your_player = @data[:your_player_id]&.then { Player.find(_1.to_sym) }
    @ai_player = @data[:ai_player_id]&.then { Player.find(_1.to_sym) }
  end

  private def publish_update!
    @@subscribers.each_value do |q|
      q << :update!
    end
  end

  # websocket only
  def bind(page)
    super # @page = page

    @@subscribers[self] = Async::Queue.new

    Async do
      while mes = @@subscribers[self].dequeue
        break unless @page
        case mes
        when :update!
          update!
        else
          raise "Unknown message: #{mes}"
        end
      end
      @@subscribers.delete(self)
    end

    # AI側を強制実行
    if @ai_player && !@@ai_stared
      @@ai_stared = true
      Async do
        until @@turn.game.winner do
          while ((action, loc) = AI.find_menu_action(@@turn, @ai_player, @@turn.menu_actionable_actions(@ai_player)))
            @@turn.menu_action!(@ai_player, action, loc)
          end
          publish_update!; sleep 1

          @@turn.actionable_units[@ai_player.id].each do |u|
            locs = @@turn.unit_actionable_locs(@ai_player, u)
            (loc, ua) = AI.unit_action_for(@@turn.game, @ai_player, u, locs)
            @@turn.unit_action!(@ai_player, u, loc, ua.id) if ua
          end
          @@completed[@ai_player] = true
          publish_update!; sleep 1

          if @@completed.all? { _2 }
            @@completed = { Human => false, Pest => false }
            @focus = nil
            @@turn = @@turn.next
            publish_update!
          end
        end
      end
    end
  end

  def render(builder)
    builder.append(ERB.new(File.read('app/views/games/_world.html.erb')).result_with_hash(
      {
        your_player: @your_player,
        turn: @@turn,
        help_focus_loc: @help_focus_loc,
        focus: @focus,
        completed: @@completed,
        hexes_view: @@turn.game.world.hexes_view(exclude_background: true),
        menu_action_focus: @menu_action_focus,
      },
    ))
  end

  def handle(event)
    pp event
    case event[:type]
    when 'click'
      loc = Location.new(event[:x], event[:y])
      @help_focus_loc = (@help_focus_loc == loc) ? nil : loc

      if @focus
        if @@turn.unit_actionable_locs(@your_player, @focus).include?(loc)
          action = UnitAction.reason(@@turn.game, @focus, loc)
          @@turn.unit_action!(@your_player, @focus, loc, action.id)
        end
        @focus = nil
      else
        if @menu_action_focus
          locs = @@turn.menu_actionable_actions(@your_player)[@menu_action_focus.id]
          if locs && locs.include?(loc)
            @@turn.menu_action!(@your_player, @menu_action_focus.id, loc)
          end
          @menu_action_focus = nil
        else
          if human = @@turn.actionable_units[@your_player.id].find { _1.loc == loc }
            @focus = human
          end
        end
      end
    when 'menu'
      @focus = nil

      menu_action_focus = MenuActions[event[:menu].to_sym]
      case menu_action_focus
      when nil
        # do nothing
      when @menu_action_focus
        @menu_action_focus = nil
      else
        @menu_action_focus = menu_action_focus
      end
    when 'rightclick'
      @focus = nil
      @menu_action_focus = nil
    when 'complete'
      @@completed[@your_player] = true
      @focus = nil
      @menu_action_focus = nil
      publish_update!

      if @@completed.all? { _2 }
        @@completed = { Human => false, Pest => false }
        @@turn = @@turn.next
      end
    when 'autoplay_all'
      return if @@autoplaying
      @@autoplaying = true
      Async do
        players = [Human, Pest]
        loop do
          players.each do |player|
            while ((action, loc) = AI.find_menu_action(@@turn, player, @@turn.menu_actionable_actions(player)))
              @@turn.menu_action!(player, action, loc)
            end
            publish_update!; sleep 0.1

            @@turn.actionable_units[player.id].each do |u|
              locs = @@turn.unit_actionable_locs(player, u)
              (loc, ua) = AI.unit_action_for(@@turn.game, player, u, locs)
              @@turn.unit_action!(player, u, loc, ua.id) if ua
            end
            publish_update!; sleep 0.1
          end
          sleep 0.3

          break if @@turn.game.winner
          @@turn = @@turn.next
        end
      end
    when 'reset'
      exit
    end
    publish_update!
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
    your_player_id =
      case session[:you]
      when @game.human_you_name
        :human
      when @game.pest_you_name
        :pest
      end
    ai_player_id =
      if @game.human_you_name.nil?
        :human
      elsif @game.pest_you_name.nil?
        :pest
      end
    @world_tag = WorldTag.new('world', your_player_id: your_player_id, ai_player_id: ai_player_id)
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
    if session[:you].nil?
      redirect_to you_path
    end
    @game = Game.new
  end

  # POST /games or /games.json
  def create
    @game = Game.new(
      human_you_name: game_params[:human_you_name].presence,
      pest_you_name: game_params[:pest_you_name].presence,
    )

    respond_to do |format|
      if @game.save
        # format.html { redirect_to game_url(@game), notice: "Game was successfully created." }
        format.html { redirect_to game_url(@game) }
      else
        format.html { render :new, status: :unprocessable_entity }
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
      params.require(:game).permit(:human_you_name, :pest_you_name)
    end
end
