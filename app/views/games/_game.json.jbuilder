json.extract! game, :id, :player_name, :finished_at, :created_at, :updated_at
json.url game_url(game, format: :json)
