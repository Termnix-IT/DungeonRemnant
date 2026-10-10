extends CanvasLayer

const MAX_LOG_ENTRIES := 3
# The newest entries stay at full strength; older ones recede.
const EMPHASIZED_LOG_ENTRIES := 2
# The face frame sits in the vitals plate's top-left, beside the HP and MP bars.
const PORTRAIT_SIZE := 104
const PORTRAIT_INSET := 14
const EFFECTS_POSITION := Vector2(16, 16)
# The weapon in hand, between the EXP bar and the turn line.
const WEAPON_RECT := Rect2(14, 172, 330, 46)
const EFFECTS_WIDTH := 330.0
# Announcements and the boss gauge share one band at the screen's top edge,
# above the ring of floor round the hero that the HUD keeps clear. The
# band's finial spikes reach 18px above it, still on the screen.
const NOTICE_TOP := 18.0
# The message log is full strength while it has news, then recedes so the
# floor under it shows; a new line brings it back.
const LOG_FRESH_TIME := 4.0
const LOG_RESTING_ALPHA := 0.5
# The tag over the hero while an attack's direction is chosen, this far above
# the hero's cell centre.
const AIM_TAG_RISE := 64.0
# Each log entry leads with a painted mark for what kind of news it is, so the
# log can be skimmed before it is read. A turn's entry often joins several
# events; the first kind whose words it holds names it, harm before all else.
const LOG_MARK_SIZE := 18
const LOG_MARKS: Array = [
	[&"harm", ["の攻撃で", "に倒された", "強制帰還", "様子が変"]],
	[&"victory", ["を倒した", "撃破", "ダメージ", "EXP +"]],
	[&"floor", ["Fに到着", "F："]],
	[&"supply", ["を使った", "回復", "装備を変更"]],
]

@onready var status: Label = $Status
@onready var floor_value: Label = $TopRight/Floor
@onready var gold_value: Label = $BottomLeft/Gold
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

var portrait: HudPortrait
var weapon: HudWeapon
var actions: HudActions
var aim_tag: Label
var _log_rest: Timer
var log_history: Array[String] = []
var last_log_text := ""
var last_log_key := -1
var turn_count := 0
var inventory_count := 0
var _gold := -1


func _ready() -> void:
	var vitals: Panel = $BottomLeft
	weapon = HudWeapon.new()
	weapon.name = "Weapon"
	vitals.add_child(weapon)
	weapon.position = WEAPON_RECT.position
	weapon.size = WEAPON_RECT.size
	# What can be done now, at the bottom right: the keys the HUD shows nowhere
	# else (Tab sits on the weapon row, beside the weapons it swaps).
	actions = HudActions.new()
	actions.name = "Actions"
	actions.theme = $TopRight.theme
	add_child(actions)
	aim_tag = Label.new()
	aim_tag.name = "AimTag"
	aim_tag.theme = $TopRight.theme
	aim_tag.theme_type_variation = &"HudAimTag"
	aim_tag.text = "攻撃の向き"
	aim_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_tag.hide()
	add_child(aim_tag)
	_log_rest = Timer.new()
	_log_rest.one_shot = true
	_log_rest.timeout.connect(func(): UIMotion.of($Log).fade_to(LOG_RESTING_ALPHA))
	add_child(_log_rest)
	portrait = HudPortrait.new()
	portrait.name = "Portrait"
	vitals.add_child(portrait)
	portrait.position = Vector2.ONE * PORTRAIT_INSET
	portrait.size = Vector2.ONE * PORTRAIT_SIZE
	for bar: ProgressBar in [hp_bar, mp_bar]:
		var ticks := VitalTicks.new()
		ticks.name = bar.name + "Ticks"
		vitals.add_child(ticks)
		vitals.move_child(ticks, bar.get_index() + 1)
		ticks.position = bar.position
		ticks.size = bar.size


# log_key identifies the action the text belongs to: text that grows within one
# action replaces its entry, and a repeated line from a new action is kept.
func refresh(hp: int, max_hp: int, turns: int, visible_enemies: int, log_text: String, floor_number: int, layout_name: String, _terrain_name: String = "", total_floors: int = 10, log_key: int = -1) -> void:
	status.text = "%d / %dF  %s     HP %d / %d     TURN %d     視界内の敵 %d" % [floor_number, total_floors, layout_name, hp, max_hp, turns, visible_enemies]
	floor_value.text = "%d / %d" % [floor_number, total_floors]
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


# The settings' 操作の案内: the actions card can be put away by players who
# know the keys. The tag over the hero stays, the one sign of the aim on the
# floor itself.
func show_controls(shown: bool) -> void:
	actions.visible = shown


# While an attack's direction is chosen: the card at the bottom right turns
# into the aim's own, and a tag stands over the hero (at, on the screen).
func show_aim(aiming: bool, at: Vector2 = Vector2.ZERO, staff: bool = false) -> void:
	if aiming != actions.aiming or staff != actions.can_cast:
		actions.show_state(aiming, staff)
	aim_tag.visible = aiming
	if aiming:
		aim_tag.reset_size()
		aim_tag.position = (at - Vector2(aim_tag.size.x * 0.5, AIM_TAG_RISE + aim_tag.size.y)).round()


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


# A gain counts up from the old amount and glints; a drop (a new run, a
# loss) shows at once.
func show_gold(gold: int) -> void:
	if gold == _gold:
		return
	var format := func(value: int) -> String: return "%s G" % UIFormat.amount(value)
	if _gold >= 0 and gold > _gold and gold_value.is_visible_in_tree():
		UIMotion.of(gold_value).count(_gold, gold, format)
		UIMotion.of(gold_value).flash()
	else:
		UIMotion.of(gold_value).reset()
		gold_value.text = format.call(gold)
	_gold = gold


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


# An empty name hides the boss gauge.
func show_boss(boss_name: String, hp: int = 0, max_hp: int = 0) -> void:
	($Boss as BossGauge).present(boss_name, hp, max_hp)


# attack is the weapon the attack code uses for main, so its range matches.
func show_weapons(main: ItemData, sub: ItemData, attack: WeaponData) -> void:
	weapon.show_weapons(main, sub, attack)


# Where announcement banners stand: the band at the screen's top edge.
func notice_lane_top() -> float:
	return NOTICE_TOP


# A banner in the top band stands where the boss gauge does; the gauge steps
# aside while it shows.
func make_room_for_notice(showing: bool) -> void:
	($Boss as Control).modulate.a = 0.0 if showing else 1.0


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
	_freshen_log()
	while log_history.size() > MAX_LOG_ENTRIES:
		log_history.pop_front()
	_render_log()
	UIMotion.of(log_entries).reveal()


func _render_log(temporary_message: String = "") -> void:
	var lines: Array[String] = log_history.duplicate()
	if not temporary_message.is_empty():
		if lines.size() >= MAX_LOG_ENTRIES:
			lines.pop_front()
		lines.append(temporary_message)
	# Long lines wrap; when the wrapped text overflows the box, the oldest
	# entries give way so the newest line is never cut off at the bottom.
	_write_log(lines)
	while lines.size() > 1 and log_entries.get_content_height() > log_entries.size.y:
		lines.pop_front()
		_write_log(lines)


func _write_log(lines: Array[String]) -> void:
	# Text is appended, never parsed as BBCode, so messages stay literal.
	var recent := _log_color(&"Label")
	var older := _log_color(&"HudSmall")
	log_entries.clear()
	for index in lines.size():
		if index > 0:
			log_entries.newline()
		var faded := index < lines.size() - EMPHASIZED_LOG_ENTRIES
		var mark := log_entries.get_theme_icon(log_mark(lines[index]), &"HudLog")
		log_entries.add_image(mark, LOG_MARK_SIZE, LOG_MARK_SIZE, Color(1, 1, 1, 0.6) if faded else Color.WHITE, INLINE_ALIGNMENT_CENTER)
		log_entries.add_text("  ")
		log_entries.push_color(older if faded else recent)
		log_entries.add_text(lines[index])
		log_entries.pop()


# The kind of news an entry is, which names its mark.
static func log_mark(text: String) -> StringName:
	for kind: Array in LOG_MARKS:
		for words: String in kind[1]:
			if text.contains(words):
				return kind[0]
	return &"news"


func _log_color(role: StringName) -> Color:
	return log_entries.get_theme_color(&"font_color", role)


# News brings the log to full strength; after a while it recedes again.
func _freshen_log() -> void:
	UIMotion.of($Log).reset()
	_log_rest.start(LOG_FRESH_TIME)


func _refresh_meta() -> void:
	meta.text = "TURN %d  ·  所持品 %d / 40" % [turn_count, inventory_count]


func terrain_label(value: String) -> String:
	match value:
		"Forest": return "深緑の森林"
		"Slate Ruins": return "蒼灰の遺跡"
		"Moss Caverns": return "苔むす洞窟"
		"Ember Depths": return "熾火の深層"
		"Obsidian Sanctum": return "黒曜の聖域"
	return value if not value.is_empty() else "未踏の迷宮"


# Takes the otherwise empty top-left corner.
func show_effects(active: Array[Dictionary]) -> void:
	var panel := get_node_or_null("ActiveEffects") as HudEffects
	if panel == null:
		panel = HudEffects.new()
		panel.name = "ActiveEffects"
		panel.theme = $TopRight.theme
		add_child(panel)
		panel.position = EFFECTS_POSITION
		panel.size.x = EFFECTS_WIDTH
	panel.show_entries(active)


func show_mana(current: int, maximum: int) -> void:
	mp_value.text = "%d / %d" % [current, maximum]
	mp_bar.max_value = max(maximum, 1)
	mp_bar.value = max(current, 0)
	UIMotion.of($BottomLeft/MpTrail).update_vital(current, maximum, mp_value)
