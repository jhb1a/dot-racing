extends Node

const TRACK_COLOR = Color(0.22, 0.22, 0.25)
const WALL_COLOR = Color(0.18, 0.45, 0.22)
const FINISH_LINE_COLOR = Color(1, 1, 1, 0.35)

# Staggered starting grid inside the finish line, like a track race: the inside lane starts
# at the back and the outside lane at the front (the race runs right to left here).
# Which dot gets which spot is shuffled each race.
const START_GRID = [Vector2(39, -326), Vector2(0, -398), Vector2(-39, -470)]

const PodiumScript = preload("res://scripts/podium.gd")
const BettingPanelScript = preload("res://scripts/betting_panel.gd")

@export var total_laps = 5
@export var podium_delay = 1.5
# Seconds of betting before the race starts on its own
@export var betting_duration = 30.0
# Rubber banding: each place behind the leader adds this much to a racer's push strength
# (0.1 = 10% stronger per place), multiplied again once the leader is on the final lap
@export var rubber_band_per_place = 0.15
@export var final_lap_rubber_band_factor = 2.0

var racer_scene = preload("res://scenes/racer.tscn")
var racers = []
var finish_order = []
var race_started = false
var race_over = false
var betting_panel
var betting_time_left = 0.0

@onready var racetrack = $Racetrack
@onready var inner_wall = $Racetrack/InnerWall
@onready var outer_walls = $Racetrack/OuterWalls
@onready var finish_line_shape = $Racetrack/FinishLine/CollisionShape2D
@onready var betting_box = $BettingBox
@onready var betting_container = $BettingBox/Panel
@onready var standings_box = $StandingsBox
@onready var standings_label = %Standings
@onready var balance_label = %BalanceLabel
@onready var ui = $UI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# `-- --laps=N` on the command line shortens the race (for testing)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--laps="):
			total_laps = int(arg.trim_prefix("--laps="))

	outer_walls.add_to_group("outer_wall")
	_draw_track()

	var grid = START_GRID.duplicate()
	grid.shuffle()
	var colors = [Racer.DotColor.RED, Racer.DotColor.GREEN, Racer.DotColor.BLUE]
	for i in colors.size():
		spawn_racer(colors[i], grid[i])

	RaceSession.balance_changed.connect(func(_player_id): _update_balance_label())
	_update_balance_label()

	# `-- --autostart` on the command line skips betting (for testing)
	if "--autostart" in OS.get_cmdline_user_args():
		start_race()
	else:
		_open_betting()

func spawn_racer(color, position):
	var racer = racer_scene.instantiate()
	racer.racer_color = color
	racer.position = position
	racer.performance_multiplier = RaceSession.get_force_multiplier(color)
	add_child(racer)
	racers.append(racer)
	racer.lap_completed.connect(_on_racer_lap_completed)

func _update_balance_label():
	balance_label.text = "Balance: $%d" % RaceSession.get_balance(RaceSession.LOCAL_PLAYER_ID)

func _open_betting():
	betting_panel = BettingPanelScript.new()
	betting_container.add_child(betting_panel)
	betting_panel.setup(racers)
	betting_panel.start_now_pressed.connect(start_race)
	betting_time_left = betting_duration
	betting_panel.set_countdown(ceili(betting_time_left))
	betting_box.show()

func start_race():
	if race_started:
		return
	race_started = true
	RaceSession.lock_bets()
	betting_box.hide()
	standings_box.show()
	for racer in racers:
		racer.start_racing()

func _process(delta):
	if betting_box.visible:
		betting_time_left -= delta
		betting_panel.set_countdown(ceili(betting_time_left))
		if betting_time_left <= 0:
			start_race()
	if not standings_box.visible:
		return
	var standings = get_standings()
	_apply_rubber_banding(standings)
	var text = _build_standings_text(standings)
	# Only touch the label when the order or a lap count changed
	if text != standings_label.text:
		standings_label.text = text

func is_final_lap(standings):
	return standings[0].laps >= total_laps - 1

# The further back a racer is, the harder it gets pushed; finished racers push normally
func _apply_rubber_banding(standings):
	var per_place = rubber_band_per_place
	if is_final_lap(standings):
		per_place *= final_lap_rubber_band_factor
	for place in standings.size():
		var racer = standings[place]
		racer.push_multiplier = 1.0 if racer in finish_order else 1.0 + per_place * place

func _on_racer_lap_completed(racer):
	if racer.laps >= total_laps and racer not in finish_order:
		finish_order.append(racer)
		if finish_order.size() == racers.size():
			_end_race()

func _end_race():
	if race_over:
		return
	race_over = true
	var results = RaceSession.settle_race(finish_order.map(func(racer): return racer.racer_color))
	var result_text = _describe_result(results.get(RaceSession.LOCAL_PLAYER_ID))

	await get_tree().create_timer(podium_delay).timeout
	standings_box.hide()
	var podium = PodiumScript.new()
	ui.add_child(podium)
	# Keep the Exit button and balance on top of the results overlay
	ui.move_child(podium, 0)
	podium.race_again_pressed.connect(_on_race_again_pressed)
	podium.show_results(finish_order, result_text)

func _describe_result(result):
	if result == null:
		return "No bet this race"
	var dot_name = Racer.color_name(result.dot)
	if result.payout > 0:
		return "You bet $%d on %s at ×%.2f and won $%d!" % [result.amount, dot_name, result.multiplier, result.payout]
	return "You lost $%d on %s" % [result.amount, dot_name]

# Reload the scene for the next race: new betting round, new grid
func _on_race_again_pressed():
	get_tree().reload_current_scene()

# Finished racers in the order they crossed the line, then everyone else by distance travelled
func get_standings():
	var running = racers.filter(func(racer): return racer not in finish_order)
	running.sort_custom(func(a, b): return a.progress > b.progress)
	return finish_order + running

func _build_standings_text(standings):
	var heading = "Final Lap!" if is_final_lap(standings) and not race_over else "Standings"
	var text = "[center][b]%s[/b][/center]\n[table=4]" % heading
	for i in standings.size():
		var racer = standings[i]
		var status = "Finished" if racer in finish_order else "Lap %d/%d" % [clampi(racer.laps + 1, 1, total_laps), total_laps]
		text += "[cell padding=0,6,12,6]%d.[/cell]" % (i + 1)
		text += "[cell padding=0,6,12,6][img=32x32]%s[/img][/cell]" % racer.get_texture().resource_path
		text += "[cell expand=1 padding=0,6,12,6]%s[/cell]" % racer.get_display_name()
		text += "[cell padding=0,6,0,6]%s[/cell]" % status
	return text + "[/table]"

func _on_exit_button_pressed():
	get_tree().quit()

# The walls are collision shapes only, so draw them. Everything outside the track
# is wall colored; the track surface is a stadium shape matching the outer wall.
func _draw_track():
	RenderingServer.set_default_clear_color(WALL_COLOR)

	var surface = Polygon2D.new()
	surface.polygon = _stadium_points(356.0, 540.0, 32)
	surface.color = TRACK_COLOR
	racetrack.add_child(surface)
	racetrack.move_child(surface, 0)

	for wall in inner_wall.get_children():
		if wall is CollisionPolygon2D:
			var visual = Polygon2D.new()
			visual.polygon = wall.polygon
			visual.color = WALL_COLOR
			wall.add_child(visual)

	var half_size = finish_line_shape.shape.size / 2
	var finish_visual = Polygon2D.new()
	finish_visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	finish_visual.color = FINISH_LINE_COLOR
	finish_line_shape.add_child(finish_visual)

# Outline of a stadium: semicircles of the given radius centered at (±half_straight, 0)
func _stadium_points(half_straight, radius, segments_per_curve):
	var points = PackedVector2Array()
	for i in range(segments_per_curve + 1):
		var angle = -PI / 2 + PI * i / segments_per_curve
		points.append(Vector2(half_straight, 0) + Vector2.from_angle(angle) * radius)
	for i in range(segments_per_curve + 1):
		var angle = PI / 2 + PI * i / segments_per_curve
		points.append(Vector2(-half_straight, 0) + Vector2.from_angle(angle) * radius)
	return points
