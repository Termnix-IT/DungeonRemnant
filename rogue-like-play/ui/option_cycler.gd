class_name OptionCycler
extends Button

# A game-settings selector, 〈 ウィンドウ 〉: the current option between two
# arrows. Left and right (keys, D-pad) step through the options while it has
# focus; a click on the left arrow steps back and anywhere else steps on, as
# does confirming. The options wrap around.

signal item_selected(index: int)

var options: Array[String] = []
var selected := 0
var _back := false
var _hovered := false


func _init() -> void:
	theme_type_variation = &"OptionCycler"
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	pressed.connect(_on_pressed)


func setup(names: Array[String], index: int = 0) -> void:
	options = names
	select(index)


# Changes the shown option without emitting, like OptionButton.select().
func select(index: int) -> void:
	if options.is_empty():
		return
	selected = posmod(index, options.size())
	text = options[selected]
	queue_redraw()


func step(direction: int) -> void:
	if options.size() < 2:
		return
	select(selected + direction)
	item_selected.emit(selected)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_back = event.position.x < size.x * 0.3
	if event.is_action_pressed("ui_left", true):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		step(1)
		accept_event()


func _on_pressed() -> void:
	step(-1 if _back else 1)
	_back = false


func _draw() -> void:
	var active := has_focus() or _hovered
	var color := get_theme_color(&"arrow_active" if active else &"arrow")
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var baseline := (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var inset := get_theme_constant(&"arrow_inset")
	draw_string(font, Vector2(inset, baseline), "〈", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	var width := font.get_string_size("〉", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(size.x - inset - width, baseline), "〉", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
