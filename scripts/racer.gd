extends RigidBody2D
class_name Racer

enum DotColor {RED, GREEN, BLUE}

signal lap_completed(racer)

@onready var hitbox = %Hitbox
@onready var sprite = %Sprite

@export var push_interval_min = 0.4
@export var push_interval_max = 1.2
@export var push_strength_min = 80.0
@export var push_strength_max = 220.0
# How strongly periodic pushes steer back toward the middle of the track (0 = pure tangent)
@export var centering_strength = 0.6
# Extra push away from the outer wall whenever a racer hits it
@export var wall_kick_strength = 120.0

# Track geometry: two stadium shapes whose curves are centered at (±track_half_straight, 0)
@export var track_half_straight = 356.0
@export var inner_radius = 256.0
@export var outer_radius = 540.0

var racer_color
var racing = false
var _time_to_push = 0.0
# Scales push strength; set by the game each frame for rubber banding
var push_multiplier = 1.0
# Scales push strength from the dot's performance rating; set once when the race is set up
var performance_multiplier = 1.0

# Laps completed, and total distance travelled along the track (laps * lap length + distance into this lap)
var laps = 0
var progress = 0.0
var _last_s = 0.0

func _ready() -> void:
	match racer_color:
		DotColor.RED:
			sprite.texture = load("res://assets/red_dot.png")
		DotColor.BLUE:
			sprite.texture = load("res://assets/blue_dot.png")
		DotColor.GREEN:
			sprite.texture = load("res://assets/green_dot.png")

	lock_rotation = true
	linear_damp = 0.6

	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.5
	physics_material.friction = 0.1
	physics_material_override = physics_material

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func start_racing():
	racing = true
	# Short random first delay so the racers don't all push in sync
	_time_to_push = randf_range(0.0, push_interval_min)

	_last_s = get_track_distance()
	# Starting a hair to the right of the line reads as nearly a full lap; don't count that as progress
	laps = -1 if _last_s > get_lap_length() / 2 else 0
	progress = laps * get_lap_length() + _last_s

func _physics_process(delta: float) -> void:
	if not racing:
		return

	_time_to_push -= delta
	if _time_to_push <= 0.0:
		apply_central_impulse(get_push_direction() * randf_range(push_strength_min, push_strength_max) * push_multiplier * performance_multiplier)
		_time_to_push = randf_range(push_interval_min, push_interval_max)

	_update_progress()

# A big jump in track distance between frames means the racer crossed the finish line:
# downward is forward (end of lap -> start of lap), upward is being knocked back over it.
func _update_progress():
	var lap_length = get_lap_length()
	var s = get_track_distance()
	if s - _last_s < -lap_length / 2:
		laps += 1
		lap_completed.emit(self)
	elif s - _last_s > lap_length / 2:
		laps -= 1
	_last_s = s
	progress = laps * lap_length + s

func _on_body_entered(body):
	if body.is_in_group("outer_wall"):
		apply_central_impulse(-get_outward() * wall_kick_strength)

# Vector from the nearest point on the track's center spine to the racer.
# Both walls are stadium shapes sharing that spine, so this points straight at the outer wall.
func get_offset_from_spine() -> Vector2:
	var pos = global_position
	var center = Vector2(clampf(pos.x, -track_half_straight, track_half_straight), 0.0)
	return pos - center

func get_outward() -> Vector2:
	var r = get_offset_from_spine()
	if r.length_squared() < 0.001:
		return Vector2.UP
	return r.normalized()

# Direction parallel to the walls, pointing counterclockwise on screen.
func get_track_tangent() -> Vector2:
	var outward = get_outward()
	return Vector2(outward.y, -outward.x)

# Tangent, tilted back toward the middle of the track the further the racer has drifted from it.
func get_push_direction() -> Vector2:
	var half_width = (outer_radius - inner_radius) / 2
	# -1 at the inner wall, 0 in the middle, +1 at the outer wall
	var drift = clampf((get_offset_from_spine().length() - get_middle_radius()) / half_width, -1.0, 1.0)
	return (get_track_tangent() - get_outward() * drift * centering_strength).normalized()

func get_middle_radius() -> float:
	return (inner_radius + outer_radius) / 2

# Length of one lap measured along the middle of the track
func get_lap_length() -> float:
	return 4 * track_half_straight + TAU * get_middle_radius()

# How far along the current lap the racer is, measured along the middle of the track.
# 0 at the finish line (x = 0 on the top straight), increasing counterclockwise up to get_lap_length().
func get_track_distance() -> float:
	var h = track_half_straight
	var r = get_middle_radius()
	var pos = global_position
	if pos.x < -h:
		# Left curve: angle swept from its top point
		var angle = (pos - Vector2(-h, 0)).angle()
		return h + wrapf(-PI / 2 - angle, 0.0, TAU) * r
	if pos.x > h:
		# Right curve: angle swept from its bottom point
		var angle = (pos - Vector2(h, 0)).angle()
		return 3 * h + PI * r + wrapf(PI / 2 - angle, 0.0, TAU) * r
	if pos.y > 0:
		# Bottom straight, heading right
		return h + PI * r + (pos.x + h)
	if pos.x <= 0:
		# Top straight, left half: just past the finish line
		return -pos.x
	# Top straight, right half: approaching the finish line
	return 3 * h + TAU * r + (h - pos.x)

func get_display_name() -> String:
	return color_name(racer_color)

static func color_name(color) -> String:
	return DotColor.keys()[color].capitalize()

func get_texture() -> Texture2D:
	return sprite.texture
