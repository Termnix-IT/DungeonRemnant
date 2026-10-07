class_name ContextMenu
extends Control

# The right-click menu: a small list of actions at the pointer, over a layer
# that covers the page so a click anywhere else, or Esc, closes it. Appearance
# belongs to the shared Theme (ContextMenu, MenuItem).

var items: VBoxContainer
var _panel: PanelContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ContextMenu"
	add_child(_panel)
	items = VBoxContainer.new()
	_panel.add_child(items)
	hide()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# entries: [[text, Callable]]. Nothing to offer, nothing opens.
func open(at: Vector2, entries: Array) -> void:
	if entries.is_empty():
		return
	for item in items.get_children():
		items.remove_child(item)
		item.queue_free()
	for entry: Array in entries:
		var button := HubUI.button(items, entry[0], func():
			close()
			entry[1].call(), &"MenuItem")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(220, 0)
	show()
	_panel.reset_size()
	var room := get_global_rect()
	var corner := at - room.position
	_panel.position = Vector2(clampf(corner.x, 0.0, maxf(0.0, room.size.x - _panel.size.x)), clampf(corner.y, 0.0, maxf(0.0, room.size.y - _panel.size.y)))
	(items.get_child(0) as Button).grab_focus()


func close() -> void:
	if visible:
		hide()


func is_open() -> bool:
	return visible


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
