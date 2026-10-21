class_name ActionHud
extends CanvasLayer

# The provisional HUD of the real-time fight: the hero's health, dashes and
# skill at the bottom left; the run's experience along the top with its
# level; the time, foe count, kills and frame rate at the top left (with how
# the foes are being sent, when an EnemyDirector is watched) and the boons
# taken under them; the controls along the bottom and a message in the
# middle (paused, fallen). The real HUD replaces it in Phase 5; it only
# reads the area (and its `director` and `run`, when it has them).

const DASH_FULL := Color("9fe3dc")
const DASH_EMPTY := Color(0.35, 0.4, 0.42, 0.6)
const CONTROLS := "WASD 移動　／　左クリック 攻撃（長押しで溜め）　／　Space 回避　／　Q スキル　／　Esc 一時停止"
# The message sits this far above the middle, clear of the hero.
const MESSAGE_RISE := 190.0

var area: CombatArea
var hp_bar: ProgressBar
var hp_value: Label
var dashes: Control
var info: Label
var message: Label
var guide: Label
var exp_bar: ProgressBar
var level_label: Label
var skill_label: Label
var boons_label: Label


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var vitals := VBoxContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.position = Vector2(32, -112)
	vitals.add_theme_constant_override("separation", 6)
	root.add_child(vitals)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	vitals.add_child(row)
	var caption := Label.new()
	caption.theme_type_variation = &"HpCaption"
	caption.text = "HP"
	row.add_child(caption)
	hp_value = Label.new()
	hp_value.theme_type_variation = &"HudValue"
	row.add_child(hp_value)
	hp_bar = ProgressBar.new()
	hp_bar.theme_type_variation = &"HpCurrent"
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(320, 18)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(hp_bar)
	skill_label = Label.new()
	skill_label.theme_type_variation = &"HudSmall"
	vitals.add_child(skill_label)
	dashes = Control.new()
	dashes.custom_minimum_size = Vector2(320, 16)
	dashes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dashes.draw.connect(_draw_dashes)
	vitals.add_child(dashes)
	exp_bar = ProgressBar.new()
	exp_bar.theme_type_variation = &"ExpBar"
	exp_bar.show_percentage = false
	exp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	exp_bar.offset_left = 120
	exp_bar.offset_right = -32
	exp_bar.offset_top = 10
	exp_bar.offset_bottom = 20
	root.add_child(exp_bar)
	level_label = Label.new()
	level_label.theme_type_variation = &"HudValue"
	level_label.position = Vector2(32, 2)
	root.add_child(level_label)
	info = Label.new()
	info.theme_type_variation = &"HudSmall"
	info.position = Vector2(32, 30)
	root.add_child(info)
	boons_label = Label.new()
	boons_label.theme_type_variation = &"HudSmall"
	boons_label.position = Vector2(32, 54)
	root.add_child(boons_label)
	guide = Label.new()
	guide.theme_type_variation = &"HudSmall"
	guide.text = CONTROLS
	guide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	guide.position.y -= 36
	root.add_child(guide)
	message = Label.new()
	message.theme_type_variation = &"HudValue"
	message.add_theme_font_size_override("font_size", 34)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message.grow_vertical = Control.GROW_DIRECTION_BOTH
	message.position.y -= MESSAGE_RISE
	root.add_child(message)
	for control: Control in [hp_value, caption, info, guide, message, exp_bar, level_label, skill_label, boons_label]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


# An area may add keys of its own to the controls line (trial_keys()).
func watch(combat_area: CombatArea) -> void:
	area = combat_area
	if area.has_method(&"trial_keys"):
		guide.text = CONTROLS + "　／　" + area.trial_keys()


func show_message(text: String) -> void:
	message.text = text


func _process(_delta: float) -> void:
	if area == null or area.hero == null:
		return
	var health := area.hero.health
	hp_bar.max_value = health.max_hp
	hp_bar.value = health.hp
	hp_value.text = "%d / %d" % [health.hp, health.max_hp]
	var director: EnemyDirector = area.get(&"director")
	var line := "敵 %d　撃破 %d　%d FPS" % [area.foes.size(), area.kills, Engine.get_frames_per_second()]
	if director != null:
		var minutes := floori(director.elapsed / 60.0)
		var sending := "固定 %d体" % director.fixed_alive if director.fixed_alive > 0 else "時間で増加（目標 %d体）" % director.target_alive()
		line = "%d:%02d　%s　／　%s" % [minutes, floori(director.elapsed) % 60, line, sending]
	var goal: String = area.objective_text() if area.has_method(&"objective_text") else ""
	info.text = goal + "　／　" + line if not goal.is_empty() else line
	var motor := area.hero.motor
	if motor.moveset.skill != null:
		skill_label.text = "Q スキル　準備よし" if motor.skill_cooldown_left <= 0.0 else "Q スキル　あと%.1f秒" % motor.skill_cooldown_left
	var run: RunState = area.get(&"run")
	exp_bar.visible = run != null
	level_label.visible = run != null
	if run != null:
		exp_bar.max_value = maxi(1, run.progression.required_exp())
		exp_bar.value = run.progression.exp
		level_label.text = "Lv %d" % run.progression.level
		var taken: Array[String] = []
		for boon in run.build.owned():
			var rank := run.build.rank(boon.id)
			taken.append(boon.display_name if boon.max_level == 1 else "%s %d" % [boon.display_name, rank])
		boons_label.text = "　".join(taken)
	dashes.queue_redraw()


func _draw_dashes() -> void:
	if area == null or area.hero == null:
		return
	var motor := area.hero.motor
	for index in motor.tuning.dash_charges:
		var center := Vector2(10 + index * 26, 8)
		dashes.draw_circle(center, 7.0, DASH_FULL if index < motor.dash_charges else DASH_EMPTY)
