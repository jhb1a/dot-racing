# Betting round UI: a card per dot (rating, recent form, live payout) plus bet controls.
# Built in code. It only reads from and asks RaceSession - it never changes money itself.
extends VBoxContainer

signal start_now_pressed

const DEFAULT_BET = 100
const PICKED_BORDER = Color(0.95, 0.78, 0.25)
const CARD_BACKGROUND = Color(1, 1, 1, 0.06)
const ORDINALS = ["1st", "2nd", "3rd"]

var player_id = RaceSession.LOCAL_PLAYER_ID
# dot -> {"style", "pays", "pick"}
var _cards = {}
var _step_buttons = []
var _bet_label
var _countdown_label

func setup(racers):
	add_theme_constant_override("separation", 14)

	var cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 20)
	add_child(cards_row)
	for racer in racers:
		cards_row.add_child(_make_card(racer))

	var bet_row = HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.add_theme_constant_override("separation", 8)
	add_child(bet_row)
	_add_step_button(bet_row, "-$50", func(): _change_amount(-50))
	_add_step_button(bet_row, "-$10", func(): _change_amount(-10))
	_bet_label = _make_label("", 24)
	_bet_label.custom_minimum_size = Vector2(400, 0)
	bet_row.add_child(_bet_label)
	_add_step_button(bet_row, "+$10", func(): _change_amount(10))
	_add_step_button(bet_row, "+$50", func(): _change_amount(50))
	_add_step_button(bet_row, "All in", _all_in)

	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 20)
	add_child(footer)
	_countdown_label = _make_label("", 24)
	footer.add_child(_countdown_label)
	var start_now = _make_button("Start now", 24)
	start_now.pressed.connect(func(): start_now_pressed.emit())
	footer.add_child(start_now)

	RaceSession.bets_changed.connect(_refresh)
	_refresh()

func set_countdown(seconds):
	_countdown_label.text = "Race starts in %ds" % seconds

func _make_card(racer):
	var dot = racer.racer_color
	var rating = RaceSession.get_performance_rating(dot)

	var style = StyleBoxFlat.new()
	style.bg_color = CARD_BACKGROUND
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.border_color = Color.TRANSPARENT
	style.set_content_margin_all(12)
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 0)
	card.add_theme_stylebox_override("panel", style)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 10)
	var image = TextureRect.new()
	image.texture = racer.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(40, 40)
	header.add_child(image)
	header.add_child(_make_label(racer.get_display_name(), 30))
	box.add_child(header)

	box.add_child(_make_label("Rating %d" % roundi(rating), 22))
	var bar = ProgressBar.new()
	bar.max_value = 100
	bar.value = rating
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(bar)
	box.add_child(_make_label(_form_text(dot), 20))

	var pays = _make_label("", 26)
	box.add_child(pays)
	var pick = _make_button("Pick", 22)
	pick.pressed.connect(_on_pick.bind(dot))
	box.add_child(pick)

	_cards[dot] = {"style": style, "pays": pays, "pick": pick}
	return card

func _form_text(dot):
	var places = RaceSession.get_recent_places(dot)
	if places.is_empty():
		return "Form: no races yet"
	return "Form: " + " ".join(PackedStringArray(places.map(func(place): return ORDINALS[place - 1])))

# Picking a dot moves the whole bet to it (or starts a default bet)
func _on_pick(dot):
	var bet = RaceSession.get_bet(player_id)
	var amount = bet.amount if bet else DEFAULT_BET
	RaceSession.place_bet(player_id, dot, amount)

func _change_amount(delta):
	var bet = RaceSession.get_bet(player_id)
	if bet:
		RaceSession.place_bet(player_id, bet.dot, bet.amount + delta)

func _all_in():
	var bet = RaceSession.get_bet(player_id)
	if bet:
		RaceSession.place_bet(player_id, bet.dot, RaceSession.get_balance(player_id))

func _refresh():
	var bet = RaceSession.get_bet(player_id)
	for dot in _cards:
		var card = _cards[dot]
		var picked = bet != null and bet.dot == dot
		card.pays.text = "Pays ×%.2f" % RaceSession.get_payout_multiplier(dot)
		card.style.border_color = PICKED_BORDER if picked else Color.TRANSPARENT
		card.pick.text = "Picked" if picked else "Pick"
	for button in _step_buttons:
		button.disabled = bet == null
	if bet == null:
		_bet_label.text = "Pick a dot to place a bet"
	else:
		var winnings = roundi(bet.amount * RaceSession.get_payout_multiplier(bet.dot))
		_bet_label.text = "$%d on %s  (wins $%d)" % [bet.amount, Racer.color_name(bet.dot), winnings]

func _add_step_button(row, text, action):
	var button = _make_button(text, 22)
	button.pressed.connect(action)
	row.add_child(button)
	_step_buttons.append(button)

func _make_button(text, font_size):
	var button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	return button

func _make_label(text, font_size):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
