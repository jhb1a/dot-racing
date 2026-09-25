# Checks the betting and rating logic in race_session.gd without running the game.
# Usage: godot --headless --path . -s res://tools/test_session.gd
extends SceneTree

const SessionScript = preload("res://scripts/race_session.gd")
const RED = Racer.DotColor.RED
const GREEN = Racer.DotColor.GREEN
const BLUE = Racer.DotColor.BLUE

var failures = 0

func _initialize():
	test_even_pool_pays_3x()
	test_popular_dot_pays_less()
	test_bets_clamped_and_moved()
	test_lock_and_settle()
	test_ratings()
	print("ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)

func check(condition, description):
	print(("PASS  " if condition else "FAIL  ") + description)
	if not condition:
		failures += 1

func new_session():
	var session = SessionScript.new()
	root.add_child(session)
	return session

func test_even_pool_pays_3x():
	var s = new_session()
	check(is_equal_approx(s.get_payout_multiplier(RED), 3.0), "no bets: every dot pays 3x")
	s.place_bet(1, RED, 500)
	s.place_bet(2, GREEN, 500)
	s.place_bet(3, BLUE, 500)
	check(is_equal_approx(s.get_payout_multiplier(BLUE), 3.0), "even bets: still 3x")
	s.free()

func test_popular_dot_pays_less():
	var s = new_session()
	s.place_bet(1, RED, 1000)
	s.place_bet(2, RED, 1000)
	s.place_bet(3, BLUE, 100)
	check(s.get_payout_multiplier(RED) < 3.0, "popular dot pays under 3x (%.2f)" % s.get_payout_multiplier(RED))
	check(s.get_payout_multiplier(GREEN) > 3.0, "unbacked dot pays over 3x (%.2f)" % s.get_payout_multiplier(GREEN))
	s.free()

func test_bets_clamped_and_moved():
	var s = new_session()
	s.place_bet(1, RED, 5000)
	check(s.get_bet(1).amount == 1000, "bet clamped to the $1000 balance")
	s.place_bet(1, BLUE, 200)
	check(s.get_bet(1).dot == BLUE and s.get_bet(1).amount == 200, "new pick replaces the old bet")
	check(s.get_pool(RED) == s.house_seed_per_dot, "old dot's pool no longer has the bet")
	s.place_bet(1, BLUE, 0)
	check(s.get_bet(1) == null, "betting 0 removes the bet")
	s.free()

func test_lock_and_settle():
	var s = new_session()
	s.place_bet(1, RED, 100)
	s.place_bet(2, BLUE, 300)
	var red_multiplier = s.get_payout_multiplier(RED)
	s.lock_bets()
	check(s.get_balance(1) == 900 and s.get_balance(2) == 700, "stakes taken when the race starts")
	check(not s.place_bet(1, GREEN, 50), "no betting while the race runs")
	var results = s.settle_race([RED, GREEN, BLUE])
	var expected = roundi(100 * red_multiplier)
	check(results[1].payout == expected and s.get_balance(1) == 900 + expected, "winner paid $%d" % expected)
	check(results[2].payout == 0 and s.get_balance(2) == 700, "loser paid nothing")
	check(s.bets.is_empty() and s.betting_open, "betting reopens with no bets")
	s.free()

func test_ratings():
	var s = new_session()
	check(is_equal_approx(s.get_performance_rating(RED), 50.0), "rating starts at 50")
	check(is_equal_approx(s.get_force_multiplier(RED), 1.0), "neutral rating: normal push")
	s.settle_race([RED, GREEN, BLUE])
	check(s.get_performance_rating(RED) > 50.0 and s.get_performance_rating(BLUE) < 50.0, "winner up, last place down")
	for i in 5:
		s.settle_race([RED, GREEN, BLUE])
	check(s.history.size() == 5, "only the last 5 races are kept")
	check(is_equal_approx(s.get_performance_rating(RED), 100.0), "5 straight wins: rating 100")
	check(is_equal_approx(s.get_force_multiplier(RED), 1.0 + s.performance_effect), "top rating: max push bonus")
	check(s.get_recent_places(BLUE) == [3, 3, 3, 3, 3], "recent places listed")
	s.settle_race([BLUE, GREEN, RED])
	check(s.get_recent_places(BLUE)[0] == 1, "newest result listed first")
	s.free()
