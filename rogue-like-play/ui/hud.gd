extends CanvasLayer

const MAX_LOG_ENTRIES := 3
# The newest entries stay at full strength; older ones recede.
const EMPHASIZED_LOG_ENTRIES := 2
const PORTRAIT_SIZE := 112

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
@onready var log_entries: RichTextLabel = $Log/Entries
@onready var equipment_rows: HudEquipment = $BottomRight/Rows

var portrait: HudPortrait
var log_history: Array[String] = []
var last_log_text := ""
var last_log_key := -1
var turn_count := 0
var inventory_count := 0


func _ready() -> void:
	# The face sits just above the vitals panel, anchored to the same corner.
	portrait = HudPortrait.new()
	portrait.name = "Portrait"
	portrait.theme = $BottomLeft.theme
	add_child(portrait)
	portrait.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var vitals: Panel = $BottomLeft
	portrait.offset_left = vitals.offset_left
	portrait.offset_right = vitals.offset_left + PORTRAIT_SIZE
	portrait.offset_bottom = vitals.offset_top - 8
	portrait.offset_top = portrait.offset_bottom - PORTRAIT_SIZE
	portrait.grow_vertical = Control.GROW_DIRECTION_BEGIN


# log_key identifies the action the text belongs to: text that grows within one
# action replaces its entry, and a repeated line from a new action is kept.
func refresh(hp: int, max_hp: int, turns: int, visible_enemies: int, log_text: String, floor_number: int, layout_name: String, terrain_name: String = "", total_floors: int = 10, log_key: int = -1) -> void:
	status.text = "%d / %dF  %s     HP %d / %d     TURN %d     視界内の敵 %d" % [floor_number, total_floors, layout_name, hp, max_hp, turns, visible_enemies]
	floor_value.text = "%d / %d" % [floor_number, total_floors]
	area.text = "%s・%s" % [_terrain_label(terrain_name), _layout_label(layout_name)]
	show_health(hp, max_hp)
	turn_count = turns
	_refresh_meta()
	_record_log(log_text, log_key)


func show_health(hp: int, max_hp: int) -> void:
	hp_value.text = "%d / %d" % [hp, max_hp]
	hp_bar.max_value = max(max_hp, 1)
	hp_bar.value = max(hp, 0)
	UIMotion.of($BottomLeft/HpTrail).update_vital(hp, max_hp, hp_value)
	portrait.show_health(hp, max_hp)


func show_aim(weapon_name: String, aiming: bool) -> void:
	if aiming:
		_render_log("攻撃方向を選択中：方向キーで変更 / Spaceで確定 / Escでキャンセル")
	$BottomRight/Title.text = "装備  ·  %s" % weapon_name


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
	equipment_rows.show_equipment(equipment)


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
	UIMotion.of(portrait).reset()
	portrait.reset()
	log_history.clear()
	last_log_text = ""
	last_log_key = -1
	_render_log()


func _record_log(value: String, key: int = -1) -> void:
	# Silent actions (plain footsteps) must not push damage and pickup
	# feedback out of history.
	var text := value.strip_edges()
	var same_action := key >= 0 and key == last_log_key and not log_history.is_empty()
	if text.is_empty() or (text == last_log_text and (key < 0 or same_action)):
		_render_log()
		return
	last_log_text = text
	last_log_key = key
	if same_action:
		log_history[-1] = text
		_render_log()
		return
	log_history.append(text)
	while log_history.size() > MAX_LOG_ENTRIES:
		log_history.pop_front()
	_render_log()
	UIMotion.of(log_entries).reveal()


func _render_log(temporary_message: String = "") -> void:
	var lines: Array[String] = []
	for entry: String in log_history:
		lines.append("◇ %s" % entry)
	if not temporary_message.is_empty():
		if lines.size() >= MAX_LOG_ENTRIES:
			lines.pop_front()
		lines.append("◆ %s" % temporary_message)
	# Text is appended, never parsed as BBCode, so messages stay literal.
	var recent := _log_color(&"Label")
	var older := _log_color(&"HudSmall")
	log_entries.clear()
	for index in lines.size():
		if index > 0:
			log_entries.newline()
		log_entries.push_color(recent if index >= lines.size() - EMPHASIZED_LOG_ENTRIES else older)
		log_entries.add_text(lines[index])
		log_entries.pop()


func _log_color(role: StringName) -> Color:
	return log_entries.get_theme_color(&"font_color", role)


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


# Sits under the floor/Gold panel, matching its width.
func show_effects(active: Array[Dictionary]) -> void:
	var panel := get_node_or_null("ActiveEffects") as HudEffects
	if panel == null:
		panel = HudEffects.new()
		panel.name = "ActiveEffects"
		panel.theme = $TopLeft.theme
		add_child(panel)
		panel.position = Vector2($TopLeft.position.x, $TopLeft.position.y + $TopLeft.size.y + 8)
		panel.size.x = $TopLeft.size.x
	panel.show_entries(active)


func show_mana(current: int, maximum: int) -> void:
	mp_value.text = "%d / %d" % [current, maximum]
	mp_bar.max_value = max(maximum, 1)
	mp_bar.value = max(current, 0)
	UIMotion.of($BottomLeft/MpTrail).update_vital(current, maximum, mp_value)
