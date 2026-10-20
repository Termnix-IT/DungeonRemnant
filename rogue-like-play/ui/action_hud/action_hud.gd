class_name ActionHud
extends CanvasLayer

# The provisional HUD of the real-time fight: the hero's health and dashes at
# the bottom left; the time, foe count, kills and frame rate at the top left
# (with how the foes are being sent, when an EnemyDirector is watched); the
# controls along the bottom and a message in the middle (paused, fallen).
# The real HUD replaces it in Phase 5; it only reads the area.

const DASH_FULL := Color("9fe3dc")
const DASH_EMPTY := Color(0.35, 0.4, 0.42, 0.6)
const CONTROLS := "WASD 移動　／　左クリック 攻撃（長押しで溜め）　／　Space 回避　／　1〜5 敵の数を固定　0 時間で増加　／　Esc 一時停止"

var area: CombatArea
var hp_bar: ProgressBar
var hp_value: Label
var dashes: Control
var info: Label
var message: Label


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
	dashes = Control.new()
	dashes.custom_minimum_size = Vector2(320, 16)
	dashes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dashes.draw.connect(_draw_dashes)
	vitals.add_child(dashes)
	info = Label.new()
	info.theme_type_variation = &"HudSmall"
	info.position = Vector2(32, 24)
	root.add_child(info)
	var guide := Label.new()
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
	root.add_child(message)
	for label: Label in [hp_value, caption, info, guide, message]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func watch(combat_area: CombatArea) -> void:
	area = combat_area


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
	info.text = line
	dashes.queue_redraw()


func _draw_dashes() -> void:
	if area == null or area.hero == null:
		return
	var motor := area.hero.motor
	for index in motor.tuning.dash_charges:
		var center := Vector2(10 + index * 26, 8)
		dashes.draw_circle(center, 7.0, DASH_FULL if index < motor.dash_charges else DASH_EMPTY)
