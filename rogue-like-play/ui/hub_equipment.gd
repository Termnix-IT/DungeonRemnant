class_name HubEquipment
extends Control

# The equipment page, as an inventory: on one slab from the left edge, the gear
# the adventurer can wear (what she carries and what is stored, each in its own
# block) as icons alone, and right beside it the five slots as large lit
# squares, so gear is only a short way from where it goes. The hall stays open
# for the painting of the armoury, with a plaque under the knight's plinth
# naming what the pointer or the focus rests on (a line of name, a line of
# kind and main effect; the full text is the tooltip). Gear goes into a slot by
# dragging its icon there, by choosing it and then the slot (Enter on the icon
# moves to the slot it would take), or by the right-click menu on the icon;
# right-clicking a worn icon offers taking it off (or swapping the weapons,
# or taking a spell out). The icons can be filtered by kind and sorted. Either way a prompt shows
# the change to her stats before anything is worn. Taking a slot's icon out
# onto the gear takes it off too, and dropping the main weapon on the sub
# weapon (or the reverse) swaps them. The page leads nowhere else: the
# warehouse is its own screen from the lobby.

signal equip_requested(from_storage: bool, index: int, slot: int)
signal unequip_requested(slot: int)
signal scroll_remove_requested(slot: int)
signal swap_requested

const SLOT_CAPTIONS := Equipment.SLOT_NAMES
const GRID_COLUMNS := 7
# The slots' icons are shown at the art's own size.
const SLOT_SIZE := 104.0
const SLOT_ICON := 96.0
const SLAB_WIDTH := 830.0
const FILTERS: Array[String] = ["すべて", "武器", "防具", "装飾", "魔法"]
const SORTS: Array[String] = ["標準", "名前順", "種類順"]

var state: RunCarryover
var selected_slot := 0
# Index into candidates of the chosen gear icon, or -1 while a slot is chosen.
var selected_candidate := -1
# What the icons show: the kind (an index of FILTERS) and the order (of SORTS).
var filter_index := 0
var sort_index := 0
# The gear that can be worn, carried first: {from_storage, index, item, count}.
var candidates: Array[Dictionary] = []
var slots: Array[Button] = []
var cells: Array[ItemCell] = []
var grid: GridContainer
var storage_grid: GridContainer
var prompt: EquipPrompt
# The prompt's accept button, which wears what was asked about.
var equip_button: Button
var filter_tabs: CategoryTabs
var sort_cycler: OptionCycler
var detail_name: Label
var detail_note: Label
# The candidate of the last equip request, for the success moment after saving,
# and where its icon stood (global) for the glyph to fly from.
var equipped_item: ItemData
var _equipped_from := Rect2()
var _pending := {}
var _slab: Control
var _menu: ContextMenu
var _gear_scroll: ScrollContainer
var _carried_heading: Label
var _storage_heading: Label


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var slab := HubUI.open_column(columns, 1.0, &"SlabColumn")
	_slab = slab.get_parent()
	_slab.size_flags_horizontal = Control.SIZE_FILL
	_slab.custom_minimum_size.x = SLAB_WIDTH
	var both := HBoxContainer.new()
	both.theme_type_variation = &"ShopColumns"
	both.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slab.add_child(both)
	_build_gear(both)
	var slot_column := VBoxContainer.new()
	slot_column.theme_type_variation = &"DetailStack"
	both.add_child(slot_column)
	_build_slots(slot_column)
	# The hall stays open, with its painting of the armoury and, under the
	# plinth, the plaque of what is looked at.
	var hall := VBoxContainer.new()
	hall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(hall)
	_build_plaque(hall)
	_menu = ContextMenu.new()
	add_child(_menu)
	prompt = EquipPrompt.new()
	add_child(prompt)
	equip_button = prompt.accept_button
	prompt.confirmed.connect(_confirm)
	prompt.canceled.connect(_cancel)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			prompt.hide()
			_close_menu())


# What she carries, then what is stored: icons in a grid each, one scroll,
# under a row that filters them by kind and sorts them.
func _build_gear(parent: Control) -> void:
	var gear := VBoxContainer.new()
	gear.theme_type_variation = &"DetailStack"
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(gear)
	var controls := HBoxContainer.new()
	controls.theme_type_variation = &"ShopColumns"
	gear.add_child(controls)
	filter_tabs = CategoryTabs.new()
	filter_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(filter_tabs)
	filter_tabs.setup(FILTERS, false)
	filter_tabs.changed.connect(func(index: int):
		filter_index = index
		_regear())
	sort_cycler = OptionCycler.new()
	sort_cycler.custom_minimum_size = Vector2(190, 44)
	sort_cycler.tooltip_text = "並べ替え"
	controls.add_child(sort_cycler)
	sort_cycler.setup(SORTS)
	sort_cycler.item_selected.connect(func(index: int):
		sort_index = index
		_regear())
	_gear_scroll = ScrollContainer.new()
	_gear_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gear_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gear.add_child(_gear_scroll)
	var blocks := VBoxContainer.new()
	blocks.theme_type_variation = &"DetailStack"
	blocks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_scroll.add_child(blocks)
	_carried_heading = HubUI.label(blocks, "", &"SectionLabel")
	grid = _new_grid(blocks)
	_storage_heading = HubUI.label(blocks, "", &"SectionLabel")
	storage_grid = _new_grid(blocks)
	# Taking a worn icon out onto the gear takes it off.
	_gear_scroll.set_drag_forwarding(Callable(), _can_drop_on_gear, _drop_on_gear)


func _new_grid(parent: Control) -> GridContainer:
	var new_grid := GridContainer.new()
	new_grid.columns = GRID_COLUMNS
	new_grid.theme_type_variation = &"GearGrid"
	parent.add_child(new_grid)
	return new_grid


func _build_slots(column: VBoxContainer) -> void:
	var heading := HubUI.label(column, "装備", &"SectionLabel")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for slot in 5:
		var row := HBoxContainer.new()
		row.theme_type_variation = &"CompactRow"
		row.alignment = BoxContainer.ALIGNMENT_END
		column.add_child(row)
		var caption := HubUI.label(row, SLOT_CAPTIONS[slot], &"SectionLabel")
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var cell := ItemCell.new()
		cell.theme_type_variation = &"SlotCell"
		cell.custom_minimum_size = Vector2.ONE * SLOT_SIZE
		cell.icon_size = SLOT_ICON
		cell.symbol = ItemGlyph.slot_symbol(slot)
		cell.pressed.connect(_slot_pressed.bind(slot))
		cell.can_accept = _slot_accepts.bind(slot)
		cell.dropped.connect(_dropped_on_slot.bind(slot))
		cell.context_requested.connect(_slot_context.bind(slot))
		cell.mouse_entered.connect(_preview_slot.bind(slot))
		cell.focus_entered.connect(_preview_slot.bind(slot))
		cell.mouse_exited.connect(_restore_detail)
		cell.focus_exited.connect(_restore_detail)
		row.add_child(cell)
		slots.append(cell)


# The plaque under the knight's plinth, on the same slab as the rest: the
# name, and the kind and effect.
func _build_plaque(hall: VBoxContainer) -> void:
	var plaque := HubUI.plaque(hall, 560)
	detail_name = plaque[0]
	detail_note = plaque[1]


func show_menu(at: Vector2, entries: Array) -> void:
	_menu.open(at, entries)


func _close_menu() -> void:
	_menu.close()


func menu_open() -> bool:
	return _menu.is_open()


# What the right-click offers on gear: each slot it could go into.
func gear_menu(index: int) -> Array:
	var item: ItemData = candidates[index].item
	var entries := []
	for slot in _slots_for(item):
		var text := "%sの杖に魔法を込める" % SLOT_CAPTIONS[slot] if item.kind == ItemData.Kind.SCROLL else "%sに装備" % SLOT_CAPTIONS[slot]
		entries.append([text, func(): ask_equip(index, slot)])
	return entries


# On a worn icon: take it off, take its spell out, or swap the two weapons.
func slot_menu(slot: int) -> Array:
	var worn := state.equipment.slots[slot]
	var entries := []
	if worn == null:
		return entries
	if slot != Equipment.Slot.MAIN:
		entries.append(["外す", func(): unequip_requested.emit(slot)])
	if state.equipment.can_socket(slot) and worn.socketed_scroll != null:
		entries.append(["魔法を外す", func(): scroll_remove_requested.emit(slot)])
	if slot <= Equipment.Slot.SUB and state.equipment.slots[Equipment.Slot.SUB] != null:
		entries.append(["主武器と副武器を入れ替え", func(): swap_requested.emit()])
	return entries


func _gear_context(at: Vector2, index: int) -> void:
	selected_candidate = index
	_mark()
	show_menu(at, gear_menu(index))


func _slot_context(at: Vector2, slot: int) -> void:
	selected_slot = slot
	selected_candidate = -1
	_mark()
	show_menu(at, slot_menu(slot))


func refresh(current: RunCarryover) -> void:
	state = current
	var kept: ItemData = candidates[selected_candidate].item if selected_candidate >= 0 and selected_candidate < candidates.size() else null
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_index := cells.find(focused) if focused is ItemCell else -1
	for index in slots.size():
		var item := state.equipment.slots[index]
		(slots[index] as ItemCell).show_item(item)
		slots[index].tooltip_text = ItemTooltipList.description(item) if item != null else SLOT_CAPTIONS[index]
	_fill_gear()
	selected_candidate = -1
	for index in candidates.size():
		if candidates[index].item == kept:
			selected_candidate = index
			break
	_mark()
	if focus_index >= 0 and not cells.is_empty():
		cells[mini(focus_index, cells.size() - 1)].grab_focus()


func _fill_gear() -> void:
	for cell in cells:
		cell.get_parent().remove_child(cell)
		cell.queue_free()
	cells.clear()
	candidates.clear()
	for from_storage in [false, true]:
		var source := state.storage if from_storage else state.inventory
		var wearable := 0
		var block := []
		for index in source.entries.size():
			var item := source.entries[index].item
			if _slots_for(item).is_empty():
				continue
			wearable += 1
			if _passes_filter(item):
				block.append({"from_storage": from_storage, "index": index, "item": item, "count": source.entries[index].count})
		_sort(block)
		for candidate: Dictionary in block:
			var at := candidates.size()
			candidates.append(candidate)
			var cell := ItemCell.new()
			cell.show_item(candidate.item, candidate.count)
			cell.tooltip_text = ItemTooltipList.description(candidate.item)
			cell.pressed.connect(_candidate_pressed.bind(at))
			cell.gui_input.connect(_candidate_input.bind(at))
			cell.context_requested.connect(_gear_context.bind(at))
			# A worn icon dropped on the gear takes it off, whichever icon it lands on.
			cell.can_accept = func(source: ItemCell) -> bool: return _can_drop_on_gear(Vector2.ZERO, source)
			cell.dropped.connect(func(source: ItemCell): _drop_on_gear(Vector2.ZERO, source))
			cell.mouse_entered.connect(_preview_candidate.bind(at))
			cell.focus_entered.connect(_preview_candidate.bind(at))
			cell.mouse_exited.connect(_restore_detail)
			cell.focus_exited.connect(_restore_detail)
			(storage_grid if from_storage else grid).add_child(cell)
			cells.append(cell)
		var heading := "%s　%d / %d 枠" % ["倉庫" if from_storage else "持ち込み", source.entries.size(), source.max_entries]
		# An empty block has nothing to explain; a full one with nothing to wear
		# or nothing of the chosen kind says so.
		if not source.entries.is_empty() and block.is_empty():
			heading += "　身につけられる品はない" if wearable == 0 else "　この種類の品はない"
		(_storage_heading if from_storage else _carried_heading).text = heading


func _passes_filter(item: ItemData) -> bool:
	match filter_index:
		1: return item.kind == ItemData.Kind.WEAPON
		2: return item.kind == ItemData.Kind.ARMOR
		3: return item.kind == ItemData.Kind.ACCESSORY
		4: return item.kind == ItemData.Kind.SCROLL
	return true


# 標準 keeps the bag's own order; 名前順 and 種類順 reorder within each block.
func _sort(block: Array) -> void:
	if sort_index == 1:
		block.sort_custom(func(a: Dictionary, b: Dictionary): return a.item.label() < b.item.label())
	elif sort_index == 2:
		block.sort_custom(func(a: Dictionary, b: Dictionary):
			var kind_a: String = ItemGlyph.category(a.item)
			var kind_b: String = ItemGlyph.category(b.item)
			return a.item.label() < b.item.label() if kind_a == kind_b else kind_a < kind_b)


# The filter or the order changed: the icons again, the chosen one kept.
func _regear() -> void:
	if state != null:
		refresh(state)


# The slots an item could go into: its kind's slots, or a staff's for a scroll.
func _slots_for(item: ItemData) -> Array[int]:
	var found: Array[int] = []
	for slot in slots.size():
		if state.equipment.accepts(item, slot) or (item.kind == ItemData.Kind.SCROLL and state.equipment.can_socket(slot)):
			found.append(slot)
	return found


# What is chosen shows its frame; slots that the chosen gear does not fit dim;
# the lesser actions follow the chosen slot.
func _mark() -> void:
	var item: ItemData = candidates[selected_candidate].item if selected_candidate >= 0 else null
	var fits: Array[int] = []
	if item != null:
		fits = _slots_for(item)
	for index in slots.size():
		(slots[index] as ItemCell).dimmed = item != null and index not in fits
		slots[index].set_pressed_no_signal(item == null and index == selected_slot)
	for index in cells.size():
		cells[index].set_pressed_no_signal(index == selected_candidate)
	_restore_detail()


func select_slot(slot: int) -> void:
	selected_slot = slot
	selected_candidate = -1
	_mark()
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused is ItemCell and (slots.has(focused) or cells.has(focused)):
		slots[slot].grab_focus()


func step_slot(direction: int) -> void:
	select_slot(posmod(selected_slot + direction, slots.size()))


# The slot a gear icon would take: the first empty one that fits, else the
# first that fits.
func _default_slot(index: int) -> int:
	var fits := _slots_for(candidates[index].item)
	for slot in fits:
		if state.equipment.slots[slot] == null:
			return slot
	return fits[0]


# Choosing a gear icon holds it for a slot; Enter or A moves on to the slot it
# would take, without wearing anything; a double click asks about it at once.
func _candidate_pressed(index: int) -> void:
	selected_candidate = index
	_mark()


func _candidate_input(event: InputEvent, index: int) -> void:
	var enter: bool = event.is_action_pressed("ui_accept") and not event.is_echo()
	var double: bool = event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT
	if not enter and not double:
		return
	cells[index].accept_event()
	selected_candidate = index
	selected_slot = _default_slot(index)
	_mark()
	if enter:
		slots[selected_slot].grab_focus()
	else:
		ask_equip(index, selected_slot)


func _slot_pressed(slot: int) -> void:
	selected_slot = slot
	if selected_candidate >= 0 and slot in _slots_for(candidates[selected_candidate].item):
		ask_equip(selected_candidate, slot)
		return
	selected_candidate = -1
	_mark()


func _slot_accepts(source: ItemCell, slot: int) -> bool:
	var from_gear := cells.find(source)
	if from_gear >= 0:
		return slot in _slots_for(candidates[from_gear].item)
	var from_slot := slots.find(source)
	var weapons := [Equipment.Slot.MAIN, Equipment.Slot.SUB]
	return from_slot >= 0 and from_slot != slot and from_slot in weapons and slot in weapons and state.equipment.slots[Equipment.Slot.SUB] != null


func _dropped_on_slot(source: ItemCell, slot: int) -> void:
	var from_gear := cells.find(source)
	if from_gear >= 0:
		selected_candidate = from_gear
		selected_slot = slot
		_mark()
		ask_equip(from_gear, slot)
	elif slots.has(source):
		swap_requested.emit()


func _can_drop_on_gear(_at: Vector2, data: Variant) -> bool:
	return data is ItemCell and slots.has(data) and (data as ItemCell).item != null and slots.find(data) != Equipment.Slot.MAIN


func _drop_on_gear(_at: Vector2, data: Variant) -> void:
	unequip_requested.emit(slots.find(data))


# The prompt: which slot, what it holds now, and how her stats would move.
func ask_equip(index: int, slot: int) -> void:
	var item: ItemData = candidates[index].item
	var current := state.equipment.slots[slot]
	var caption := "%s（今：%s）" % [SLOT_CAPTIONS[slot], current.label() if current != null else "なし"]
	_pending = {"candidate": index, "slot": slot}
	if item.kind == ItemData.Kind.SCROLL:
		prompt.ask(caption, current, ItemGlyph.slot_symbol(slot), item, [], "込めてあった魔法は、元の場所へ戻る。", "杖に「%s」を込める" % item.label(), "杖に魔法を込める", "やめる")
		return
	var changes := _changes(slot, item)
	prompt.ask(caption, current, ItemGlyph.slot_symbol(slot), item, changes, "" if not changes.is_empty() else "能力は変わらない", "%sを装備する" % item.label(), "装備する", "やめる")


# [name, before, after] for each of her stats that wearing item would move.
func _changes(slot: int, item: ItemData) -> Array:
	var before := state.preparation_stats()
	var preview := Equipment.new()
	preview.slots.assign(state.equipment.slots)
	preview.slots[slot] = item
	var after := state.preparation_stats(preview)
	var rows := []
	for stat: Array in HeroStats.STATS:
		if before[stat[0]] != after[stat[0]]:
			rows.append([stat[1], before[stat[0]], after[stat[0]]])
	return rows


func _confirm() -> void:
	prompt.hide()
	if _pending.is_empty():
		return
	var candidate: Dictionary = candidates[_pending.candidate]
	var slot: int = _pending.slot
	var cell: ItemCell = cells[_pending.candidate]
	_pending = {}
	equipped_item = candidate.item
	_equipped_from = Rect2(cell.get_global_rect().position + (cell.size - Vector2.ONE * ItemCell.ICON) * 0.5, Vector2.ONE * ItemCell.ICON)
	selected_slot = slot
	equip_requested.emit(candidate.from_storage, candidate.index, slot)


func _cancel() -> void:
	prompt.hide()
	if not _pending.is_empty() and _pending.candidate < cells.size():
		cells[_pending.candidate].grab_focus()
	_pending = {}


func _preview_slot(slot: int) -> void:
	var item := state.equipment.slots[slot] if state != null else null
	_show_detail(item, SLOT_CAPTIONS[slot] if item == null else "")


func _preview_candidate(index: int) -> void:
	var candidate: Dictionary = candidates[index]
	_show_detail(candidate.item, "倉庫" if candidate.from_storage else "持ち込み")


# What the pointer or the focus left: the chosen gear, else the chosen slot.
func _restore_detail() -> void:
	if state == null:
		return
	if selected_candidate >= 0 and selected_candidate < candidates.size():
		_preview_candidate(selected_candidate)
	else:
		_preview_slot(selected_slot)


# One line of name, one of kind and main effect; the tooltip has the rest.
func _show_detail(item: ItemData, tag: String) -> void:
	if item == null:
		detail_name.text = tag if not tag.is_empty() else "未装備"
		detail_note.text = "未装備"
		return
	detail_name.text = item.label()
	var parts: Array[String] = [ItemGlyph.category(item), ItemGlyph.main_effect(item)]
	if not tag.is_empty():
		parts.append(tag)
	detail_note.text = HubUI.plaque_note(parts)


# Opening the page: the slots arrive top first, the gear a beat later.
func play_entrance() -> void:
	for index in slots.size():
		UIMotion.of(slots[index]).appear(UIMotion.ROW_STAGGER * index, UIMotion.ROW_TIME)
	UIMotion.of(_slab).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(_gear_scroll).appear(UIMotion.STAGGER_TIME)


# Success moment after saving: the gear's icon flies into its slot, which
# then acknowledges it. Swaps and removals have no single item to carry and
# only pulse their slots.
func present_equip(changed: Array[int]) -> void:
	if equipped_item != null and changed.size() == 1 and is_visible_in_tree():
		var slot := slots[changed[0]]
		var origin := Control.new()
		origin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(origin)
		origin.global_position = _equipped_from.position
		origin.size = _equipped_from.size
		var flight := UIMotion.fly_glyph(self, equipped_item, origin, slot)
		origin.queue_free()
		flight.finished.connect(func():
			if is_instance_valid(slot) and slot.is_visible_in_tree():
				UIMotion.of(slot).pulse())
	else:
		for index in changed:
			UIMotion.of(slots[index]).pulse()
	equipped_item = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var pad: bool = event is InputEventJoypadButton and event.pressed
	var back: bool = (key and event.keycode == KEY_Q) or (pad and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var next: bool = (key and event.keycode == KEY_E) or (pad and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	if back or next:
		step_slot(-1 if back else 1)
		get_viewport().set_input_as_handled()
