class_name HubEquipment
extends Control

# The equipment page, as an inventory: the five slots down the left and, beside
# them, the gear the adventurer can wear (carried and stored together) as icons
# alone. The name and main effect of what the pointer or the focus rests on
# stand in one line under them; the full text is the tooltip. Gear goes into a
# slot by dragging its icon there, or by choosing it and then the slot (Enter
# on the icon moves to the slot it would take); either way a prompt names the
# change to her stats before anything is worn. Taking a slot's icon out onto
# the gear takes it off, and dropping the main weapon on the sub weapon (or
# the reverse) swaps them. The page leads nowhere else: the warehouse is its
# own screen from the lobby.

signal equip_requested(from_storage: bool, index: int, slot: int)
signal unequip_requested(slot: int)
signal scroll_remove_requested(slot: int)
signal swap_requested

const SLOT_CAPTIONS := Equipment.SLOT_NAMES
const GRID_COLUMNS := 7

var state: RunCarryover
var selected_slot := 0
# Index into candidates of the chosen gear icon, or -1 while a slot is chosen.
var selected_candidate := -1
# The gear that can be worn, carried first: {from_storage, index, item, count}.
var candidates: Array[Dictionary] = []
var slots: Array[Button] = []
var cells: Array[ItemCell] = []
var grid: GridContainer
var prompt: ChoicePrompt
# The prompt's accept button, which wears what was asked about.
var equip_button: Button
var unequip_button: Button
var swap_button: Button
var scroll_remove_button: Button
var detail_name: Label
var detail_note: Label
# The candidate of the last equip request, for the success moment after saving,
# and where its icon stood (global) for the glyph to fly from.
var equipped_item: ItemData
var _equipped_from := Rect2()
var _pending := {}
var _slab: Control
var _gear_scroll: ScrollContainer
var _gear_heading: Label


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var slab := HubUI.open_column(columns, 1.0, &"SlabColumn")
	_slab = slab.get_parent()
	slab.theme_type_variation = &"DetailStack"
	_build_body(slab)
	# The hall stays open on the right, with its painting of the armoury.
	var hall := Control.new()
	hall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hall.size_flags_stretch_ratio = 0.8
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(hall)
	prompt = ChoicePrompt.new()
	add_child(prompt)
	equip_button = prompt.accept_button
	prompt.confirmed.connect(_confirm)
	prompt.canceled.connect(_cancel)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			prompt.hide())


func _build_body(column: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.theme_type_variation = &"ShopColumns"
	column.add_child(top)
	# The slots: an icon and the slot's name beside it.
	var slot_column := VBoxContainer.new()
	slot_column.theme_type_variation = &"DetailStack"
	top.add_child(slot_column)
	HubUI.label(slot_column, "装備", &"NoteLabel")
	for slot in 5:
		var row := HBoxContainer.new()
		row.theme_type_variation = &"CompactRow"
		slot_column.add_child(row)
		var cell := ItemCell.new()
		cell.symbol = ItemGlyph.slot_symbol(slot)
		cell.pressed.connect(_slot_pressed.bind(slot))
		cell.can_accept = _slot_accepts.bind(slot)
		cell.dropped.connect(_dropped_on_slot.bind(slot))
		cell.mouse_entered.connect(_preview_slot.bind(slot))
		cell.focus_entered.connect(_preview_slot.bind(slot))
		cell.mouse_exited.connect(_restore_detail)
		cell.focus_exited.connect(_restore_detail)
		row.add_child(cell)
		slots.append(cell)
		var caption := HubUI.label(row, SLOT_CAPTIONS[slot], &"NoteLabel")
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		caption.custom_minimum_size.x = 56
	# The gear: every icon that can be worn, a scroll if there are many.
	var gear_column := VBoxContainer.new()
	gear_column.theme_type_variation = &"DetailStack"
	gear_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gear_column)
	_gear_heading = HubUI.label(gear_column, "身につけられる品", &"NoteLabel")
	_gear_scroll = ScrollContainer.new()
	_gear_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gear_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gear_column.add_child(_gear_scroll)
	grid = GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.theme_type_variation = &"GearGrid"
	_gear_scroll.add_child(grid)
	# Taking a worn icon out onto the gear takes it off.
	_gear_scroll.set_drag_forwarding(Callable(), _can_drop_on_gear, _drop_on_gear)
	HubUI.rule(column)
	detail_name = HubUI.label(column, "", &"HeadingLabel")
	detail_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail_note = HubUI.label(column, "", &"NoteLabel")
	detail_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	var lesser := HBoxContainer.new()
	lesser.theme_type_variation = &"TextActions"
	column.add_child(lesser)
	unequip_button = HubUI.button(lesser, "外す", func(): unequip_requested.emit(selected_slot), &"TextAction")
	scroll_remove_button = HubUI.button(lesser, "魔法を外す", func(): scroll_remove_requested.emit(selected_slot), &"TextAction")
	swap_button = HubUI.button(lesser, "主武器と副武器を入れ替え", func(): swap_requested.emit(), &"TextAction")


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
	swap_button.disabled = state.equipment.slots[Equipment.Slot.SUB] == null
	_mark()
	if focus_index >= 0 and not cells.is_empty():
		cells[mini(focus_index, cells.size() - 1)].grab_focus()


func _fill_gear() -> void:
	for cell in cells:
		grid.remove_child(cell)
		cell.queue_free()
	cells.clear()
	candidates.clear()
	for from_storage in [false, true]:
		var source := state.storage if from_storage else state.inventory
		for index in source.entries.size():
			var item := source.entries[index].item
			if _slots_for(item).is_empty():
				continue
			var at := candidates.size()
			candidates.append({"from_storage": from_storage, "index": index, "item": item, "count": source.entries[index].count})
			var cell := ItemCell.new()
			cell.show_item(item, source.entries[index].count)
			cell.tooltip_text = ItemTooltipList.description(item)
			cell.pressed.connect(_candidate_pressed.bind(at))
			cell.gui_input.connect(_candidate_input.bind(at))
			cell.mouse_entered.connect(_preview_candidate.bind(at))
			cell.focus_entered.connect(_preview_candidate.bind(at))
			cell.mouse_exited.connect(_restore_detail)
			cell.focus_exited.connect(_restore_detail)
			grid.add_child(cell)
			cells.append(cell)
	_gear_heading.text = "身につけられる品" if not candidates.is_empty() else "身につけられる品はない"


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
	var current := state.equipment.slots[selected_slot]
	unequip_button.visible = selected_slot != Equipment.Slot.MAIN and selected_candidate < 0
	unequip_button.disabled = current == null
	scroll_remove_button.visible = selected_candidate < 0 and state.equipment.can_socket(selected_slot) and current.socketed_scroll != null
	swap_button.visible = selected_candidate < 0
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


# The prompt: which slot, what it holds now, and how her stats would change.
func ask_equip(index: int, slot: int) -> void:
	var item: ItemData = candidates[index].item
	var current := state.equipment.slots[slot]
	var caption := "%s（今：%s）" % [SLOT_CAPTIONS[slot], current.label() if current != null else "なし"]
	_pending = {"candidate": index, "slot": slot}
	if item.kind == ItemData.Kind.SCROLL:
		prompt.ask(caption, "杖に「%s」を込める" % item.label(), "込めてあった魔法は、元の場所へ戻る。", "杖に魔法を込める", "やめる")
	else:
		prompt.ask(caption, "%sを装備する" % item.label(), _change_text(slot, item), "装備する", "やめる")


func _change_text(slot: int, item: ItemData) -> String:
	var before := state.preparation_stats()
	var preview := Equipment.new()
	preview.slots.assign(state.equipment.slots)
	preview.slots[slot] = item
	var after := state.preparation_stats(preview)
	var lines: Array[String] = []
	for stat: Array in HeroStats.STATS:
		if before[stat[0]] != after[stat[0]]:
			lines.append("%s　%d → %d（%+d）" % [stat[1], before[stat[0]], after[stat[0]], after[stat[0]] - before[stat[0]]])
	return "\n".join(lines) if not lines.is_empty() else "能力は変わらない"


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
		detail_name.text = "未装備"
		detail_note.text = tag
		return
	detail_name.text = item.label()
	var parts: Array[String] = [ItemGlyph.category(item), ItemGlyph.main_effect(item)]
	if not tag.is_empty():
		parts.append(tag)
	detail_note.text = "　".join(parts)


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
