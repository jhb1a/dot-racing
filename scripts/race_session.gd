# Autoload (RaceSession): the single owner of balances, bets and race history.
# It outlives scene reloads, so money and performance ratings carry over between races.
# Every call names the player, and the UI only asks and displays - it never moves money
# itself - so in multiplayer these calls can become requests to the host.
extends Node

signal balance_changed(player_id)
signal bets_changed

const LOCAL_PLAYER_ID = 1
# Rating points for finishing 1st, 2nd, 3rd; races not run yet count as neutral
const PLACE_SCORES = [100.0, 50.0, 0.0]
const NEUTRAL_RATING = 50.0

var starting_balance = 1000
# House money on every dot, so a dot nobody backs doesn't pay infinitely and
# a lone bettor isn't only betting against themselves
var house_seed_per_dot = 2000
# How much the performance rating changes a dot's push strength (0.15 = up to ±15%)
var performance_effect = 0.15
var history_length = 5

var balances = {}
# player_id -> {"dot": DotColor, "amount": int}; one dot per player per race
var bets = {}
# Finishing order (DotColor values) of recent races, oldest first
var history = []
var betting_open = true
var locked_multipliers = {}

func get_dots():
	return Racer.DotColor.values()

func get_balance(player_id) -> int:
	if not balances.has(player_id):
		balances[player_id] = starting_balance
	return balances[player_id]

# The player's bet this race, or null
func get_bet(player_id):
	return bets.get(player_id)

# Backs `dot` with `amount`, replacing any earlier bet this race. 0 removes the bet.
func place_bet(player_id, dot, amount) -> bool:
	if not betting_open or dot not in get_dots():
		return false
	amount = clampi(amount, 0, get_balance(player_id))
	if amount == 0:
		bets.erase(player_id)
	else:
		bets[player_id] = {"dot": dot, "amount": amount}
	bets_changed.emit()
	return true

func get_pool(dot) -> float:
	var pool = float(house_seed_per_dot)
	for bet in bets.values():
		if bet.dot == dot:
			pool += bet.amount
	return pool

func get_total_pool() -> float:
	var total = 0.0
	for dot in get_dots():
		total += get_pool(dot)
	return total

# 3x when money is spread evenly over the 3 dots; less for popular dots, more for unpopular ones.
# Fixed once the race starts.
func get_payout_multiplier(dot) -> float:
	if not betting_open:
		return locked_multipliers.get(dot, 0.0)
	return get_total_pool() / get_pool(dot)

# Race is starting: fix the payouts and take the stakes
func lock_bets():
	if not betting_open:
		return
	for dot in get_dots():
		locked_multipliers[dot] = get_payout_multiplier(dot)
	betting_open = false
	for player_id in bets:
		balances[player_id] = get_balance(player_id) - bets[player_id].amount
		balance_changed.emit(player_id)

# Race is over: pay the winners, record the result, reopen betting.
# Returns player_id -> {dot, amount, multiplier, payout}.
func settle_race(finish_order) -> Dictionary:
	lock_bets()
	var results = {}
	var winner = finish_order[0]
	for player_id in bets:
		var bet = bets[player_id]
		var multiplier = locked_multipliers[bet.dot]
		var payout = roundi(bet.amount * multiplier) if bet.dot == winner else 0
		balances[player_id] += payout
		results[player_id] = {"dot": bet.dot, "amount": bet.amount, "multiplier": multiplier, "payout": payout}
		balance_changed.emit(player_id)

	history.append(finish_order.duplicate())
	while history.size() > history_length:
		history.pop_front()

	bets.clear()
	locked_multipliers.clear()
	betting_open = true
	bets_changed.emit()
	return results

# Finishing places (1 = won) in recent races, newest first
func get_recent_places(dot) -> Array:
	var places = []
	for i in range(history.size() - 1, -1, -1):
		places.append(history[i].find(dot) + 1)
	return places

# 0-100: average of the last `history_length` results, with missing races counted as neutral
func get_performance_rating(dot) -> float:
	var places = get_recent_places(dot)
	var total = NEUTRAL_RATING * (history_length - places.size())
	for place in places:
		total += PLACE_SCORES[place - 1]
	return total / history_length

# Push strength multiplier from the rating: neutral 1.0, up to 1 ± performance_effect
func get_force_multiplier(dot) -> float:
	return 1.0 + (get_performance_rating(dot) - NEUTRAL_RATING) / NEUTRAL_RATING * performance_effect
