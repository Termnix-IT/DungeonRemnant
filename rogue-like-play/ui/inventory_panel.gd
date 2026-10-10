extends CanvasLayer

# The dungeon's inventory, in the preparation screen's grammar (HubPrepare):
# over the shaded dungeon, a dark slab on the left holds the five equipment
# slots as lit squares across the top and, under a rule, what she carries as
# a list of two columns; the lighter plate on the right is the decision
# column: the chosen thing's art and name, what wearing it would change, its
# description, and the actions with the primary one at the foot.
#
# Choosing a row shows that item; choosing a slot shows what it holds, with
# taking it off as the primary action. Enter (A) presses the primary action.
# The mouse follows the shared drag grammar (ItemDrag): a row dropped on a
# slot it fits is worn there (a scroll set in a staff), a worn slot dropped on
# the list comes off, and the weapons dropped on each other swap; none of it
# costs a turn. Game logic is reached only through action_requested.

signal action_requested(kind: String, index: int, slot: int)
signal close_requested

const EMPTY_HINT := "持ち物か装備枠を選ぶと、ここに詳しく表示されます。装備中の5枠は所持品の上限に含みません。"
const TURN_NOTE := "ターンが進むのは「使う」だけ"
const COMPARED_STATS := [["hp", "最大HP"], ["attack", "攻撃"], ["defense", "防御"], ["reach", "射程"], ["vision", "視界"]]
const SLOT_CAPTIONS := Equipment.SLOT_NAMES
const SLOT_SIZE := 88.0
const SLOT_ICON := 72.0
const LIST_COLUMNS := 2
const SECONDARY_HEIGHT := 44.0

var player: Node2D
var selected_index := -1
# The equipment slot the column is about, or -1 while a row is chosen.
var selected_slot := -1
# The five slots as squares, indexed by Equipment.Slot.
var slot_cells: Array[ItemCell] = []
# One per slot, shown only for the slots the chosen item fits.
var equip_buttons: Array[Button] = []
var use_button: Button
# Takes off the chosen slot's item.
var remove_button: Button
# The action Enter (A) presses: the one at the foot of the column, or null.
var primary_button: Button
# A staff's slot carries the round socket of its spell; the socket or M (RB)
# opens the MagicPicker of the scrolls carried.
var sockets: Array[MagicSocket] = []
var magic_picker: MagicPicker
var magic_hint: Button
var _picking_slot := -1
# Slot the comparison describes; hovering an equip action previews that slot.
var preview_slot := -1
var title_label: Label
var count_label: Label
var list: ItemCardList
var showcase: ItemShowcase
var details: ItemDetails
var feedback_label: Label
var actions: VBoxContainer
# The footer's key caps double as the switch and close actions (clickable),
# in place of text buttons labelled with their keys.
var key_guide: KeyGuide
var switch_hint: Button
@onready var panel: VBoxContainer = $Panel


func _ready() -> void:
	hide()
	_build_header()
	var body := HBoxContainer.new()
	body.name = "Body"
	body.theme_type_variation = &"ShopColumns"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(body)
	var work := HubUI.open_column(body, 2.1, &"SlabSolid")
	work.theme_type_variation = &"DetailStack"
	_build_slots(work)
	HubUI.rule(work)
	HubUI.label(work, "持ち物", &"SectionLabel")
	list = ItemCardList.new()
	list.name = "List"
	list.max_columns = LIST_COLUMNS
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_child(list)
	list.empty_text = "持ち物はありません"
	list.resized.connect(_fit_columns)
	list.item_selected.connect(_select_item)
	var column := HubUI.open_column(body, 1.0, &"SlabSolidEnd")
	_build_column(column)
	key_guide = KeyGuide.new()
	key_guide.name = "KeyGuide"
	panel.add_child(key_guide)
	key_guide.add_hint("Esc", "B", "閉じる", func(): close_requested.emit())
	key_guide.add_hint("Enter", "A", "決定", activate_selected)
	switch_hint = key_guide.add_hint("Tab", "Y", "武器切替", func(): action_requested.emit("switch", -1, -1))
	magic_hint = key_guide.add_hint("M", "RB", "魔法", func(): open_magic(magic_slot()))
	magic_picker = MagicPicker.new()
	add_child(magic_picker)
	magic_picker.chosen.connect(func(index: int): _apply_magic("socket", index))
	magic_picker.removed.connect(func(): _apply_magic("unsocket", -1))
	magic_picker.canceled.connect(close_magic)
	visibility_changed.connect(func():
		if not visible:
			close_magic())
	list.drag_row = _pick_row
	list.can_take = _list_takes
	list.take = _dropped_on_list
	ItemDrag.glow(list, _list_takes)
	UIMotion.bind_buttons(panel)


# 「所持品」, how many kinds she carries of how many, and on the right which
# action costs a turn.
func _build_header() -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	panel.add_child(header)
	title_label = HubUI.label(header, "所持品", &"TitleLabel")
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_label = HubUI.label(header, "", &"NoteLabel")
	count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var note := HubUI.label(header, TURN_NOTE, &"NoteLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_slots(work: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Slots"
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
		cell.pressed.connect(select_slot.bind(slot))
		# The cell picks itself up (its own _get_drag_data); drops are
		# forwarded here so it also takes the list's rows.
		cell.can_accept = _cell_swaps.bind(slot)
		cell.set_drag_forwarding(Callable(), _can_drop_on_slot.bind(slot), _drop_on_slot.bind(slot))
		ItemDrag.glow(cell, func(data: Variant) -> bool: return data is Dictionary and _slot_takes(data, slot))
		box.add_child(cell)
		var caption := HubUI.label(box, SLOT_CAPTIONS[slot], &"SectionLabel")
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_cells.append(cell)
		if slot <= Equipment.Slot.SUB:
			var socket := MagicSocket.new()
			cell.add_child(socket)
			socket.position = Vector2.ONE * (SLOT_SIZE - MagicSocket.SIZE - 4.0)
			socket.pressed.connect(open_magic.bind(slot))
			sockets.append(socket)


func _build_column(column: VBoxContainer) -> void:
	column.theme_type_variation = &"DetailStack"
	showcase = ItemShowcase.new()
	showcase.name = "Showcase"
	column.add_child(showcase)
	HubUI.rule(column)
	details = ItemDetails.new()
	details.name = "Description"
	column.add_child(details)
	var gap := HubUI.space(column)
	details.fit_lines(gap, 48.0)
	feedback_label = HubUI.label(column, "", &"BodyLabel")
	feedback_label.name = "Feedback"
	actions = VBoxContainer.new()
	actions.name = "Actions"
	actions.theme_type_variation = &"DetailStack"
	column.add_child(actions)
	for slot in SLOT_CAPTIONS.size():
		var equip := _action_button(_equip.bind(slot))
		equip.mouse_entered.connect(_preview.bind(slot))
		equip.mouse_exited.connect(_preview.bind(-1))
		equip_buttons.append(equip)
	use_button = _action_button(func(): action_requested.emit("use", selected_index, -1))
	use_button.name = "Use"
	remove_button = _action_button(func(): _remove(selected_slot))
	remove_button.name = "Remove"


func _action_button(action: Callable) -> Button:
	var button := HubUI.button(actions, "", action)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.hide()
	return button


func present(actor: Node2D) -> void:
	player = actor
	selected_index = -1
	selected_slot = -1
	refresh()
	show()
	UIMotion.of(panel).reveal(UIMotion.WINDOW_TIME)
	# Arrow keys and the D-pad move through the list; the inventory and close
	# keys are handled by Run in _input before the list can see them.
	list.grab_focus()


func refresh(feedback: String = "") -> void:
	count_label.text = "%d / %d 種類" % [player.inventory.entries.size(), player.inventory.max_entries]
	list.clear()
	for entry: InventoryEntry in player.inventory.entries:
		list.add_card(entry.item, entry.count, -1, ItemGlyph.category(entry.item))
	for slot in slot_cells.size():
		var item: ItemData = player.equipment.slots[slot]
		slot_cells[slot].show_item(item)
		slot_cells[slot].tooltip_text = ItemTooltipList.description(item) if item != null else "%s：なし" % SLOT_CAPTIONS[slot]
	switch_hint.disabled = player.equipment.slots[Equipment.Slot.SUB] == null
	for slot in sockets.size():
		sockets[slot].visible = player.equipment.can_socket(slot)
		sockets[slot].scroll = player.equipment.slots[slot].socketed_scroll if sockets[slot].visible else null
	magic_hint.visible = magic_slot() >= 0
	feedback_label.text = feedback
	feedback_label.visible = not feedback.is_empty()
	if selected_index >= player.inventory.entries.size():
		selected_index = -1
	if selected_index >= 0:
		list.select(selected_index)
	_update_actions()


# Two columns that share the list's width, so each row keeps its icon, name,
# main effect and count.
func _fit_columns() -> void:
	var room := list.size.x - list.get_theme_stylebox(&"panel").get_minimum_size().x - list.get_v_scroll_bar().get_combined_minimum_size().x
	var gap := list.get_theme_constant(&"h_separation")
	list.fixed_column_width = maxi(1, floori((room - gap * (LIST_COLUMNS - 1)) / LIST_COLUMNS) - gap)


func _select_item(index: int) -> void:
	var changed := selected_index != index or selected_slot >= 0
	selected_index = index
	selected_slot = -1
	_update_actions()
	if changed:
		UIMotion.reveal_selection([details, showcase])


# A slot chosen (a click, or Enter on it): the column shows what it holds, and
# taking it off is the primary action.
func select_slot(slot: int) -> void:
	if player == null:
		return
	var changed := selected_slot != slot
	selected_slot = slot
	selected_index = -1
	list.deselect_all()
	_update_actions()
	if changed:
		UIMotion.reveal_selection([details, showcase])


func _selected_item() -> ItemData:
	if selected_index >= 0 and selected_index < player.inventory.entries.size():
		return player.inventory.entries[selected_index].item
	return null


# The slots an item could go into: its kind's slots, or a staff's for a scroll.
func _fits(item: ItemData, slot: int) -> bool:
	return player.equipment.accepts(item, slot) or (item.kind == ItemData.Kind.SCROLL and player.equipment.can_socket(slot))


func _update_actions() -> void:
	var item := _selected_item()
	preview_slot = -1
	for slot in slot_cells.size():
		slot_cells[slot].set_pressed_no_signal(slot == selected_slot)
		slot_cells[slot].dimmed = item != null and not _fits(item, slot)
	for slot in equip_buttons.size():
		var socket: bool = item != null and item.kind == ItemData.Kind.SCROLL and player.equipment.can_socket(slot)
		equip_buttons[slot].visible = item != null and _fits(item, slot)
		equip_buttons[slot].text = SLOT_CAPTIONS[slot] + ("に魔法装着" if socket else "に装備")
	_update_use(item)
	var worn: ItemData = player.equipment.slots[selected_slot] if selected_slot >= 0 else null
	remove_button.visible = worn != null
	remove_button.disabled = selected_slot == Equipment.Slot.MAIN
	if worn != null:
		remove_button.text = "主武器は外せない" if remove_button.disabled else "%sを外す" % SLOT_CAPTIONS[selected_slot]
	if selected_slot >= 0:
		_show_slot(selected_slot)
	else:
		showcase.present(item)
		_describe(item)
	_arrange_actions(_primary_for(item, worn))


func _update_use(item: ItemData) -> void:
	use_button.visible = item != null and item.kind == ItemData.Kind.CONSUMABLE
	use_button.disabled = true
	use_button.text = "使用する（1ターン）"
	if not use_button.visible:
		return
	if not item.effect_id.is_empty():
		use_button.disabled = not player.active_effects.can_use(item)
	elif item.restore_mp > 0:
		use_button.disabled = player.mp >= player.stats.max_mp
		if use_button.disabled:
			use_button.text = "MPは満タンです"
	else:
		use_button.disabled = player.hp >= player.stats.max_hp
		if use_button.disabled:
			use_button.text = "HPは満タンです"


# The column's one primary action: taking off the chosen slot, using a
# consumable, or wearing the item in the slot the comparison describes (a
# scroll: the first staff it can be set in).
func _primary_for(item: ItemData, worn: ItemData) -> Button:
	if selected_slot >= 0:
		return remove_button if worn != null else null
	if item == null:
		return null
	if use_button.visible:
		return use_button
	var slot := _default_slot(item)
	if item.kind == ItemData.Kind.SCROLL:
		for staff in equip_buttons.size():
			if player.equipment.can_socket(staff):
				slot = staff
				break
	return equip_buttons[slot] if slot >= 0 else null


# The other actions stand above the primary one, which sits at the foot.
func _arrange_actions(primary: Button) -> void:
	primary_button = primary
	var order: Array[Button] = equip_buttons.duplicate()
	order.append_array([use_button, remove_button])
	for button in order:
		var main := button == primary
		button.theme_type_variation = &"PrimaryAction" if main else &"SecondaryButton"
		button.custom_minimum_size.y = HubUI.PRIMARY_ACTION_HEIGHT if main else SECONDARY_HEIGHT
		actions.move_child(button, -1)
	if primary != null:
		actions.move_child(primary, -1)
	actions.visible = order.any(func(button: Button) -> bool: return button.visible)


# What the chosen slot holds: its art and name, where it is worn, and its
# description; an empty slot names itself.
func _show_slot(slot: int) -> void:
	var worn: ItemData = player.equipment.slots[slot]
	showcase.present(worn)
	details.reset()
	if worn == null:
		showcase.title.text = SLOT_CAPTIONS[slot]
		showcase.category.text = "未装備"
		details.line("所持品をこの枠へドラッグするか、所持品を選んで装備できます。", &"MutedLabel")
		return
	showcase.category.text = "%s　·　%sに装備中" % [ItemGlyph.category(worn), SLOT_CAPTIONS[slot]]
	if player.equipment.can_socket(slot):
		details.line("魔法：%s" % worn.socketed_scroll.weapon.display_name if worn.socketed_scroll != null else "魔法なし", &"BodyLabel")
	details.item_text(worn, showcase)


func _preview(slot: int) -> void:
	if not visible or player == null or slot == preview_slot or selected_slot >= 0:
		return
	preview_slot = slot
	_describe(_selected_item())


func _describe(item: ItemData) -> void:
	details.reset()
	if item == null:
		details.line(EMPTY_HINT, &"MutedLabel")
		return
	var slot := preview_slot if preview_slot >= 0 else _default_slot(item)
	details.item_text(item, showcase)
	if slot >= 0 and item.kind != ItemData.Kind.SCROLL and player.equipment.accepts(item, slot):
		_compare(item, slot)


# An empty compatible slot first; otherwise the first one, so weapons
# compare against Main, which is the slot that decides the attack.
func _default_slot(item: ItemData) -> int:
	var first := -1
	for slot in 5:
		if player.equipment.accepts(item, slot):
			if player.equipment.slots[slot] == null:
				return slot
			if first < 0:
				first = slot
	return first


func _compare(item: ItemData, slot: int) -> void:
	var current: ItemData = player.equipment.slots[slot]
	var gear := Equipment.new()
	gear.slots.assign(player.equipment.slots)
	gear.slots[slot] = item
	var before: Dictionary = player.stats_with(player.equipment)
	var after: Dictionary = player.stats_with(gear)
	details.line("%sに装備した場合（現在：%s）" % [SLOT_CAPTIONS[slot], current.label() if current != null else "なし"], &"MutedLabel")
	var changed := false
	for stat: Array in COMPARED_STATS:
		if before[stat[0]] != after[stat[0]]:
			details.delta(stat[1], before[stat[0]], after[stat[0]])
			changed = true
	if not changed:
		details.line("能力値は変わりません", &"MutedLabel")


# Space, Enter and gamepad A press the column's primary action. On a slot
# that has the focus but is not yet chosen, they choose it first.
func activate_selected() -> bool:
	if not visible or player == null:
		return false
	var owner := get_viewport().gui_get_focus_owner()
	var focused := slot_cells.find(owner) if owner is ItemCell else -1
	if focused >= 0 and focused != selected_slot:
		select_slot(focused)
		return true
	if primary_button == null or not primary_button.visible or primary_button.disabled:
		return false
	primary_button.pressed.emit()
	return true


func switch_weapons() -> bool:
	var switch: Button = switch_hint
	if not visible or switch.disabled:
		return false
	switch.pressed.emit()
	return true


func _equip(slot: int) -> void:
	if selected_index < 0 or selected_index >= player.inventory.entries.size():
		return
	var kind := "socket" if player.inventory.entries[selected_index].item.kind == ItemData.Kind.SCROLL else "equip"
	action_requested.emit(kind, selected_index, slot)


func _remove(slot: int) -> void:
	if slot < 0 or slot == Equipment.Slot.MAIN:
		return
	action_requested.emit("unequip", -1, slot)


func _pick_row(index: int) -> Variant:
	if player == null or index < 0 or index >= player.inventory.entries.size():
		return null
	return {"item": player.inventory.entries[index].item, "inventory_index": index}


# A slot takes a carried row that fits it (a scroll fits a staff), or the
# other weapon's cell to swap with.
func _slot_takes(data: Variant, slot: int) -> bool:
	if player == null:
		return false
	if data is Dictionary and data.has("inventory_index"):
		return _fits(data.item, slot)
	return data is ItemCell and _cell_swaps(data, slot)


func _cell_swaps(source: ItemCell, slot: int) -> bool:
	var from := slot_cells.find(source)
	var weapons := [Equipment.Slot.MAIN, Equipment.Slot.SUB]
	return player != null and from >= 0 and from != slot and from in weapons and slot in weapons and player.equipment.slots[Equipment.Slot.SUB] != null


func _dropped_on_slot(data: Variant, slot: int) -> void:
	if data is Dictionary:
		selected_index = data.inventory_index
		selected_slot = -1
		list.select(selected_index)
		_equip(slot)
	else:
		action_requested.emit("switch", -1, -1)


func _can_drop_on_slot(_at: Vector2, data: Variant, slot: int) -> bool:
	return _slot_takes(data, slot)


func _drop_on_slot(_at: Vector2, data: Variant, slot: int) -> void:
	_dropped_on_slot(data, slot)


# The list takes a worn slot back, except the main weapon.
func _list_takes(data: Variant) -> bool:
	if player == null or not data is ItemCell:
		return false
	var slot := slot_cells.find(data)
	return slot >= 0 and slot != Equipment.Slot.MAIN and player.equipment.slots[slot] != null


func _dropped_on_list(data: Variant) -> void:
	_remove(slot_cells.find(data))


# The staff M opens the picker for: the main weapon if it is a staff, else
# the sub weapon; -1 when neither is.
func magic_slot() -> int:
	if player == null:
		return -1
	for slot in [Equipment.Slot.MAIN, Equipment.Slot.SUB]:
		if player.equipment.can_socket(slot):
			return slot
	return -1


func picking() -> bool:
	return magic_picker.visible


# Each scroll carried is a card; choosing it costs no turn, as before.
func open_magic(slot: int) -> void:
	if not visible or slot < 0 or not player.equipment.can_socket(slot):
		return
	_picking_slot = slot
	var choices: Array[Dictionary] = []
	for index in player.inventory.entries.size():
		var entry: InventoryEntry = player.inventory.entries[index]
		if entry.item.kind == ItemData.Kind.SCROLL:
			choices.append({"key": index, "item": entry.item, "count": entry.count, "place": "所持品"})
	magic_picker.open("%sの杖に魔法を込める" % SLOT_CAPTIONS[slot], player.equipment.slots[slot].socketed_scroll, choices)


func _apply_magic(kind: String, index: int) -> void:
	var slot := _picking_slot
	close_magic()
	action_requested.emit(kind, index, slot)


func close_magic() -> void:
	magic_picker.hide()
	_picking_slot = -1
	if visible:
		list.grab_focus()
