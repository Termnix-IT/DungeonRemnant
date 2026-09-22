extends CanvasLayer

const MAX_LOG_ENTRIES := 3
const EMPTY_EQUIPMENT := "—"

@onready var status: Label = $Status
@onready var floor_value: Label = $TopLeft/Floor
@onready var gold_value: Label = $TopLeft/Gold
@onready var area: Label = $TopRight/Area
@onready var minimap: DungeonMinimap = $TopRight/Minimap
@onready var hp_value: Label = $BottomLeft/HpValue
@onready var hp_bar: ProgressBar = $BottomLeft/HpBar
@onready var mp_value: Label = $BottomLeft/MpValue
@onready var mp_bar: ProgressBar = $BottomLeft/MpBar
@onready var level_value: Label = $BottomLeft/Level
@onready var exp_value: Label = $BottomLeft/ExpValue
@onready var exp_bar: ProgressBar = $BottomLeft/ExpBar
@onready var meta: Label = $BottomLeft/Meta
@onready var log_entries: Label = $Log/Entries
@onready var equipment_rows: Array[Label] = [
	$BottomRight/Rows/Main,
	$BottomRight/Rows/Sub,
	$BottomRight/Rows/Armor,
	$BottomRight/Rows/Accessory1,
	$BottomRight/Rows/Accessory2,
]

var log_history: Array[String] = []
var last_log_text := ""
var turn_count := 0
var inventory_count := 0


func refresh(hp: int, max_hp: int, turns: int, visible_enemies: int, log_text: String, floor_number: int, layout_name: String, terrain_name: String = "", total_floors: int = 10) -> void:
	status.text = "%d / %dF  %s     HP %d / %d     TURN %d     視界内の敵 %d" % [floor_number, total_floors, layout_name, hp, max_hp, turns, visible_enemies]
	floor_value.text = "%d / %d" % [floor_number, total_floors]
	area.text = "%s・%s" % [_terrain_label(terrain_name), _layout_label(layout_name)]
	hp_value.text = "%d / %d" % [hp, max_hp]
	hp_bar.max_value = max(max_hp, 1)
	hp_bar.value = max(hp, 0)
	UIMotion.of($BottomLeft/HpTrail).update_vital(hp, max_hp, hp_value)
	turn_count = turns
	_refresh_meta()
	var message := "死亡しました。リザルト画面を確認してください。" if hp <= 0 else log_text
	_record_log(message)


func show_aim(weapon_name: String, aiming: bool) -> void:
	if aiming:
		_render_log("攻撃方向を選択中：方向キーで変更 / Spaceで確定 / Escでキャンセル")
	$BottomRight/Title.text = "EQUIPMENT  ·  %s" % weapon_name


func show_progress(level: int, exp: int, required: int) -> void:
	level_value.text = "Lv %d" % level
	if required > 0:
		exp_value.text = "EXP %d / %d" % [exp, required]
		exp_bar.max_value = required
		exp_bar.value = exp
	else:
		exp_value.text = "EXP MAX"
		exp_bar.max_value = 1
		exp_bar.value = 1


func show_inventory(count: int) -> void:
	inventory_count = count
	_refresh_meta()


func show_gold(gold: int) -> void:
	gold_value.text = str(gold)


func show_equipment(equipment: Equipment) -> void:
	var captions := ["Main", "Sub", "Armor", "Acc 1", "Acc 2"]
	for index in equipment_rows.size():
		var item: ItemData = equipment.slots[index]
		var item_name := item.label() if item != null else EMPTY_EQUIPMENT
		equipment_rows[index].text = "%s    %s" % [captions[index].rpad(6), item_name]


func show_minimap(
	grid: GridState,
	explored: Dictionary,
	visible_cells: Dictionary,
	player_cell: Vector2i,
	stairs_cell: Vector2i,
	enemy_cells: Array[Vector2i],
	item_cells: Array[Vector2i]
) -> void:
	minimap.refresh(grid, explored, visible_cells, player_cell, stairs_cell, enemy_cells, item_cells)


func show_boss(text: String) -> void:
	$Boss.text = text
	$Boss.visible = not text.is_empty()


func reset_log() -> void:
	for node_name in ["HpTrail", "MpTrail", "HpValue", "MpValue"]:
		UIMotion.of(get_node("BottomLeft/" + node_name)).reset()
	log_history.clear()
	last_log_text = ""
	_render_log()


func _record_log(text: String) -> void:
	# Routine footsteps must not push damage and pickup feedback out of history.
	if text == "移動しました。":
		_render_log()
		return
	if text.is_empty() or text == last_log_text:
		_render_log()
		return
	last_log_text = text
	log_history.append(text)
	while log_history.size() > MAX_LOG_ENTRIES:
		log_history.pop_front()
	_render_log()


func _render_log(temporary_message: String = "") -> void:
	var lines: Array[String] = []
	for entry: String in log_history:
		lines.append("◇ %s" % entry)
	if not temporary_message.is_empty():
		if lines.size() >= MAX_LOG_ENTRIES:
			lines.pop_front()
		lines.append("◆ %s" % temporary_message)
	log_entries.text = "\n".join(lines)


func _refresh_meta() -> void:
	meta.text = "TURN %d  ·  所持品 %d / 40" % [turn_count, inventory_count]


func _terrain_label(value: String) -> String:
	match value:
		"Forest": return "深緑の森林"
		"Slate Ruins": return "蒼灰の遺跡"
		"Moss Caverns": return "苔むす洞窟"
		"Ember Depths": return "熾火の深層"
		"Obsidian Sanctum": return "黒曜の聖域"
	return value if not value.is_empty() else "未踏の迷宮"


func _layout_label(value: String) -> String:
	match value:
		"Room": return "部屋群"
		"OpenArea": return "大広間"
		"Cave": return "洞穴"
	return value


func show_effects(text: String) -> void:
	var label := get_node_or_null("ActiveEffects") as Label
	if label == null:
		label = Label.new()
		label.name = "ActiveEffects"
		label.position = Vector2(310, 64)
		label.size = Vector2(770, 90)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	label.text = text


func show_mana(current: int, maximum: int) -> void:
	mp_value.text = "%d / %d" % [current, maximum]
	mp_bar.max_value = max(maximum, 1)
	mp_bar.value = max(current, 0)
	UIMotion.of($BottomLeft/MpTrail).update_vital(current, maximum, mp_value)
