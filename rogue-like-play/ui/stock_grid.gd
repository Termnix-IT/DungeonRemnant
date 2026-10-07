class_name StockGrid
extends VBoxContainer

# One stock shown as an inventory: its name and room, a row that filters its
# icons by kind and sorts them, and under that the icons alone, in a grid, one
# ItemCell each with its count in the corner. What is said about an icon is the
# page's to say (looked_at); here the icons are chosen, activated (Enter, A or a
# double click), opened for a menu (right click), picked up and dropped. Leaving
# the grid sideways with the arrow keys is the page's too (crossed).

signal chosen(entry: int)
signal activated(entry: int)
signal context_requested(entry: int, at: Vector2)
# The pointer or the focus rests on an entry, or left it (-1).
signal looked_at(entry: int)
signal received(source: ItemCell)
# A sideways arrow press went off the grid: direction -1 or 1, and the row.
signal crossed(direction: int, row: int)
# The icons were laid out again (a move, a filter, an order).
signal refreshed

const FILTERS: Array[String] = ["すべて", "武器", "防具", "装飾", "魔法", "道具"]
const SORTS: Array[String] = ["標準", "名前順", "種類順"]
const COLUMNS := 6

var inventory: Inventory
# What is shown: {index (into the inventory), item, count}.
var entries: Array[Dictionary] = []
var cells: Array[ItemCell] = []
# The inventory index of the chosen icon, or -1.
var selected := -1
var filter_index := 0
var sort_index := 0
# Called with the dragged ItemCell; says whether this stock takes it.
var can_receive := Callable()
var name_label: Label
var rule: HintMark
var count_label: Label
var filter_tabs: CategoryTabs
var sort_cycler: OptionCycler
var empty_label: Label
var scroll: ScrollContainer
var grid: GridContainer


func _init(title: String = "", rule_text: String = "") -> void:
	theme_type_variation = &"DetailStack"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"CompactRow"
	add_child(heading)
	name_label = HubUI.label(heading, title, &"ItemNameLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not rule_text.is_empty():
		rule = HintMark.make(heading, rule_text, HubSettings.TOPIC_PREPARATION)
	count_label = HubUI.label(heading, "", &"NoteLabel")
	count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sort_cycler = OptionCycler.new()
	sort_cycler.custom_minimum_size = Vector2(150, 40)
	sort_cycler.tooltip_text = "並べ替え"
	heading.add_child(sort_cycler)
	sort_cycler.setup(SORTS)
	sort_cycler.item_selected.connect(func(index: int):
		sort_index = index
		_changed())
	filter_tabs = CategoryTabs.new()
	add_child(filter_tabs)
	filter_tabs.setup(FILTERS, false)
	filter_tabs.changed.connect(func(index: int):
		filter_index = index
		_changed())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.theme_type_variation = &"DetailStack"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.theme_type_variation = &"GearGrid"
	body.add_child(grid)
	empty_label = HubUI.label(body, "この種類の品はない", &"NoteLabel")
	empty_label.hide()
	# Dropping on the space between or below the icons counts as dropping here.
	scroll.set_drag_forwarding(Callable(), _can_drop_here, _drop_here)


func set_stock(stock: Inventory) -> void:
	inventory = stock
	var kept: ItemData = stock.entries[selected].item if selected >= 0 and selected < stock.entries.size() else null
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_at := cells.find(focused) if focused is ItemCell else -1
	for cell in cells:
		cell.get_parent().remove_child(cell)
		cell.queue_free()
	cells.clear()
	entries.clear()
	for index in stock.entries.size():
		var item := stock.entries[index].item
		if _passes_filter(item):
			entries.append({"index": index, "item": item, "count": stock.entries[index].count})
	_sort()
	selected = -1
	for place in entries.size():
		var entry := entries[place]
		if entry.item == kept:
			selected = entry.index
		var cell := ItemCell.new()
		cell.show_item(entry.item, entry.count)
		cell.tooltip_text = ItemTooltipList.description(entry.item)
		cell.set_pressed_no_signal(entry.index == selected)
		cell.pressed.connect(_pressed.bind(place))
		cell.gui_input.connect(_cell_input.bind(place))
		cell.context_requested.connect(func(at: Vector2): context_requested.emit(place, at))
		cell.mouse_entered.connect(func(): looked_at.emit(place))
		cell.focus_entered.connect(func(): looked_at.emit(place))
		cell.mouse_exited.connect(func(): looked_at.emit(-1))
		cell.focus_exited.connect(func(): looked_at.emit(-1))
		cell.can_accept = _can_accept
		cell.dropped.connect(func(source: ItemCell): received.emit(source))
		grid.add_child(cell)
		cells.append(cell)
	count_label.text = "%d / %d 枠" % [stock.entries.size(), stock.max_entries]
	empty_label.visible = entries.is_empty() and not stock.entries.is_empty()
	if focus_at >= 0 and not cells.is_empty():
		cells[mini(focus_at, cells.size() - 1)].grab_focus()
	refreshed.emit()


func _passes_filter(item: ItemData) -> bool:
	match filter_index:
		1: return item.kind == ItemData.Kind.WEAPON
		2: return item.kind == ItemData.Kind.ARMOR
		3: return item.kind == ItemData.Kind.ACCESSORY
		4: return item.kind == ItemData.Kind.SCROLL
		5: return item.kind == ItemData.Kind.CONSUMABLE
	return true


# 標準 keeps the stock's own order; 名前順 and 種類順 reorder what is shown.
func _sort() -> void:
	if sort_index == 1:
		entries.sort_custom(func(a: Dictionary, b: Dictionary): return a.item.label() < b.item.label())
	elif sort_index == 2:
		entries.sort_custom(func(a: Dictionary, b: Dictionary):
			var kind_a: String = ItemGlyph.category(a.item)
			var kind_b: String = ItemGlyph.category(b.item)
			return a.item.label() < b.item.label() if kind_a == kind_b else kind_a < kind_b)


func _changed() -> void:
	if inventory != null:
		set_stock(inventory)


# The icon at a place among those shown is the one chosen.
func choose(place: int) -> void:
	selected = entries[place].index if place >= 0 and place < entries.size() else -1
	for at in cells.size():
		cells[at].set_pressed_no_signal(at == place)


func clear_choice() -> void:
	choose(-1)


# The shown place of an inventory index, or -1.
func position_of(index: int) -> int:
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
	if event.is_action_pressed("ui_left") and place % COLUMNS == 0:
		cells[place].accept_event()
		crossed.emit(-1, floori(place / float(COLUMNS)))
	elif event.is_action_pressed("ui_right") and (place % COLUMNS == COLUMNS - 1 or place == cells.size() - 1):
		cells[place].accept_event()
		crossed.emit(1, floori(place / float(COLUMNS)))


# A cell of the given row, the first or the last of it, takes the focus.
func focus_row(row: int, from_left: bool) -> bool:
	if cells.is_empty():
		return false
	var first := mini(row, floori((cells.size() - 1) / float(COLUMNS))) * COLUMNS
	var at := first if from_left else mini(first + COLUMNS - 1, cells.size() - 1)
	cells[at].grab_focus()
	return true


func _can_accept(source: ItemCell) -> bool:
	return can_receive.is_valid() and can_receive.call(source)


func _can_drop_here(_at: Vector2, data: Variant) -> bool:
	return data is ItemCell and _can_accept(data)


func _drop_here(_at: Vector2, data: Variant) -> void:
	received.emit(data as ItemCell)
