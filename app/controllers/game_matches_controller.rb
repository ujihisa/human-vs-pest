# frozen_string_literal: true

require 'async/queue'
require 'async/websocket/adapters/rails'

# TODO: シリアライズするなどで、DBに保存する?
GAME = {}

class WorldTag < Live::View
  # both static and websocket
  def initialize(...)
    super(...)
    game_match_id = @data[:game_match_id].to_i # to_i必須。WorldTag.new からはIntegerで、Live::Page.newからはStringで呼ばれる。
    GAME[game_match_id] ||= {
      turn: Turn.new(num: 1, game: GameState.new(world: World.create(size_x: 5, size_y: 8))),
      completed: { Human => false, Pest => false },
      autoplaying: false,
      ai_started: false,
      subscribers: {},
    }
    @g = GAME[game_match_id] # just as an alias

    @your_player = @data[:your_player_id]&.then { Player.find(_1.to_sym) }
    @ai_player = @data[:ai_player_id]&.then { Player.find(_1.to_sym) }
    @notify_turn_next = nil
    # @debug_click_location = {x: 0, y: 0}
  end

  private def publish_update!
    @g[:subscribers].each_value do |q|
      q << :update!
    end
  end

  private def set_notify_turn_next!
    @notify_turn_next = @g[:turn].num
    Async do
      sleep 1
      if @notify_turn_next == @g[:turn].num
        @notify_turn_next = nil
      end
    end
  end

  # websocket only
  def bind(page)
    super # @page = page

    @g[:subscribers][self] = Async::Queue.new

    Async do
      while mes = @g[:subscribers][self].dequeue
        break unless @page
        case mes
        when :update!
          update!
        else
          raise "Unknown message: #{mes}"
        end
      end
      @g[:subscribers].delete(self)
    end

    # AI側を強制実行
    if @ai_player && !@g[:ai_started]
      @g[:ai_started] = true
      Async do
        until @g[:turn].game.winner do
          while ((action, loc) = AI.find_menu_action(@g[:turn], @ai_player, @g[:turn].menu_actionable_actions(@ai_player)))
            @g[:turn].menu_action!(@ai_player, action, loc)
          end
          publish_update!; sleep 1

          @g[:turn].actionable_units[@ai_player.id].each do |u|
            locs = @g[:turn].unit_actionable_locs(@ai_player, u)
            (loc, ua) = AI.unit_action_for(@g[:turn].game, @ai_player, u, locs)
            @g[:turn].unit_action!(@ai_player, u, loc, ua.id) if ua
          end
          @g[:completed][@ai_player] = true
          publish_update!; sleep 1

          # TODO: pubsubかbarrierでawait
          if @g[:completed].all? { _2 }
            @g[:completed] = { Human => false, Pest => false }
            @focus = nil
            @g[:turn] = @g[:turn].next
            set_notify_turn_next!
            publish_update!
          end
        end
      end
    end
  end

  def render(builder)
    builder.append(ERB.new(File.read('app/views/game_matches/_world.html.erb')).result_with_hash(
      {
        your_player: @your_player,
        turn: @g[:turn],
        help_focus_loc: @help_focus_loc,
        focus: @focus,
        completed: @g[:completed],
        hexes_view: @g[:turn].game.world.hexes_view(exclude_background: true),
        menu_action_focus: @menu_action_focus,
        notify_turn_next: @notify_turn_next,
        # debug_click_location: @debug_click_location,
      },
    ))
  end

  def handle(event)
    pp event
    case event[:type]
    when 'click'
      # @debug_click_location = {x: event[:clientX], y: event[:clientY]}

      loc = Location.new(event[:x], event[:y])
      @help_focus_loc = (@help_focus_loc == loc) ? nil : loc

      if @focus
        if @g[:turn].unit_actionable_locs(@your_player, @focus).include?(loc)
          action = UnitAction.reason(@g[:turn].game, @focus, loc)
          @g[:turn].unit_action!(@your_player, @focus, loc, action.id)
        end
        @focus = @help_focus_loc = nil
      else
        if @menu_action_focus
          locs = @g[:turn].menu_actionable_actions(@your_player)[@menu_action_focus.id]
          if locs && locs.include?(loc)
            @g[:turn].menu_action!(@your_player, @menu_action_focus.id, loc)
          end
          @menu_action_focus = @help_focus_loc = nil
        else
          if human = @g[:turn].actionable_units[@your_player.id].find { _1.loc == loc }
            @focus = human
          end
        end
      end
    when 'menu'
      @focus = nil

      menu_action_focus = MenuActions.at(@g[:turn].game, @your_player)[event[:menu].to_sym]
      case menu_action_focus
      when nil
        # do nothing
      when @menu_action_focus
        @menu_action_focus = nil
      else
        @menu_action_focus = menu_action_focus
      end
    when 'rightclick', 'key_esc'
      @help_focus_loc = nil
      @focus = nil
      @menu_action_focus = nil
    when 'complete', 'key_enter'
      @g[:completed][@your_player] = true
      @focus = @help_focus_loc = nil
      publish_update!

      if @g[:completed].all? { _2 }
        @g[:completed] = { Human => false, Pest => false }
        @g[:turn] = @g[:turn].next
        set_notify_turn_next!
      end
    when 'autoplay_all'
      return if @g[:autoplaying]
      @g[:autoplaying] = true
      Async do
        players = [Human, Pest]
        loop do
          players.each do |player|
            while ((action, loc) = AI.find_menu_action(@g[:turn], player, @g[:turn].menu_actionable_actions(player)))
              @g[:turn].menu_action!(player, action, loc)
            end
            publish_update!; sleep 0.1

            @g[:turn].actionable_units[player.id].each do |u|
              locs = @g[:turn].unit_actionable_locs(player, u)
              (loc, ua) = AI.unit_action_for(@g[:turn].game, player, u, locs)
              @g[:turn].unit_action!(player, u, loc, ua.id) if ua
            end
            publish_update!; sleep 0.1
          end
          sleep 0.3

          break if @g[:turn].game.winner
          @g[:turn] = @g[:turn].next
          set_notify_turn_next!
        end
      end
    when 'reset'
      exit
    when 'debug_unit_actionable_again'
      human_units = @g[:turn].game.world.unitss[:human]
      @g[:turn].actionable_units[:human] = human_units
      human_units.each do |u|
        u.hp = u.max_hp(@g[:turn].game.world)
      end
      # humanのresourcesのwoodを+10
      @g[:turn].game.resources[:human].then { _1[:wood] = _1[:wood].add_amount(10) }
    end
    publish_update!
  end
end

class GameMatchesController < ApplicationController
  before_action :set_game_match, only: %i[ show ]

  # GET /games or /games.json
  def index
    @game_matches = GameMatch.where(finished_at: nil).order(id: :desc).all
    @finished_game_matches = GameMatch.where.not(finished_at: nil).order(id: :desc).all
  end

  # GET /games/1 or /games/1.json
  def show
    your_player_id =
      case session[:you]
      when nil
        nil
      when @game_match.human_you_name
        :human
      when @game_match.pest_you_name
        :pest
      end
    ai_player_id =
      if @game_match.human_you_name.nil?
        :human
      elsif @game_match.pest_you_name.nil?
        :pest
      end
    @world_tag = WorldTag.new('world', game_match_id: @game_match.id, your_player_id: your_player_id, ai_player_id: ai_player_id)
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
    @game_match = GameMatch.new
  end

  # POST /games or /games.json
  def create
    @game_match = GameMatch.new(
      human_you_name: game_params[:human_you_name].presence,
      pest_you_name: game_params[:pest_you_name].presence,
    )

    respond_to do |format|
      if @game_match.save
        # format.html { redirect_to game_match_url(@game_match), notice: "GameMatch was successfully created." }
        format.html { redirect_to game_match_url(@game_match) }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_game_match
      @game_match = GameMatch.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def game_params
      params.require(:game_match).permit(:human_you_name, :pest_you_name)
    end
end
