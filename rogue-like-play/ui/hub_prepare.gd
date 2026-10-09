class_name HubPrepare
extends Control

# The preparation screen: equipment and the warehouse in one place, so where
# a thing is (worn, carried or stored) and where it goes can be seen at once.
# On one dark slab from the left edge: the five slots as lit squares across
# the top, and under them the warehouse and what she carries as two icon
# grids side by side (StockGrid, each filtered and sorted on its own). The
# right column says what is chosen and what it would change: its name and
# kind, her stats before and after wearing it in the slot it would take (the
# same comparison the dungeon's inventory shows), its description, and the
# actions, the primary one at the foot.
#
# Choosing and acting are separate. Choosing an icon or a slot only fills the
# column; Enter (A) or a double click moves to the primary action, which acts
# on the next press. Dragging an icon onto a slot chooses that slot for it and
# moves to the action the same way; dragging an icon to the other grid moves
# it, and dragging a worn icon onto either grid takes it off. The right-click
# menu acts at once. A staff's slot carries a round socket for its spell; the
# socket, M or Y opens the MagicPicker of the spells at hand.

signal equip_requested(from_storage: bool, index: int, slot: int)
signal unequip_requested(slot: int)
signal scroll_remove_requested(slot: int)
signal swap_requested
signal transfer_requested(from_storage: bool, index: int)

const SLOT_CAPTIONS := Equipment.SLOT_NAMES
const SLOT_SIZE := 88.0
const SLOT_ICON := 72.0
const STORAGE_NOTE := "倉庫の品は冒険へ持っていかず、倒れても失わない。"
const STORAGE_COLUMNS := 6
const CARRIED_COLUMNS := 4
const STOCK_GAP := 36.0

var state: RunCarryover
# What the column is about: a chosen icon, else a chosen slot.
var selected_slot := 0
var storage: StockGrid
var carried: StockGrid
var slots: Array[ItemCell] = []
var sockets: Array[MagicSocket] = []
var detail_icon: ItemCell
var detail_name: Label
var detail_note: Label
var details: ItemDetails
var hero_stats: HeroStats
# What went wrong with the last action; one that worked says nothing.
var result_label: Label
var primary_button: Button
var alternate_button: Button
var move_button: Button
var swap_button: Button
var magic_picker: MagicPicker
# The footer's key cap for the spell picker, set by the hub.
var magic_hint: Button
var menu: ContextMenu
# The slot the chosen icon would go into (the primary action's), or -1.
var target_slot := -1
# The item of the last equip or move, for the success moment after saving,
# and where its icon stood (global) for the glyph to fly from.
var equipped_item: ItemData
var moved_item: ItemData
var _from_rect := Rect2()
var _slab: Control
# The upright rule between the warehouse and the carried grids.
var divider: Control
var _column: VBoxContainer
var _picking_slot := -1
# What the column showed last, so only a new choice fades in.
var _shown: ItemData


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var work := HubUI.open_column(columns, 2.1, &"SlabSolid")
	work.theme_type_variation = &"DetailStack"
	_slab = work.get_parent()
	_build_slots(work)
	HubUI.rule(work)
	var stocks := HBoxContainer.new()
	stocks.theme_type_variation = &"ShopColumns"
	stocks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_child(stocks)
	storage = StockGrid.new("倉庫", STORAGE_NOTE)
	storage.columns = STORAGE_COLUMNS
	storage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage.size_flags_stretch_ratio = 1.45
	stocks.add_child(storage)
	# A gilt hairline parts the two grids, so where the warehouse ends and
	# what she carries begins reads at a glance.
	divider = HubUI.column_rule(stocks, STOCK_GAP)
	carried = StockGrid.new("持ち込み")
	carried.columns = CARRIED_COLUMNS
	carried.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stocks.add_child(carried)
	for pair: Array in [[storage, carried], [carried, storage]]:
		_wire(pair[0], pair[1])
	_column = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	_build_column(_column)
	menu = ContextMenu.new()
	add_child(menu)
	magic_picker = MagicPicker.new()
	add_child(magic_picker)
	magic_picker.chosen.connect(_spell_chosen)
	magic_picker.removed.connect(_spell_removed)
	magic_picker.canceled.connect(_close_picker)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			magic_picker.hide()
			menu.close())


func _build_slots(work: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"ShopColumns"
	work.add_child(row)
	for slot in SLOT_CAPTIONS.size():
		var box := VBoxContainer.new()
		box.theme_type_variation = &"CompactStack"
		row.add_child(box)
		var cell := ItemCell.new()
		cell.theme_type_variation = &"SlotCell"
		cell.custom_minimum_size = Vector2.ONE * SLOT_SIZE
		cell.icon_size = SLOT_ICON
		cell.symbol = ItemGlyph.slot_symbol(slot)
		cell.pressed.connect(_slot_pressed.bind(slot))
		cell.can_accept = _slot_accepts.bind(slot)
		cell.dropped.connect(_dropped_on_slot.bind(slot))
		cell.context_requested.connect(_slot_context.bind(slot))
		cell.gui_input.connect(_slot_input.bind(slot))
		box.add_child(cell)
		var caption := HubUI.label(box, SLOT_CAPTIONS[slot], &"SectionLabel")
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slots.append(cell)
		if slot <= Equipment.Slot.SUB:
			var socket := MagicSocket.new()
			cell.add_child(socket)
			socket.position = Vector2.ONE * (SLOT_SIZE - MagicSocket.SIZE - 4.0)
			socket.pressed.connect(open_magic.bind(slot))
			sockets.append(socket)


func _wire(side: StockGrid, other: StockGrid) -> void:
	# An icon from the other grid moves; a worn icon from a slot comes off.
	side.can_receive = func(source: ItemCell) -> bool:
		return other.cells.has(source) or (slots.has(source) and source.item != null and slots.find(source) != Equipment.Slot.MAIN)
	side.chosen.connect(func(_place: int):
		other.clear_choice()
		_show_chosen())
	side.activated.connect(func(_place: int):
		other.clear_choice()
		_show_chosen()
		_to_action())
	side.context_requested.connect(func(place: int, at: Vector2):
		side.choose(place)
		other.clear_choice()
		_show_chosen()
		menu.open(at, stock_menu(side, place)))
	# A filter can hide the chosen icon: the column follows.
	side.refreshed.connect(_show_chosen)
	side.received.connect(func(source: ItemCell):
		if slots.has(source):
			unequip_requested.emit(slots.find(source))
		else:
			var place := other.cells.find(source)
			if place >= 0:
				_move(other, place))
	side.crossed.connect(func(direction: int, row: int):
		if (side == storage) == (direction > 0):
			other.focus_row(row, direction > 0))


func _build_column(column: VBoxContainer) -> void:
	column.theme_type_variation = &"DetailStack"
	var head := HBoxContainer.new()
	head.theme_type_variation = &"ShopColumns"
	column.add_child(head)
	detail_icon = ItemCell.new()
	detail_icon.custom_minimum_size = Vector2.ONE * SLOT_SIZE
	detail_icon.icon_size = SLOT_ICON
	detail_icon.draggable = false
	detail_icon.toggle_mode = false
	detail_icon.focus_mode = Control.FOCUS_NONE
	detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(detail_icon)
	var named := VBoxContainer.new()
	named.theme_type_variation = &"CompactStack"
	named.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	named.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(named)
	# The name wraps rather than being cut, so the whole of it is always here.
	detail_name = HubUI.label(named, "", &"HeadingLabel")
	detail_note = HubUI.label(named, "", &"NoteLabel")
	HubUI.rule(column)
	# Before and after wearing it, beside the action that does.
	hero_stats = HeroStats.new()
	hero_stats.visible = false
	add_child(hero_stats)
	hero_stats.move_stats_to(column, column.get_child_count())
	details = ItemDetails.new()
	column.add_child(details)
	var gap := HubUI.space(column)
	details.fit_lines(gap, 48.0)
	result_label = HubUI.label(column, "", &"BodyLabel")
	result_label.hide()
	swap_button = HubUI.button(column, "主武器と副武器を入れ替え", func(): swap_requested.emit())
	move_button = HubUI.button(column, "", _move_chosen)
	alternate_button = HubUI.button(column, "", func(): _equip_chosen(_alternate_slot()))
	primary_button = HubUI.primary_action(column, "", _act)


# What the right-click offers on an icon: each slot it could go into, and the
# other side.
func stock_menu(side: StockGrid, place: int) -> Array:
	var entry := side.entries[place]
	var entries := []
	for slot in _slots_for(entry.item):
		var text := "%sの杖に魔法を込める" % SLOT_CAPTIONS[slot] if entry.item.kind == ItemData.Kind.SCROLL else "%sに装備" % SLOT_CAPTIONS[slot]
		entries.append([text, func(): _equip(side, place, slot)])
	entries.append([_move_text(side), func(): _move(side, place)])
	return entries


# On a worn icon: take it off, choose or take out its spell, or swap the weapons.
func slot_menu(slot: int) -> Array:
	var worn := state.equipment.slots[slot]
	var entries := []
	if worn == null:
		return entries
	if slot != Equipment.Slot.MAIN:
		entries.append(["外す", func(): unequip_requested.emit(slot)])
	if state.equipment.can_socket(slot):
		entries.append(["魔法を込める", func(): open_magic(slot)])
	if state.equipment.can_socket(slot) and worn.socketed_scroll != null:
		entries.append(["魔法を外す", func(): scroll_remove_requested.emit(slot)])
	if slot <= Equipment.Slot.SUB and state.equipment.slots[Equipment.Slot.SUB] != null:
		entries.append(["主武器と副武器を入れ替え", func(): swap_requested.emit()])
	return entries


func present(current: RunCarryover) -> void:
	storage.clear_choice()
	carried.clear_choice()
	selected_slot = Equipment.Slot.MAIN
	refresh(current)
	for stock: StockGrid in [storage, carried]:
		if not stock.cells.is_empty():
			stock.cells[0].grab_focus()
			return
	slots[selected_slot].grab_focus()


# The state again after an action; message says what went wrong, if anything.
# The chosen item stays chosen, on whichever side it now is.
func refresh(current: RunCarryover = state, message: String = "") -> void:
	state = current
	var kept := _chosen()
	for index in slots.size():
		var item := state.equipment.slots[index]
		slots[index].show_item(item)
		slots[index].tooltip_text = ItemTooltipList.description(item) if item != null else SLOT_CAPTIONS[index]
	for index in sockets.size():
		sockets[index].visible = state.equipment.can_socket(index)
		sockets[index].scroll = state.equipment.slots[index].socketed_scroll if sockets[index].visible else null
	if is_instance_valid(magic_hint):
		magic_hint.visible = magic_slot() >= 0
	storage.set_stock(state.storage)
	carried.set_stock(state.inventory)
	if not kept.is_empty():
		_rechoose(kept.item, kept.side)
	result_label.text = message
	result_label.visible = not message.is_empty()
	_show_chosen()


# Chooses item again after a refresh: where it was, else on the other side.
func _rechoose(item: ItemData, side: StockGrid) -> void:
	for stock: StockGrid in [side, carried if side == storage else storage]:
		for place in stock.entries.size():
			if stock.entries[place].item == item:
				stock.choose(place)
				(storage if stock == carried else carried).clear_choice()
				return
	storage.clear_choice()
	carried.clear_choice()


# The chosen icon as {side, place, item, from_storage, index}, or empty.
func _chosen() -> Dictionary:
	for stock: StockGrid in [storage, carried]:
		var place := stock.place_of(stock.selected) if stock.selected >= 0 else -1
		if place >= 0:
			var entry := stock.entries[place]
			return {"side": stock, "place": place, "item": entry.item, "from_storage": stock == storage, "index": entry.index}
	return {}


# The slots an item could go into: its kind's slots, or a staff's for a scroll.
func _slots_for(item: ItemData) -> Array[int]:
	var found: Array[int] = []
	for slot in slots.size():
		if state.equipment.accepts(item, slot) or (item.kind == ItemData.Kind.SCROLL and state.equipment.can_socket(slot)):
			found.append(slot)
	return found


# The slot an item would take: the first empty one that fits, else the first
# that fits; -1 when it is not worn at all.
func _default_slot(item: ItemData) -> int:
	var fits := _slots_for(item)
	for slot in fits:
		if state.equipment.slots[slot] == null:
			return slot
	return fits[0] if not fits.is_empty() else -1


func _alternate_slot() -> int:
	var chosen := _chosen()
	if chosen.is_empty():
		return -1
	for slot in _slots_for(chosen.item):
		if slot != target_slot:
			return slot
	return -1


func _move_text(side: StockGrid) -> String:
	return "持ち込みへ移す" if side == storage else "倉庫へ預ける"


# Fills the column for what is chosen, and sets the actions to match.
func _show_chosen() -> void:
	if state == null:
		return
	var chosen := _chosen()
	for index in slots.size():
		slots[index].set_pressed_no_signal(chosen.is_empty() and index == selected_slot)
	if chosen.is_empty():
		_show_slot(selected_slot)
		return
	var item: ItemData = chosen.item
	if target_slot < 0 or target_slot not in _slots_for(item):
		target_slot = _default_slot(item)
	var fits := _slots_for(item)
	for index in slots.size():
		slots[index].dimmed = index not in fits
	_show_item(item, "倉庫" if chosen.from_storage else "持ち込み")
	swap_button.hide()
	move_button.text = _move_text(chosen.side)
	if target_slot >= 0:
		var current := state.equipment.slots[target_slot]
		if item.kind == ItemData.Kind.SCROLL:
			hero_stats.show_stats(state.preparation_stats())
			_set_primary("%sの杖に込める" % SLOT_CAPTIONS[target_slot], true)
		else:
			hero_stats.show_stats(state.preparation_stats(), _stats_with(target_slot, item), HeroStats.swap_text(target_slot, current))
			_set_primary("%sに装備" % SLOT_CAPTIONS[target_slot], true)
		var other := _alternate_slot()
		alternate_button.visible = other >= 0
		alternate_button.text = ("%sの杖に込める" if item.kind == ItemData.Kind.SCROLL else "%sに装備") % SLOT_CAPTIONS[other] if other >= 0 else ""
		move_button.show()
	else:
		# Goods that are not worn have one thing to do: cross to the other side.
		hero_stats.show_stats(state.preparation_stats())
		alternate_button.hide()
		move_button.hide()
		_set_primary(_move_text(chosen.side), true)


# A slot chosen: what it holds, and taking it off.
func _show_slot(slot: int) -> void:
	target_slot = -1
	for index in slots.size():
		slots[index].dimmed = false
	var worn := state.equipment.slots[slot]
	hero_stats.show_stats(state.preparation_stats())
	alternate_button.hide()
	move_button.hide()
	swap_button.visible = slot <= Equipment.Slot.SUB and worn != null and state.equipment.slots[Equipment.Slot.SUB] != null
	if worn == null:
		_shown = null
		detail_icon.symbol = ItemGlyph.slot_symbol(slot)
		detail_icon.show_item(null)
		detail_name.text = SLOT_CAPTIONS[slot]
		detail_note.text = "未装備"
		details.reset()
		_set_primary("外す", false)
		return
	_show_item(worn, "%sに装備中" % SLOT_CAPTIONS[slot])
	if slot == Equipment.Slot.MAIN:
		_set_primary("主武器は外せない", false)
	else:
		_set_primary("%sを外す" % SLOT_CAPTIONS[slot], true)


func _show_item(item: ItemData, place: String) -> void:
	if item != _shown:
		_shown = item
		UIMotion.reveal_selection([detail_name, detail_note])
	detail_icon.symbol = null
	detail_icon.show_item(item)
	detail_name.text = item.label()
	var parts: Array[String] = [ItemGlyph.category(item), place]
	if item.kind == ItemData.Kind.WEAPON and item.weapon.kind == WeaponData.Kind.STAFF:
		parts.insert(1, "魔法：%s" % item.socketed_scroll.weapon.display_name if item.socketed_scroll != null else "魔法なし")
	detail_note.text = "　·　".join(parts)
	details.reset()
	details.line(ItemGlyph.main_effect(item), &"BodyLabel")
	if item.description() != ItemGlyph.main_effect(item):
		details.line(item.description(), &"DescriptionLabel")


func _set_primary(text: String, enabled: bool) -> void:
	primary_button.text = text
	primary_button.disabled = not enabled


# Her stats if item were worn in slot.
func _stats_with(slot: int, item: ItemData) -> Dictionary:
	var preview := Equipment.new()
	preview.slots.assign(state.equipment.slots)
	preview.slots[slot] = item
	return state.preparation_stats(preview)


func _to_action() -> void:
	if primary_button.is_visible_in_tree() and not primary_button.disabled:
		primary_button.grab_focus()


# The primary action: wear the chosen icon, move it, or take off the chosen slot.
func _act() -> void:
	var chosen := _chosen()
	if chosen.is_empty():
		if selected_slot != Equipment.Slot.MAIN and state.equipment.slots[selected_slot] != null:
			unequip_requested.emit(selected_slot)
		return
	if target_slot >= 0:
		_equip_chosen(target_slot)
	else:
		_move_chosen()


func _equip_chosen(slot: int) -> void:
	var chosen := _chosen()
	if not chosen.is_empty() and slot >= 0:
		_equip(chosen.side, chosen.place, slot)


func _equip(side: StockGrid, place: int, slot: int) -> void:
	var entry := side.entries[place]
	equipped_item = entry.item if entry.item.kind != ItemData.Kind.SCROLL else null
	_from_rect = _icon_rect(side.cells[place])
	selected_slot = slot
	equip_requested.emit(side == storage, entry.index, slot)


func _move_chosen() -> void:
	var chosen := _chosen()
	if not chosen.is_empty():
		_move(chosen.side, chosen.place)


# The whole stack at a place goes to the other side.
func _move(side: StockGrid, place: int) -> void:
	if place < 0 or place >= side.entries.size():
		return
	var entry := side.entries[place]
	moved_item = entry.item
	_from_rect = _icon_rect(side.cells[place])
	transfer_requested.emit(side == storage, entry.index)


func _icon_rect(cell: ItemCell) -> Rect2:
	return Rect2(cell.get_global_rect().position + (cell.size - Vector2.ONE * ItemCell.ICON) * 0.5, Vector2.ONE * ItemCell.ICON)


func _slot_pressed(slot: int) -> void:
	var chosen := _chosen()
	# With an icon chosen, a slot it fits is where it would go.
	if not chosen.is_empty() and slot in _slots_for(chosen.item):
		target_slot = slot
		_show_chosen()
		return
	select_slot(slot)


func select_slot(slot: int) -> void:
	selected_slot = slot
	storage.clear_choice()
	carried.clear_choice()
	_show_chosen()


func _slot_input(event: InputEvent, slot: int) -> void:
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		slots[slot].accept_event()
		_slot_pressed(slot)
		_to_action()


func _slot_context(at: Vector2, slot: int) -> void:
	select_slot(slot)
	menu.open(at, slot_menu(slot))


func _slot_accepts(source: ItemCell, slot: int) -> bool:
	for stock: StockGrid in [storage, carried]:
		var place := stock.cells.find(source)
		if place >= 0:
			return slot in _slots_for(stock.entries[place].item)
	var from_slot := slots.find(source)
	var weapons := [Equipment.Slot.MAIN, Equipment.Slot.SUB]
	return from_slot >= 0 and from_slot != slot and from_slot in weapons and slot in weapons and state.equipment.slots[Equipment.Slot.SUB] != null


# An icon dropped on a slot: that slot is where it would go, and the action
# waits; weapons dropped on each other swap.
func _dropped_on_slot(source: ItemCell, slot: int) -> void:
	for stock: StockGrid in [storage, carried]:
		var place := stock.cells.find(source)
		if place >= 0:
			stock.choose(place)
			(carried if stock == storage else storage).clear_choice()
			target_slot = slot
			_show_chosen()
			_to_action()
			return
	if slots.has(source):
		swap_requested.emit()


# Opening the screen: the slots arrive left first, the grids a beat later.
func play_entrance() -> void:
	UIMotion.of(_slab).appear(0.0, UIMotion.WINDOW_TIME)
	for index in slots.size():
		UIMotion.of(slots[index]).appear(UIMotion.ROW_STAGGER * index, UIMotion.ROW_TIME)
	UIMotion.of(storage.scroll).appear(UIMotion.STAGGER_TIME)
	UIMotion.of(carried.scroll).appear(UIMotion.STAGGER_TIME)
	UIMotion.of(_column).appear(UIMotion.STAGGER_TIME)


# Success moment after saving: the worn item's icon flies into its slot, which
# then acknowledges it. Swaps and removals have no single item to carry and
# only pulse their slots.
func present_equip(changed: Array[int]) -> void:
	var item := equipped_item
	equipped_item = null
	if item != null and changed.size() == 1 and is_visible_in_tree():
		var slot := slots[changed[0]]
		var flight := UIMotion.fly_glyph(self, item, _origin(), slot)
		flight.finished.connect(func():
			if is_instance_valid(slot) and slot.is_visible_in_tree():
				UIMotion.of(slot).pulse())
	else:
		for index in changed:
			UIMotion.of(slots[index]).pulse()


# Success moment after saving: the moved item's icon flies from where it stood
# to its place on the other side, which then acknowledges the arrival.
func present_move(to_storage: bool) -> void:
	var item := moved_item
	moved_item = null
	UIMotion.of(result_label).reveal()
	if item == null or not is_visible_in_tree():
		return
	var stock := storage if to_storage else carried
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
	var flight := UIMotion.fly_glyph_at(self, item, _origin(), point)
	flight.finished.connect(func():
		if is_instance_valid(landing) and landing.is_visible_in_tree():
			UIMotion.of(landing).pulse())


# A stand-in at where the icon stood, for the flight to start from.
func _origin() -> Control:
	var origin := Control.new()
	origin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(origin)
	origin.global_position = _from_rect.position
	origin.size = _from_rect.size
	origin.queue_free.call_deferred()
	return origin


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or magic_picker.visible:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var pad: bool = event is InputEventJoypadButton and event.pressed
	if (key and event.keycode == KEY_M) or (pad and event.button_index == JOY_BUTTON_Y):
		get_viewport().set_input_as_handled()
		open_magic(magic_slot())


# The staff a key opens the picker for: the chosen slot if it holds a staff,
# else the first weapon slot that does; -1 when neither does.
func magic_slot() -> int:
	if state == null:
		return -1
	if state.equipment.can_socket(selected_slot):
		return selected_slot
	for slot in [Equipment.Slot.MAIN, Equipment.Slot.SUB]:
		if state.equipment.can_socket(slot):
			return slot
	return -1


# Every scroll carried or stored is a card; the carried come first.
func open_magic(slot: int) -> void:
	if state == null or slot < 0 or not state.equipment.can_socket(slot):
		return
	menu.close()
	_picking_slot = slot
	select_slot(slot)
	var choices: Array[Dictionary] = []
	for from_storage in [false, true]:
		var source := state.storage if from_storage else state.inventory
		for index in source.entries.size():
			var entry := source.entries[index]
			if entry.item.kind == ItemData.Kind.SCROLL:
				choices.append({"key": {"from_storage": from_storage, "index": index}, "item": entry.item, "count": entry.count, "place": "倉庫" if from_storage else "持ち込み"})
	magic_picker.open("%sの杖に魔法を込める" % SLOT_CAPTIONS[slot], state.equipment.slots[slot].socketed_scroll, choices)


# Picking a card is the decision; the slot pulses once it is saved.
func _spell_chosen(key: Dictionary) -> void:
	var slot := _picking_slot
	_close_picker()
	equipped_item = null
	equip_requested.emit(key.from_storage, key.index, slot)


func _spell_removed() -> void:
	var slot := _picking_slot
	_close_picker()
	scroll_remove_requested.emit(slot)


func _close_picker() -> void:
	magic_picker.hide()
	if _picking_slot >= 0 and is_visible_in_tree():
		slots[_picking_slot].grab_focus()
	_picking_slot = -1
