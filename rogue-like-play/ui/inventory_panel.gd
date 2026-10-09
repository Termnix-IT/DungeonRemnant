extends CanvasLayer

signal action_requested(kind: String, index: int, slot: int)
signal close_requested

const EMPTY_HINT := "左の所持品を選択してください。装備中の5枠は所持品の上限に含みません。"
const NAME_WIDTH := 150.0
const COMPARED_STATS := [["hp", "最大HP"], ["attack", "攻撃"], ["defense", "防御"], ["reach", "射程"], ["vision", "視界"]]

var player: Node2D
var selected_index := -1
var equip_buttons: Array[Button] = []
var slot_labels: Array[Label] = []
var slot_glyphs: Array[Control] = []
var remove_buttons: Array[Button] = []
# A staff's row carries the round socket of its spell; the socket or M (RB)
# opens the MagicPicker of the scrolls carried.
var sockets: Array[MagicSocket] = []
var magic_picker: MagicPicker
var magic_hint: Button
var _picking_slot := -1
# Slot the comparison describes; hovering an equip action previews that slot.
var preview_slot := -1
@onready var list: ItemCardList = $Panel/List
@onready var showcase: ItemShowcase = $Panel/Showcase
@onready var details: ItemDetails = $Panel/Description
# The footer's key caps double as the switch and close actions (clickable),
# in place of text buttons labelled with their keys.
var key_guide: KeyGuide
var switch_hint: Button


func _ready() -> void:
	hide()
	list.item_selected.connect(_select_item)
	key_guide = KeyGuide.new()
	key_guide.name = "KeyGuide"
	$Panel.add_child(key_guide)
	key_guide.position = Vector2(24, 610)
	key_guide.size = Vector2(600, 34)
	switch_hint = key_guide.add_hint("Tab", "Y", "武器切替", func(): action_requested.emit("switch", -1, -1))
	key_guide.add_hint("Esc", "B", "閉じる", func(): close_requested.emit())
	magic_hint = key_guide.add_hint("M", "RB", "魔法", func(): open_magic(magic_slot()))
	magic_picker = MagicPicker.new()
	add_child(magic_picker)
	magic_picker.chosen.connect(func(index: int): _apply_magic("socket", index))
	magic_picker.removed.connect(func(): _apply_magic("unsocket", -1))
	magic_picker.canceled.connect(close_magic)
	visibility_changed.connect(func():
		if not visible:
			close_magic())
	$Panel/Use.pressed.connect(func(): action_requested.emit("use", selected_index, -1))
	for slot in 5:
		var row := HBoxContainer.new()
		row.theme_type_variation = &"CompactRow"
		row.custom_minimum_size.y = 32
		$Panel/Equipment.add_child(row)
		var glyph := Control.new()
		glyph.custom_minimum_size = Vector2(24, 24)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.draw.connect(_draw_slot.bind(slot, glyph))
		row.add_child(glyph)
		slot_glyphs.append(glyph)
		var caption := HubUI.label(row, HudEquipment.CAPTIONS[slot], &"MutedLabel")
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.custom_minimum_size.x = 64
		var label := HubUI.label(row, "", &"BodyLabel")
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# A trimming label has no width of its own; this keeps the name column.
		label.custom_minimum_size.x = NAME_WIDTH
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		slot_labels.append(label)
		if slot <= Equipment.Slot.SUB:
			var socket := MagicSocket.new()
			socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			socket.pressed.connect(open_magic.bind(slot))
			row.add_child(socket)
			sockets.append(socket)
		# The socket sits right after the staff's name; the actions keep the right edge.
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
		var remove := Button.new()
		remove.text = "外す"
		remove.theme_type_variation = &"SecondaryButton"
		remove.focus_mode = Control.FOCUS_NONE
		remove.custom_minimum_size.x = 64
		remove.pressed.connect(_remove.bind(slot))
		row.add_child(remove)
		remove_buttons.append(remove)
		var equip := Button.new()
		equip.theme_type_variation = &"PrimaryButton"
		equip.focus_mode = Control.FOCUS_NONE
		equip.custom_minimum_size = Vector2(0, 44)
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip.pressed.connect(_equip.bind(slot))
		equip.mouse_entered.connect(_preview.bind(slot))
		equip.mouse_exited.connect(_preview.bind(-1))
		$Panel/Actions.add_child(equip)
		equip_buttons.append(equip)
		# The shared drag grammar (ItemDrag): a carried item dropped on a slot
		# it fits is worn there, a worn one dropped on the list comes off, and
		# the weapons dropped on each other swap; none of it costs a turn.
		ItemDrag.accept_drops(row, _row_takes.bind(slot), _dropped_on_row.bind(slot), _pick_slot.bind(slot))
		ItemDrag.glow(row, _row_takes.bind(slot))
	list.drag_row = _pick_row
	list.can_take = _list_takes
	list.take = _dropped_on_list
	ItemDrag.glow(list, _list_takes)
	UIMotion.bind_buttons($Panel)


func present(actor: Node2D) -> void:
	player = actor
	selected_index = -1
	refresh()
	show()
	UIMotion.of($Panel).reveal(UIMotion.WINDOW_TIME)
	# Arrow keys and the D-pad move through the list; the inventory and close
	# keys are handled by Run in _input before the list can see them.
	list.grab_focus()


func refresh(feedback: String = "") -> void:
	$Panel/Title.text = "所持品  %d / 40種類枠" % player.inventory.entries.size()
	list.clear()
	for entry: InventoryEntry in player.inventory.entries:
		list.add_card(entry.item, entry.count, -1, ItemGlyph.category(entry.item))
	for slot in 5:
		var item: ItemData = player.equipment.slots[slot]
		slot_labels[slot].text = item.label() if item != null else "—"
		slot_labels[slot].tooltip_text = "%s：%s" % [HudEquipment.CAPTIONS[slot], item.label() if item != null else "なし"]
		slot_glyphs[slot].queue_redraw()
		remove_buttons[slot].visible = item != null
		remove_buttons[slot].disabled = slot == Equipment.Slot.MAIN
	switch_hint.disabled = player.equipment.slots[Equipment.Slot.SUB] == null
	for slot in sockets.size():
		sockets[slot].visible = player.equipment.can_socket(slot)
		sockets[slot].scroll = player.equipment.slots[slot].socketed_scroll if sockets[slot].visible else null
	magic_hint.visible = magic_slot() >= 0
	$Panel/Feedback.text = feedback
	if selected_index >= player.inventory.entries.size():
		selected_index = -1
	if selected_index >= 0:
		list.select(selected_index)
	_update_actions()


func _select_item(index: int) -> void:
	var changed := selected_index != index
	selected_index = index
	_update_actions()
	if changed:
		UIMotion.reveal_selection([details, showcase])


func _selected_item() -> ItemData:
	if selected_index >= 0 and selected_index < player.inventory.entries.size():
		return player.inventory.entries[selected_index].item
	return null


func _update_actions() -> void:
	var item := _selected_item()
	showcase.present(item)
	preview_slot = -1
	_describe(item)
	for slot in 5:
		var socket: bool = item != null and item.kind == ItemData.Kind.SCROLL and player.equipment.can_socket(slot)
		equip_buttons[slot].visible = item != null and (socket or player.equipment.accepts(item, slot))
		equip_buttons[slot].text = HudEquipment.CAPTIONS[slot] + ("に魔法装着" if socket else "に装備")
	$Panel/Use.visible = item != null and item.kind == ItemData.Kind.CONSUMABLE
	$Panel/Use.disabled = true
	$Panel/Use.text = "使用する（1ターン）"
	if item != null:
		if not item.effect_id.is_empty():
			$Panel/Use.disabled = not player.active_effects.can_use(item)
		elif item.restore_mp > 0:
			$Panel/Use.disabled = player.mp >= player.stats.max_mp
			if $Panel/Use.disabled:
				$Panel/Use.text = "MPは満タンです"
		else:
			$Panel/Use.disabled = player.hp >= player.stats.max_hp
			if $Panel/Use.disabled:
				$Panel/Use.text = "HPは満タンです"


func _preview(slot: int) -> void:
	if not visible or player == null or slot == preview_slot:
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
	details.line("%sに装備した場合（現在：%s）" % [HudEquipment.CAPTIONS[slot], current.label() if current != null else "なし"], &"MutedLabel")
	var changed := false
	for stat: Array in COMPARED_STATS:
		if before[stat[0]] != after[stat[0]]:
			details.delta(stat[1], before[stat[0]], after[stat[0]])
			changed = true
	if not changed:
		details.line("能力値は変わりません", &"MutedLabel")


func _draw_slot(slot: int, glyph: Control) -> void:
	if player == null:
		return
	var item: ItemData = player.equipment.slots[slot]
	if item != null:
		var role := &"GoldLabel" if slot == Equipment.Slot.MAIN else &"MutedLabel"
		ItemGlyph.paint(glyph, Rect2(Vector2.ZERO, glyph.size), item, glyph.get_theme_color(&"font_color", role))


# Space, Enter and gamepad A: use a consumable, or equip into the slot the
# comparison describes. Other slots stay on their buttons.
func activate_selected() -> bool:
	var use: Button = $Panel/Use
	if not visible:
		return false
	if use.visible:
		if use.disabled:
			return false
		use.pressed.emit()
		return true
	var item := _selected_item()
	if item == null or item.kind == ItemData.Kind.SCROLL:
		return false
	var slot := _default_slot(item)
	if slot < 0 or not equip_buttons[slot].visible:
		return false
	equip_buttons[slot].pressed.emit()
	return true


func switch_weapons() -> bool:
	var switch: Button = switch_hint
	if not visible or switch.disabled:
		return false
	switch.pressed.emit()
	return true


func _equip(slot: int) -> void:
	var kind := "socket" if player.inventory.entries[selected_index].item.kind == ItemData.Kind.SCROLL else "equip"
	action_requested.emit(kind, selected_index, slot)


func _remove(slot: int) -> void:
	action_requested.emit("unequip", -1, slot)


func _pick_row(index: int) -> Variant:
	if player == null or index < 0 or index >= player.inventory.entries.size():
		return null
	return {"item": player.inventory.entries[index].item, "inventory_index": index}


func _pick_slot(target: Control, slot: int) -> Variant:
	var item: ItemData = player.equipment.slots[slot] if player != null else null
	if item == null:
		return null
	if target.get_viewport().gui_is_dragging():
		target.set_drag_preview(ItemDrag.preview(item, 32.0, target.get_theme_color(&"font_color", &"GoldLabel")))
	return {"item": item, "slot": slot}


# A slot takes a carried item that fits it (a scroll fits a staff), or the
# other weapon to swap with.
func _row_takes(data: Variant, slot: int) -> bool:
	if player == null or not data is Dictionary:
		return false
	if data.has("inventory_index"):
		var item: ItemData = data.item
		return player.equipment.accepts(item, slot) or (item.kind == ItemData.Kind.SCROLL and player.equipment.can_socket(slot))
	var weapons := [Equipment.Slot.MAIN, Equipment.Slot.SUB]
	return data.has("slot") and data.slot != slot and data.slot in weapons and slot in weapons and player.equipment.slots[Equipment.Slot.SUB] != null


func _dropped_on_row(data: Variant, slot: int) -> void:
	if data.has("inventory_index"):
		selected_index = data.inventory_index
		list.select(selected_index)
		_equip(slot)
	else:
		action_requested.emit("switch", -1, -1)


# The list takes a worn item back, except the main weapon.
func _list_takes(data: Variant) -> bool:
	return player != null and data is Dictionary and data.has("slot") and data.slot != Equipment.Slot.MAIN


func _dropped_on_list(data: Variant) -> void:
	_remove(data.slot)


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
	magic_picker.open("%sの杖に魔法を込める" % HudEquipment.CAPTIONS[slot], player.equipment.slots[slot].socketed_scroll, choices)


func _apply_magic(kind: String, index: int) -> void:
	var slot := _picking_slot
	close_magic()
	action_requested.emit(kind, index, slot)


func close_magic() -> void:
	magic_picker.hide()
	_picking_slot = -1
	if visible:
		list.grab_focus()
