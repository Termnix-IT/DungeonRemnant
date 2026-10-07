class_name IconGrid
extends VBoxContainer

# A scrolling grid of icons: one ItemCell per row given to show_rows, an item's
# art alone with its count in the corner. What is said about an icon is the
# page's to say (looked_at); here the icons are chosen, activated (Enter, A or a
# double click), opened for a menu (right click), picked up and dropped. Leaving
# the grid sideways with the arrow keys is the page's too (crossed). A row is
# {index, item, count}; index is whatever the page uses to name it, unique among
# the rows. "tooltip" may replace the item's description, "badge" the count in
# the icon's corner.

signal chosen(place: int)
signal activated(place: int)
signal context_requested(place: int, at: Vector2)
# The pointer or the focus rests on a place, or left it (-1).
signal looked_at(place: int)
signal received(source: ItemCell)
# A sideways arrow press went off the grid: direction -1 or 1, and the row.
signal crossed(direction: int, row: int)
# The icons were laid out again (a move, a filter, an order).
signal refreshed

# What is shown, in order.
var entries: Array[Dictionary] = []
var cells: Array[ItemCell] = []
# The index of the chosen row, or -1.
var selected := -1
var columns := 6
var cell_size := ItemCell.SIZE
# True where reaching an icon with the focus chooses it (a page that previews the choice).
var choose_on_focus := false
var icon_size := ItemCell.ICON
# Called with the dragged ItemCell; says whether this grid takes it.
var can_receive := Callable()
var empty_label: Label
var scroll: ScrollContainer
var grid: GridContainer


func _init() -> void:
	theme_type_variation = &"DetailStack"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.theme_type_variation = &"DetailStack"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	grid = GridContainer.new()
	grid.theme_type_variation = &"GearGrid"
	body.add_child(grid)
	empty_label = HubUI.label(body, "", &"NoteLabel")
	empty_label.hide()
	# Dropping on the space between or below the icons counts as dropping here.
	scroll.set_drag_forwarding(Callable(), _can_drop_here, _drop_here)


# Lays the rows out as icons. The chosen row stays chosen if its item is still
# shown, and the focus stays at its place. empty_text is said when no row is
# shown (nothing when it is empty).
func show_rows(rows: Array[Dictionary], empty_text := "") -> void:
	var kept: ItemData = null
	for entry in entries:
		if entry.index == selected:
			kept = entry.item
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_at := cells.find(focused) if focused is ItemCell else -1
	for cell in cells:
		cell.get_parent().remove_child(cell)
		cell.queue_free()
	cells.clear()
	entries = rows
	selected = -1
	grid.columns = columns
	for place in entries.size():
		var entry := entries[place]
		if entry.item == kept:
			selected = entry.index
		var cell := ItemCell.new()
		cell.custom_minimum_size = Vector2.ONE * cell_size
		cell.icon_size = icon_size
		cell.show_item(entry.item, entry.get("badge", entry.count))
		cell.tooltip_text = entry.get("tooltip", ItemTooltipList.description(entry.item))
		cell.set_pressed_no_signal(entry.index == selected)
		cell.pressed.connect(_pressed.bind(place))
		cell.gui_input.connect(_cell_input.bind(place))
		cell.context_requested.connect(func(at: Vector2): context_requested.emit(place, at))
		cell.mouse_entered.connect(func(): looked_at.emit(place))
		cell.focus_entered.connect(func():
			looked_at.emit(place)
			if choose_on_focus and entries[place].index != selected:
				_pressed(place))
		cell.mouse_exited.connect(func(): looked_at.emit(-1))
		cell.focus_exited.connect(func(): looked_at.emit(-1))
		cell.can_accept = _can_accept
		cell.dropped.connect(func(source: ItemCell): received.emit(source))
		grid.add_child(cell)
		cells.append(cell)
	empty_label.text = empty_text
	empty_label.visible = entries.is_empty() and not empty_text.is_empty()
	if focus_at >= 0 and not cells.is_empty():
		cells[mini(focus_at, cells.size() - 1)].grab_focus()
	refreshed.emit()


# The icon at a place among those shown is the one chosen.
func choose(place: int) -> void:
	selected = entries[place].index if place >= 0 and place < entries.size() else -1
	for at in cells.size():
		cells[at].set_pressed_no_signal(at == place)


func clear_choice() -> void:
	choose(-1)


# The shown place of a row's index, or -1.
func place_of(index: int) -> int:
	return entries.find_custom(func(entry: Dictionary): return entry.index == index)


func _pressed(place: int) -> void:
	choose(place)
	chosen.emit(place)


func _cell_input(event: InputEvent, place: int) -> void:
	var enter: bool = event.is_action_pressed("ui_accept") and not event.is_echo()
	var double: bool = event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT
	if enter or double:
		cells[place].accept_event()
		choose(place)
		activated.emit(place)
		return
	if event.is_action_pressed("ui_left") and place % columns == 0:
		cells[place].accept_event()
		crossed.emit(-1, floori(place / float(columns)))
	elif event.is_action_pressed("ui_right") and (place % columns == columns - 1 or place == cells.size() - 1):
		cells[place].accept_event()
		crossed.emit(1, floori(place / float(columns)))


# A cell of the given row, the first or the last of it, takes the focus.
func focus_row(row: int, from_left: bool) -> bool:
	if cells.is_empty():
		return false
	var first := mini(row, floori((cells.size() - 1) / float(columns))) * columns
	var at := first if from_left else mini(first + columns - 1, cells.size() - 1)
	cells[at].grab_focus()
	return true


func _can_accept(source: ItemCell) -> bool:
	return can_receive.is_valid() and can_receive.call(source)


func _can_drop_here(_at: Vector2, data: Variant) -> bool:
	return data is ItemCell and _can_accept(data)


func _drop_here(_at: Vector2, data: Variant) -> void:
	received.emit(data as ItemCell)
