# Post-race results: an Olympic-style podium with the racers in their finishing places.
# Built entirely in code; call show_results() after adding it to a CanvasLayer.
extends Control

signal race_again_pressed

const OVERLAY_COLOR = Color(0, 0, 0, 0.8)
const PLACE_COLORS = [Color(0.85, 0.68, 0.2), Color(0.72, 0.72, 0.76), Color(0.72, 0.45, 0.22)]
const BLOCK_HEIGHTS = [280.0, 200.0, 140.0]
const BLOCK_WIDTH = 240.0
const DOT_SIZE = 96.0
const FLOOR_Y = 860.0
# Horizontal offset from screen center for each place: 2nd on the left, 1st in the middle, 3rd on the right
const PLACE_OFFSETS = [0.0, -260.0, 260.0]

func show_results(finish_order, result_text = ""):
	var screen_size = get_viewport_rect().size
	var center_x = screen_size.x / 2
	size = screen_size
	mouse_filter = MOUSE_FILTER_IGNORE
	modulate.a = 0.0

	var overlay = ColorRect.new()
	overlay.color = OVERLAY_COLOR
	overlay.size = screen_size
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)

	var title = _make_label("Results", 80)
	title.position = Vector2(0, 140)
	title.size = Vector2(screen_size.x, 100)
	add_child(title)

	var result = _make_label(result_text, 36)
	result.position = Vector2(0, 250)
	result.size = Vector2(screen_size.x, 60)
	add_child(result)

	var dots = []
	for place in range(mini(finish_order.size(), 3)):
		var racer = finish_order[place]
		var height = BLOCK_HEIGHTS[place]
		var block_x = center_x + PLACE_OFFSETS[place] - BLOCK_WIDTH / 2

		var block = ColorRect.new()
		block.color = PLACE_COLORS[place]
		block.position = Vector2(block_x, FLOOR_Y - height)
		block.size = Vector2(BLOCK_WIDTH, height)
		block.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(block)

		var number = _make_label(str(place + 1), 72)
		number.position = Vector2(0, 20)
		number.size = Vector2(BLOCK_WIDTH, 80)
		block.add_child(number)

		var name_label = _make_label(racer.get_display_name(), 32)
		name_label.position = Vector2(0, 100)
		name_label.size = Vector2(BLOCK_WIDTH, 40)
		block.add_child(name_label)

		var dot = TextureRect.new()
		dot.texture = racer.get_texture()
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.position = Vector2(center_x + PLACE_OFFSETS[place] - DOT_SIZE / 2, FLOOR_Y - height - DOT_SIZE - 10)
		dot.pivot_offset = dot.size / 2
		dot.scale = Vector2.ZERO
		dot.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(dot)
		dots.append(dot)

	var race_again = Button.new()
	race_again.text = "Next Race"
	race_again.add_theme_font_size_override("font_size", 36)
	race_again.size = Vector2(300, 70)
	race_again.position = Vector2(center_x - 150, FLOOR_Y + 60)
	race_again.modulate.a = 0.0
	race_again.disabled = true
	race_again.pressed.connect(func(): race_again_pressed.emit())
	add_child(race_again)

	# Fade in, pop the dots onto the podium from 3rd place up to 1st, then reveal the button
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	for place in range(dots.size() - 1, -1, -1):
		tween.tween_interval(0.3)
		tween.tween_property(dots[place], "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.4)
	tween.tween_property(race_again, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func(): race_again.disabled = false)

func _make_label(text, font_size):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
