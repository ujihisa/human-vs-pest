# frozen_string_literal: true

require 'async/websocket/adapters/rails'

class WorldTag < Live::View
  @@turn = Turn.new(num: 1, game: GameState.new(world: World.create(size_x: 5, size_y: 8)))
  @@game = @@turn.game
  @@human_focus = nil
  @@human_flush = nil
  @@completed = { Human => false, Pest => false }
  @@autoplaying = false
  @@pest_ai_stared = false
  @@menu_action = nil

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

    # TODO: とりあえずいまは害虫側は強制的にAI実行する
    if !@@pest_ai_stared
      @@pest_ai_stared = true
      Async do
        until @@game.winner do
          player = Pest
          while ((action, locs) = @@turn.menu_actionable_actions(player).first) # TODO: sample
            @@turn.menu_action!(player, action, locs.sample)
          end
          sleep 1

          @@turn.actionable_units[player].each do |u|
            locs = @@turn.unit_actionable_locs(player, u)
            ua = AI.unit_action_for(@@game, player, u, locs)
            @@turn.unit_action!(player, u, ua.first, ua.last) if ua
          end
          @@completed[player] = true
          sleep 1

          if @@completed.all? { _2 }
            @@completed = { Human => false, Pest => false }
            @@human_focus = nil
            @@turn = @@turn.next
          end
        end
      end
    end
  end

  def render(builder)
    builder.append(ERB.new(File.read('app/views/games/_world.html.erb')).result_with_hash(
      {
        turn: @@turn,
        game: @@game,
        human_focus: @@human_focus,
        human_flush: @@human_flush,
        completed: @@completed,
        hexes_view: @@game.world.hexes_view,
        menu_action: @@menu_action,
      },
    ))
  end

  def handle(event)
    @@human_flush = nil
    player = Human # TODO: 今は人間側しか操作できない...

    pp event
    case event[:type]
    when 'click'
      loc = Location.new(event[:x], event[:y])
      case @@human_focus
      when Unit
        if @@turn.unit_actionable_locs(Human, @@human_focus).include?(loc)
          action = @@turn.game.reason_unit_action(Human, @@human_focus, loc)
          @@turn.unit_action!(Human, @@human_focus, loc, action)
        end
        @@human_focus = nil
      when Building
        # b = @@turn.actionable_buildings[Human].find { _1.loc == loc }
        # @@turn.building_action!(Human, b) if @@game.reason_building_action(Human, b)
        # @@human_focus = nil
      else # nil
        if @@menu_action
          locs = @@turn.menu_actionable_actions(player)[@@menu_action.id]
          if locs && locs.include?(loc)
            @@turn.menu_action!(player, @@menu_action.id, loc)
          else
            @@menu_action = nil
          end
        else
          if human = @@turn.actionable_units[Human].find { _1.loc == loc }
            @@human_focus = human
          end
        end
      end
    when 'menu'
      @@human_focus = nil

      menu_action = Turn::MENU_ACTIONS[event[:menu].to_sym]
      case menu_action
      when nil
        # do nothing
      when @@menu_action
        @@menu_action = nil
      else
        @@menu_action = menu_action
      end
    when 'rightclick'
      @@human_focus = nil
      @@menu_action = nil
    when 'complete'
      case event[:player]
      when 'Human'
        player = Human
      when 'Pest'
        player = Pest
      else
        raise "Must not happen: Unknown player: #{event[:player]}"
      end

      @@completed[player] = true
      update!

      if @@completed.all? { _2 }
        @@completed = { Human => false, Pest => false }
        @@human_focus = nil
        @@turn = @@turn.next
      end
    when 'autoplay_all'
      return if @@autoplaying
      @@autoplaying = true
      Async do
        players = [Human, Pest]
        loop do
          players.each do |player|
            while ((action, locs) = @@turn.menu_actionable_actions(player).first) # TODO: sample
              @@turn.menu_action!(player, action, locs.sample)
            end
            update!; sleep 0.1

            @@turn.actionable_units[player].each do |u|
              locs = @@turn.unit_actionable_locs(player, u)
              ua = AI.unit_action_for(@@game, player, u, locs)
              @@turn.unit_action!(player, u, ua.first, ua.last) if ua
            end
            update!; sleep 0.1
          end
          sleep 0.3

          break if @@game.winner
          @@turn = @@turn.next
        end
      end
    when 'reset'
      exit
    end
    update!
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
