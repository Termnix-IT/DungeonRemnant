extends CanvasLayer

signal action_requested(kind: String, index: int, slot: int)
signal close_requested

var player: Node2D
var selected_index := -1
var equip_buttons: Array[Button] = []
var slot_labels: Array[Label] = []
var remove_buttons: Array[Button] = []


func _ready() -> void:
	hide()
	$Panel/List.item_selected.connect(_select_item)
	$Panel/Close.pressed.connect(func(): close_requested.emit())
	$Panel/Switch.pressed.connect(func(): action_requested.emit("switch", -1, -1))
	$Panel/Use.pressed.connect(func(): action_requested.emit("use", selected_index, -1))
	for slot in 5:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 34
		$Panel/Equipment.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		slot_labels.append(label)
		var remove := Button.new()
		remove.text = "外す"
		remove.focus_mode = Control.FOCUS_NONE
		remove.pressed.connect(_remove.bind(slot))
		row.add_child(remove)
		remove_buttons.append(remove)
		var equip := Button.new()
		equip.text = Equipment.SLOT_NAMES[slot] + "に装備"
		equip.focus_mode = Control.FOCUS_NONE
		equip.custom_minimum_size = Vector2(175, 42)
		equip.pressed.connect(_equip.bind(slot))
		$Panel/Actions.add_child(equip)
		equip_buttons.append(equip)


func present(actor: Node2D) -> void:
	player = actor
	selected_index = -1
	refresh()
	show()


func refresh(feedback: String = "") -> void:
	$Panel/Title.text = "Inventory  %d / 40種類枠" % player.inventory.entries.size()
	$Panel/List.clear()
	for entry: InventoryEntry in player.inventory.entries:
		$Panel/List.add_item("%s  ×%d" % [entry.item.display_name, entry.count])
	for slot in 5:
		var item: ItemData = player.equipment.slots[slot]
		slot_labels[slot].text = "%s：%s" % [Equipment.SLOT_NAMES[slot], item.display_name if item != null else "なし"]
		remove_buttons[slot].disabled = slot == Equipment.Slot.MAIN or item == null
	$Panel/Switch.disabled = player.equipment.slots[Equipment.Slot.SUB] == null
	$Panel/Feedback.text = feedback
	if selected_index >= player.inventory.entries.size():
		selected_index = -1
	if selected_index >= 0:
		$Panel/List.select(selected_index)
	_update_actions()


func _select_item(index: int) -> void:
	selected_index = index
	_update_actions()


func _update_actions() -> void:
	var item: ItemData = null
	if selected_index >= 0 and selected_index < player.inventory.entries.size():
		item = player.inventory.entries[selected_index].item
	$Panel/Description.text = item.description() if item != null else "左の所持品を選択してください。\n装備中の5枠はInventory上限に含みません。"
	for slot in 5:
		equip_buttons[slot].visible = item != null and player.equipment.accepts(item, slot)
	$Panel/Use.visible = item != null and item.kind == ItemData.Kind.CONSUMABLE
	$Panel/Use.disabled = player.hp >= player.stats.max_hp


func _equip(slot: int) -> void:
	action_requested.emit("equip", selected_index, slot)


func _remove(slot: int) -> void:
	action_requested.emit("unequip", -1, slot)
