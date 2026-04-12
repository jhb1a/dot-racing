extends Node

var racer_scene = preload("res://scenes/racer.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_racer(Racer.DotColor.RED, Vector2(100, 300))
	spawn_racer(Racer.DotColor.GREEN, Vector2(200, 300))
	spawn_racer(Racer.DotColor.BLUE, Vector2(300, 300))

func spawn_racer(color, position):
	var racer = racer_scene.instantiate()
	racer.racer_color = color
	racer.position = position
	add_child(racer)
