extends CanvasLayer

signal start_requested
signal purchase_requested

var gold_label: Label
var equipment_label: Label
var upgrade_label: Label
var feedback: Label
var purchase_button: Button
var start_button: Button
var save_label: Label


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("0d141c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_label("拠点", Vector2(64, 42), Vector2(800, 50), 36)
	_label("装備を引き継ぎ、次の冒険へ。", Vector2(64, 100), Vector2(800, 30), 18)
	gold_label = _label("", Vector2(64, 154), Vector2(850, 40), 26)
	gold_label.modulate = Color("62d6cf")
	_label("持ち込み装備", Vector2(64, 224), Vector2(400, 35), 24)
	equipment_label = _label("", Vector2(64, 275), Vector2(420, 250), 20)
	_label("永久強化", Vector2(530, 224), Vector2(400, 35), 24)
	upgrade_label = _label("", Vector2(530, 275), Vector2(400, 140), 20)
	purchase_button = _button("", Vector2(530, 430), Vector2(400, 48))
	purchase_button.pressed.connect(func(): purchase_requested.emit())
	feedback = _label("", Vector2(530, 490), Vector2(400, 55), 18)
	start_button = _button("冒険開始 — 1F / Lv1", Vector2(64, 572), Vector2(866, 54))
	start_button.pressed.connect(func(): start_requested.emit())
	save_label = _label("", Vector2(64, 640), Vector2(866, 65), 16)


func _label(text: String, position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


func _button(text: String, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	add_child(button)
	return button


func refresh(state: RunCarryover, message: String = "") -> void:
	gold_label.text = "所持Gold  %d" % state.gold
	var lines: PackedStringArray = []
	for index in state.equipment.slots.size():
		var item := state.equipment.slots[index]
		lines.append("%s：%s" % [Equipment.SLOT_NAMES[index], item.display_name if item != null else "なし"])
	lines.append("\nInventory：%d / 40枠" % state.inventory.entries.size())
	equipment_label.text = "\n".join(lines)
	var definition := state.upgrade
	upgrade_label.text = "%s　%d / %d\n最大HP ＋%d\n1段階ごとに最大HP ＋%d" % [definition.display_name, state.hp_upgrade_level, definition.costs.size(), definition.hp_bonus(state.hp_upgrade_level), definition.hp_per_level]
	var cost := definition.price(state.hp_upgrade_level)
	purchase_button.text = "強化上限に到達" if cost < 0 else "購入：%d Gold" % cost
	purchase_button.disabled = cost < 0 or state.gold < cost
	feedback.text = message if not message.is_empty() else ("Goldが不足しています。" if cost >= 0 and state.gold < cost else "")
