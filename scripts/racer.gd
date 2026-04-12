extends RigidBody2D
class_name Racer

enum DotColor {RED, GREEN, BLUE}

@onready var hitbox = %Hitbox
@onready var sprite = %Sprite

var racer_color
var move_speed = 1

func _ready() -> void:
	match racer_color:
		DotColor.RED:
			sprite.texture = load("res://assets/red_dot.png")
		DotColor.BLUE:
			sprite.texture = load("res://assets/blue_dot.png")
		DotColor.GREEN:
			sprite.texture = load("res://assets/green_dot.png")
