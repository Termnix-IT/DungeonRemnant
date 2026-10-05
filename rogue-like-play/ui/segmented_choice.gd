class_name SegmentedChoice
extends HBoxContainer

# A short set of options shown side by side as toggle buttons, in place of a
# dropdown that hides two or three choices behind a click. It keeps the
# OptionButton calls the pages use (add_item, select, selected, ids, texts,
# item_selected), so it drops in where a dropdown stood. Arrow keys move
# between the buttons through ordinary focus neighbours.

signal item_selected(index: int)

var selected := -1
# The buttons' look; CategoryTab gives underlined text tabs with no boxes.
var option_role := &"ItemButton"
var _buttons: Array[Button] = []
var _ids: Array[int] = []
var _group := ButtonGroup.new()


func _init() -> void:
	theme_type_variation = &"CompactRow"


func _ready() -> void:
	# Text tabs underline the chosen option, sliding between them.
	if option_role == &"CategoryTab":
		TabUnderline.attach(self)


var item_count: int:
	get:
		return _buttons.size()


func add_item(text: String, id: int = -1) -> void:
	var index := _buttons.size()
	var button := HubUI.button(self, text, _press.bind(index), option_role)
	button.toggle_mode = true
	button.button_group = _group
	button.custom_minimum_size.x = 72
	_buttons.append(button)
	_ids.append(id if id >= 0 else index)
	if selected < 0:
		select(0)


func clear() -> void:
	for button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_ids.clear()
	selected = -1


# Like OptionButton.select(): changes the choice without emitting.
func select(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	selected = index
	# Setting a toggle without its signal does not release the group's other
	# buttons, so every option is set explicitly.
	for other in _buttons.size():
		_buttons[other].set_pressed_no_signal(other == index)


func get_item_text(index: int) -> String:
	return _buttons[index].text if index >= 0 and index < _buttons.size() else ""


func get_item_id(index: int) -> int:
	return _ids[index] if index >= 0 and index < _ids.size() else -1


func get_selected_id() -> int:
	return get_item_id(selected)


func option(index: int) -> Button:
	return _buttons[index]


# Focus lands on the chosen option, the way a dropdown takes focus itself.
func focus_selected() -> void:
	if selected >= 0:
		_buttons[selected].grab_focus()


func _press(index: int) -> void:
	# Pressing the chosen option again keeps it down and changes nothing.
	if index == selected:
		_buttons[index].set_pressed_no_signal(true)
		return
	select(index)
	item_selected.emit(index)
