class_name QuantityStepper
extends HBoxContainer

# Replaces SpinBox with large −/+ actions around a typed field. Keeps the
# SpinBox surface the shop relies on: value, min/max, editable, value_changed,
# get_line_edit() and apply().
signal value_changed(value: float)

var minus: Button
var plus: Button
var field: LineEdit
var max_button: Button
var min_value := 1.0:
	set(limit):
		min_value = limit
		value = value
var max_value := 1.0:
	set(limit):
		max_value = maxf(limit, min_value)
		value = value
var editable := true:
	set(allowed):
		editable = allowed
		_sync()
var value := 1.0:
	set(requested):
		var next := clampf(roundf(requested), min_value, max_value)
		var changed := next != value
		# Inside its own setter this writes the stored value directly.
		value = next
		_sync()
		if changed:
			value_changed.emit(next)


func _init() -> void:
	theme_type_variation = &"CompactRow"
	minus = _step_button("−", -1)
	field = LineEdit.new()
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.custom_minimum_size = Vector2(72, 44)
	field.select_all_on_focus = true
	field.text_submitted.connect(func(_text: String): apply())
	field.focus_exited.connect(apply)
	add_child(field)
	plus = _step_button("+", 1)
	_sync()


func _step_button(label: String, direction: int) -> Button:
	var button := Button.new()
	button.text = label
	button.theme_type_variation = &"SecondaryButton"
	button.custom_minimum_size = Vector2(44, 44)
	button.pressed.connect(func(): value = value + direction)
	add_child(button)
	return button


# The settings' selector look, 〈 3 〉: arrows instead of boxed −/+, the
# number shown rather than typed, left / right on an arrow to step, and a
# quiet "最大" to jump to the limit.
func use_selector() -> void:
	minus.text = "〈"
	plus.text = "〉"
	for arrow in [minus, plus]:
		arrow.theme_type_variation = &"SelectorArrow"
		arrow.custom_minimum_size = Vector2(40, 44)
		arrow.gui_input.connect(_step_keys.bind(arrow))
	field.theme_type_variation = &"SelectorValue"
	field.editable = false
	field.focus_mode = Control.FOCUS_NONE
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.custom_minimum_size = Vector2(64, 44)
	max_button = Button.new()
	max_button.text = "最大"
	max_button.theme_type_variation = &"CategoryTab"
	max_button.pressed.connect(func(): value = max_value)
	add_child(max_button)
	_sync()


func _step_keys(event: InputEvent, arrow: Button) -> void:
	if event.is_action_pressed("ui_left", true):
		value = value - 1
		arrow.accept_event()
	elif event.is_action_pressed("ui_right", true):
		value = value + 1
		arrow.accept_event()


func get_line_edit() -> LineEdit:
	return field


# Commits typed text; invalid text falls back to the current value.
func apply() -> void:
	if field.text.strip_edges().is_valid_int():
		value = float(field.text.strip_edges().to_int())
	_sync()


func _sync() -> void:
	if field == null:
		return
	field.text = str(int(value))
	field.editable = editable and max_button == null
	if max_button != null:
		max_button.disabled = not editable or value >= max_value
	minus.disabled = not editable or value <= min_value
	plus.disabled = not editable or value >= max_value
