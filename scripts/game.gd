extends Node

var racer_scene = preload("res://scenes/racer.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_racer()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_racer(color, position):
	var racer = racer_scene.instantiate()
	add_child(racer)
