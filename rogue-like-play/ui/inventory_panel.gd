extends CanvasLayer

signal action_requested(kind: String, index: int, slot: int)
signal close_requested

const EMPTY_HINT := "左の所持品を選択してください。装備中の5枠は所持品の上限に含みません。"
const COMPARED_STATS := [["hp", "最大HP"], ["attack", "攻撃"], ["defense", "防御"], ["reach", "射程"], ["vision", "視界"]]

var player: Node2D
var selected_index := -1
var equip_buttons: Array[Button] = []
var slot_labels: Array[Label] = []
var slot_glyphs: Array[Control] = []
var remove_buttons: Array[Button] = []
var scroll_remove_buttons: Array[Button] = []
# Slot the comparison describes; hovering an equip action previews that slot.
var preview_slot := -1
@onready var list: ItemCardList = $Panel/List
@onready var showcase: ItemShowcase = $Panel/Showcase
@onready var details: ItemDetails = $Panel/Description


func _ready() -> void:
	hide()
	list.item_selected.connect(_select_item)
	$Panel/Close.pressed.connect(func(): close_requested.emit())
	$Panel/Switch.pressed.connect(func(): action_requested.emit("switch", -1, -1))
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
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		slot_labels.append(label)
		var scroll_remove := Button.new()
		scroll_remove.text = "魔法を外す"
		scroll_remove.theme_type_variation = &"SecondaryButton"
		scroll_remove.focus_mode = Control.FOCUS_NONE
		scroll_remove.pressed.connect(func(): action_requested.emit("unsocket", -1, slot))
		row.add_child(scroll_remove)
		scroll_remove_buttons.append(scroll_remove)
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
	UIMotion.bind_buttons($Panel)


func present(actor: Node2D) -> void:
	player = actor
	selected_index = -1
	refresh()
	show()
	UIMotion.of($Panel).reveal(UIMotion.WINDOW_TIME)


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
		scroll_remove_buttons[slot].visible = item != null and item.socketed_scroll != null
		remove_buttons[slot].visible = item != null
		remove_buttons[slot].disabled = slot == Equipment.Slot.MAIN
	$Panel/Switch.disabled = player.equipment.slots[Equipment.Slot.SUB] == null
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
	if item != null:
		if not item.effect_id.is_empty():
			$Panel/Use.disabled = not player.active_effects.can_use(item)
		elif item.restore_mp > 0:
			$Panel/Use.disabled = player.mp >= player.stats.max_mp
		else:
			$Panel/Use.disabled = player.hp >= player.stats.max_hp


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
	details.item_text(item)
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


func _equip(slot: int) -> void:
	var kind := "socket" if player.inventory.entries[selected_index].item.kind == ItemData.Kind.SCROLL else "equip"
	action_requested.emit(kind, selected_index, slot)


func _remove(slot: int) -> void:
	action_requested.emit("unequip", -1, slot)
