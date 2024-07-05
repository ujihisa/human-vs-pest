require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game_match = game_matches(:one)
  end

  test "should get index" do
    get game_matches_url
    assert_response :success
  end

  test "should get new" do
    put(you_url, params: { you_name: 'aaa' })
    assert_response :found

    get new_game_match_url
    assert_response :success
  end

  test "should create game_match" do
    assert_difference("GameMatch.count") do
      post game_matches_url, params: { game_match: { human_you_name: @game_match.human_you_name } }
    end

    assert_redirected_to game_match_url(GameMatch.last)
  end

  test "should show game" do
    get game_match_url(@game_match)
    assert_response :success
  end
end
