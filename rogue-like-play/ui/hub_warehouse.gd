class_name HubWarehouse
extends Control

# The warehouse page, as two inventories either side of the hall: what she
# carries on a slab from the left edge, the warehouse on a slab from the right,
# each as icons alone (a StockGrid, which filters and sorts them), and between
# them the open hall with the painting of the storeroom and, at its foot, a
# plaque naming what the pointer or the focus rests on. Goods cross by being
# dragged to the other side, by Enter, A or a double click on the icon, or by
# the right-click menu; the whole stack goes, as much as the other side has
# room for. Leaving is the back key.

signal transfer_requested(from_storage: bool, index: int)

const STORAGE_NOTE := "倉庫の品は冒険へ持っていかず、倒れても失わない。"
const SLAB_WIDTH := 510.0
const IDLE_NAME := "持ち込み　⇄　倉庫"
const IDLE_NOTE := "品をドラッグして、預ける・持ち出す"

var state: RunCarryover
var carried: StockGrid
var storage: StockGrid
var detail_name: Label
var detail_note: Label
# What went wrong with a move; a move that worked says nothing.
var result_label: Label
# The item of the last requested move, for the success moment after saving,
# and where its icon stood (global) for the glyph to fly from.
var moved_item: ItemData
var _moved_from := Rect2()
var menu: ContextMenu
var _slabs: Array[Control] = []


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	carried = StockGrid.new("持ち込み")
	_slab(columns, &"SlabColumn", carried)
	# The hall stays open, with its painting of the storeroom and, at its foot,
	# the plaque of what is looked at.
	var hall := VBoxContainer.new()
	hall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(hall)
	result_label = HubUI.label(hall, "", &"BodyLabel")
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.hide()
	var plaque := HubUI.plaque(hall, 460)
	detail_name = plaque[0]
	detail_note = plaque[1]
	hall.move_child(result_label, hall.get_child_count() - 3)
	storage = StockGrid.new("倉庫", STORAGE_NOTE)
	_slab(columns, &"SlabColumnEnd", storage)
	for pair: Array in [[carried, storage], [storage, carried]]:
		var side: StockGrid = pair[0]
		var other: StockGrid = pair[1]
		side.can_receive = func(source: ItemCell) -> bool: return other.cells.has(source)
		side.chosen.connect(func(_place: int):
			other.clear_choice()
			_restore())
		side.activated.connect(func(place: int): _move(side, place))
		side.context_requested.connect(func(place: int, at: Vector2): _open_menu(side, other, place, at))
		side.looked_at.connect(func(place: int):
			if place >= 0:
				_show_item(side.entries[place].item)
			else:
				_restore())
		# A filter can hide the chosen icon: the plaque follows.
		side.refreshed.connect(_restore)
		side.received.connect(func(source: ItemCell): _received(side, other, source))
		side.crossed.connect(func(direction: int, row: int):
			if (side == carried) == (direction > 0):
				other.focus_row(row, direction > 0))
	menu = ContextMenu.new()
	add_child(menu)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			menu.close())


# A stock on its own slab of the given role, fixed in width so the hall keeps
# the middle.
func _slab(columns: HBoxContainer, role: StringName, stock: StockGrid) -> void:
	var stack := HubUI.open_column(columns, 1.0, role)
	var slab := stack.get_parent() as Control
	slab.size_flags_horizontal = Control.SIZE_FILL
	slab.custom_minimum_size.x = SLAB_WIDTH
	stack.add_child(stock)
	_slabs.append(slab)


func present(current_state: RunCarryover) -> void:
	carried.clear_choice()
	storage.clear_choice()
	refresh(current_state)
	for stock: StockGrid in [carried, storage]:
		if not stock.cells.is_empty():
			stock.cells[0].grab_focus()
			return
	carried.filter_tabs.tabs[carried.filter_tabs.selected].grab_focus()


func refresh(current_state: RunCarryover = state, message: String = "") -> void:
	state = current_state
	carried.set_stock(state.inventory)
	storage.set_stock(state.storage)
	result_label.text = message
	result_label.visible = not message.is_empty()
	_restore()


# The chosen icon of either stock, or null.
func _chosen_item() -> ItemData:
	for stock: StockGrid in [carried, storage]:
		if stock.selected >= 0 and stock.selected < stock.inventory.entries.size():
			return stock.inventory.entries[stock.selected].item
	return null


func _restore() -> void:
	var item := _chosen_item()
	if item == null:
		detail_name.text = IDLE_NAME
		detail_note.text = IDLE_NOTE
	else:
		_show_item(item)


# One line of name, one of kind and main effect; the tooltip has the rest.
func _show_item(item: ItemData) -> void:
	detail_name.text = item.label()
	detail_note.text = HubUI.plaque_note([ItemGlyph.category(item), ItemGlyph.main_effect(item)])


# The whole stack at a place of a stock goes to the other one.
func _move(side: StockGrid, place: int) -> void:
	if place < 0 or place >= side.entries.size():
		return
	var entry := side.entries[place]
	var cell := side.cells[place]
	moved_item = entry.item
	_moved_from = Rect2(cell.get_global_rect().position + (cell.size - Vector2.ONE * ItemCell.ICON) * 0.5, Vector2.ONE * ItemCell.ICON)
	transfer_requested.emit(side == storage, entry.index)


# An icon dropped on one stock that came from the other.
func _received(side: StockGrid, other: StockGrid, source: ItemCell) -> void:
	var place := other.cells.find(source)
	if place >= 0 and side != other:
		_move(other, place)


func _open_menu(side: StockGrid, other: StockGrid, place: int, at: Vector2) -> void:
	side.choose(place)
	other.clear_choice()
	_restore()
	menu.open(at, move_menu(side, place))


# What the right-click offers on an icon: to go to the other side.
func move_menu(side: StockGrid, place: int) -> Array:
	return [["持ち込みへ持ち出す" if side == storage else "倉庫へ預ける", func(): _move(side, place)]]


# Opening the page: the slabs arrive from their edges, the icons a beat later.
func play_entrance() -> void:
	for slab in _slabs:
		UIMotion.of(slab).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(carried.scroll).appear(UIMotion.STAGGER_TIME)
	UIMotion.of(storage.scroll).appear(UIMotion.STAGGER_TIME)


# Success moment after saving: the moved item's icon flies from where it stood
# to its place in the other stock, which then acknowledges the arrival.
func present_move(to_storage: bool) -> void:
	var item := moved_item
	moved_item = null
	var stock := storage if to_storage else carried
	UIMotion.of(result_label).reveal()
	if item == null or not is_visible_in_tree():
		return
	var landing: Control = stock.scroll
	var point := stock.scroll.get_global_rect().get_center()
	for place in stock.entries.size():
		if stock.entries[place].item.id == item.id:
			var cell := stock.cells[place]
			# A cell scrolled out of view lands on the grid's centre instead.
			if stock.scroll.get_global_rect().encloses(cell.get_global_rect()):
				landing = cell
				point = cell.get_global_rect().get_center()
			break
	var origin := Control.new()
	origin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(origin)
	origin.global_position = _moved_from.position
	origin.size = _moved_from.size
	var flight := UIMotion.fly_glyph_at(self, item, origin, point)
	origin.queue_free()
	flight.finished.connect(func():
		if is_instance_valid(landing) and landing.is_visible_in_tree():
			UIMotion.of(landing).pulse())
