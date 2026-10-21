class_name ActionHud
extends CanvasLayer

# The HUD of the real-time fight, in the corners so the ground round the
# hero stays clear:
# - along the top, the run's experience with its level at the left;
# - at the top left, the area's name, its goal with a bar of how far it has
#   come, the foes felled, and under them the boons taken as their emblems
#   with their ranks;
# - at the bottom left, her health (a trail shows what a blow took), her
#   dashes as gems and her skill as a dial that fills as it comes back;
# - the controls along the bottom, and a banner in the middle for the
#   area's name, its clearing, her fall and the boss's rage;
# - at 30% health or less, the screen's edges pulse red, deeper and faster
#   the less is left.
# It only reads the area (and its `run`, `director` and `boss_foe`, when it
# has them). A trial area (the sandbox) adds its keys and its counters.

const DASH_FULL := Color("9fe3dc")
const DASH_EMPTY := Color(0.35, 0.4, 0.42, 0.6)
const SKILL_READY := Color("ffd27a")
const SKILL_WAIT := Color(0.55, 0.58, 0.62, 0.9)
const DIAL_BACK := Color(0.02, 0.025, 0.035, 0.88)
const GEM_EDGE := Color(0.02, 0.025, 0.035, 0.85)
const CONTROLS := "WASD 移動　／　左クリック 攻撃（長押しで溜め）　／　Space 回避　／　Q スキル　／　Esc メニュー"
# The banner sits this far above the middle, clear of the hero.
const MESSAGE_RISE := 190.0
const EDGE := 32.0
const BAR_WIDTH := 340.0
const GOAL_WIDTH := 300.0
const EMBLEM_SIZE := 40.0
const DIAL_SIZE := 44.0
# The share of health from which the edges pulse, and their pulse rates (per
# second) at that share and at the last of it.
const DANGER_SHARE := 0.3
const DANGER_RATE := Vector2(1.2, 2.6)

var area: CombatArea
var hp_bar: ProgressBar
var hp_trail: ProgressBar
var hp_value: Label
var dashes: Control
var skill_dial: Control
var skill_label: Label
var exp_bar: ProgressBar
var level_label: Label
# The goal: the area's name, what to do, how far it has come, the foes felled.
var info: Label
var area_label: Label
var goal_bar: ProgressBar
var kills_label: Label
var boons: HBoxContainer
var trial_label: Label
var guide: Label
var banner: PanelContainer
var message: Label
var boss_gauge: BossGauge
var danger: TextureRect
var _boons_shown := ""
var _danger_time := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_danger(root)
	_build_top(root)
	_build_vitals(root)
	guide = _label(root, &"HudSmall")
	guide.text = CONTROLS
	guide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	guide.position.y -= 36
	boss_gauge = BossGauge.new()
	boss_gauge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_gauge.offset_left = -380
	boss_gauge.offset_right = 380
	boss_gauge.offset_top = 30
	boss_gauge.offset_bottom = 132
	boss_gauge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(boss_gauge)
	boss_gauge.hide()
	banner = PanelContainer.new()
	banner.theme_type_variation = &"BannerBand"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.position.y -= MESSAGE_RISE
	root.add_child(banner)
	message = _label(banner, &"HudBanner")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.hide()


# Clear in the middle, red at the edges; under the rest of the HUD.
func _build_danger(root: Control) -> void:
	var red := root.get_theme_color(&"font_color", &"HpCaption")
	var fade := Gradient.new()
	fade.set_color(0, Color(red, 0.0))
	fade.set_color(1, Color(red, 0.55))
	fade.add_point(0.6, Color(red, 0.0))
	var edges := GradientTexture2D.new()
	edges.gradient = fade
	edges.fill = GradientTexture2D.FILL_RADIAL
	edges.fill_from = Vector2(0.5, 0.5)
	edges.fill_to = Vector2(0.5, 1.12)
	danger = TextureRect.new()
	danger.texture = edges
	danger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	danger.stretch_mode = TextureRect.STRETCH_SCALE
	danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(danger)
	danger.hide()


func _build_top(root: Control) -> void:
	exp_bar = ProgressBar.new()
	exp_bar.theme_type_variation = &"ExpBar"
	exp_bar.show_percentage = false
	exp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	exp_bar.offset_left = 120
	exp_bar.offset_right = -EDGE
	exp_bar.offset_top = 16
	exp_bar.offset_bottom = 26
	root.add_child(exp_bar)
	level_label = _label(root, &"HudValue")
	level_label.position = Vector2(EDGE, 8)
	var goal := VBoxContainer.new()
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.position = Vector2(EDGE, 44)
	goal.custom_minimum_size.x = GOAL_WIDTH
	root.add_child(goal)
	area_label = _label(goal, &"HudCaption")
	info = _label(goal, &"VitalCaption")
	goal_bar = ProgressBar.new()
	goal_bar.theme_type_variation = &"ExpBar"
	goal_bar.show_percentage = false
	goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_bar.custom_minimum_size = Vector2(GOAL_WIDTH, 8)
	goal.add_child(goal_bar)
	kills_label = _label(goal, &"HudCaption")
	boons = HBoxContainer.new()
	boons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.add_child(boons)
	trial_label = _label(goal, &"HudSmall")


func _build_vitals(root: Control) -> void:
	var vitals := VBoxContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.position = Vector2(EDGE, -138)
	root.add_child(vitals)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(row)
	var caption := _label(row, &"HpCaption")
	caption.text = "HP"
	hp_value = _label(row, &"HudValue")
	# The bar over its trail, with quarter notches on top.
	var gauge := Control.new()
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.custom_minimum_size = Vector2(BAR_WIDTH, 18)
	vitals.add_child(gauge)
	hp_trail = ProgressBar.new()
	hp_trail.theme_type_variation = &"HpTrail"
	hp_bar = ProgressBar.new()
	hp_bar.theme_type_variation = &"HpCurrent"
	for bar: ProgressBar in [hp_trail, hp_bar]:
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		gauge.add_child(bar)
	var ticks := VitalTicks.new()
	ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	gauge.add_child(ticks)
	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(actions)
	skill_dial = Control.new()
	skill_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_dial.custom_minimum_size = Vector2(DIAL_SIZE, DIAL_SIZE)
	skill_dial.draw.connect(_draw_skill)
	actions.add_child(skill_dial)
	# The skill's key while ready, the seconds left while it comes back.
	skill_label = _label(skill_dial, &"HudValue")
	skill_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dashes = Control.new()
	dashes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dashes.custom_minimum_size = Vector2(120, DIAL_SIZE)
	dashes.draw.connect(_draw_dashes)
	actions.add_child(dashes)


func _label(parent: Control, role: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# An area may add keys of its own to the controls line (trial_keys()).
func watch(combat_area: CombatArea) -> void:
	area = combat_area
	if area.has_method(&"trial_keys"):
		guide.text = CONTROLS + "　／　" + area.trial_keys()


# The banner in the middle; empty hides it.
func show_message(text: String) -> void:
	message.text = text
	banner.visible = not text.is_empty()


func _process(delta: float) -> void:
	if area == null or area.hero == null:
		return
	var health := area.hero.health
	_show_danger(float(health.hp) / maxf(1.0, health.max_hp), delta)
	hp_bar.max_value = health.max_hp
	hp_bar.value = health.hp
	hp_value.text = "%d / %d" % [health.hp, health.max_hp]
	UIMotion.of(hp_trail).update_vital(health.hp, health.max_hp, hp_value)
	_show_goal()
	var motor := area.hero.motor
	skill_dial.visible = motor.moveset.skill != null
	if skill_dial.visible:
		skill_label.text = "Q" if motor.skill_cooldown_left <= 0.0 else str(ceili(motor.skill_cooldown_left))
		skill_dial.queue_redraw()
	var run: RunState = area.get(&"run")
	exp_bar.visible = run != null
	level_label.visible = run != null
	if run != null:
		exp_bar.max_value = maxi(1, run.progression.required_exp())
		exp_bar.value = run.progression.exp
		level_label.text = "Lv %d" % run.progression.level
		_show_boons(run.build)
	var boss: Foe = area.get(&"boss_foe")
	if boss != null and is_instance_valid(boss) and not boss.dying:
		if boss_gauge.bar == null or not boss_gauge.visible or boss_gauge.bar.value != boss.health.hp:
			boss_gauge.present(boss.data.display_name, boss.health.hp, boss.health.max_hp)
	elif boss_gauge.visible:
		boss_gauge.present("", 0, 0)
	dashes.queue_redraw()


func _show_danger(share: float, delta: float) -> void:
	danger.visible = share > 0.0 and share <= DANGER_SHARE
	if not danger.visible:
		_danger_time = 0.0
		return
	var depth := 1.0 - share / DANGER_SHARE
	_danger_time += delta * lerpf(DANGER_RATE.x, DANGER_RATE.y, depth)
	var pulse := 0.5 + 0.5 * sin(_danger_time * TAU)
	danger.modulate.a = lerpf(0.45, 1.0, depth) * lerpf(0.55, 1.0, pulse)


# The area's goal and how far it has come; a trial area's counters under it.
func _show_goal() -> void:
	var data: AreaData = area.get(&"data")
	area_label.text = data.display_name if data != null else ""
	area_label.visible = data != null
	info.text = area.objective_text() if area.has_method(&"objective_text") else ""
	info.visible = not info.text.is_empty()
	var progress := _goal_progress(data)
	goal_bar.visible = progress >= 0.0
	goal_bar.value = progress * 100.0
	kills_label.text = "撃破 %d" % area.kills
	trial_label.visible = area.has_method(&"trial_keys")
	if trial_label.visible:
		var director: EnemyDirector = area.get(&"director")
		var line := "敵 %d　%d FPS" % [area.foes.size(), Engine.get_frames_per_second()]
		if director != null:
			var sending := "固定 %d体" % director.fixed_alive if director.fixed_alive > 0 else "時間で増加（目標 %d体）" % director.target_alive()
			line = "%d:%02d　%s　／　%s" % [floori(director.elapsed / 60.0), floori(director.elapsed) % 60, line, sending]
		trial_label.text = line


# How far the goal has come, 0 to 1; -1 when it has no measure.
func _goal_progress(data: AreaData) -> float:
	if data == null:
		return -1.0
	# The boss's own gauge across the top tells it.
	if data.boss != null:
		return -1.0
	var waves: WaveRunner = area.get(&"waves")
	if waves != null:
		return clampf(float(maxi(waves.wave, 0)) / maxf(1.0, data.waves.size()), 0.0, 1.0) if not waves.done() else 1.0
	if data.kill_target > 0:
		return clampf(float(area.kills) / data.kill_target, 0.0, 1.0)
	if data.survive_time > 0.0:
		return clampf(float(area.get(&"elapsed")) / data.survive_time, 0.0, 1.0)
	return -1.0


# The boons taken, as emblems with their rank; rebuilt only when they change.
func _show_boons(build: BuildState) -> void:
	var shown := ""
	for boon in build.owned():
		shown += "%s:%d " % [boon.id, build.rank(boon.id)]
	if shown == _boons_shown:
		return
	_boons_shown = shown
	for child in boons.get_children():
		child.queue_free()
	for boon in build.owned():
		var icon := TextureRect.new()
		icon.texture = EmblemIcons.texture(boon.emblem)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boons.add_child(icon)
		if boon.max_level > 1:
			var rank := _label(icon, &"HudCaption")
			rank.text = str(build.rank(boon.id))
			rank.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			rank.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			rank.grow_vertical = Control.GROW_DIRECTION_BEGIN


# The skill as a dial: its ring fills as it comes back, gold when ready.
func _draw_skill() -> void:
	if area == null or area.hero == null:
		return
	var motor := area.hero.motor
	var center := skill_dial.size * 0.5
	var radius := DIAL_SIZE * 0.5 - 3.0
	skill_dial.draw_circle(center, radius, DIAL_BACK)
	var cooldown := motor.moveset.skill_cooldown if motor.moveset.skill != null else 0.0
	var ready := motor.skill_cooldown_left <= 0.0
	var share := 1.0 if ready or cooldown <= 0.0 else 1.0 - motor.skill_cooldown_left / cooldown
	skill_dial.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * share, 40, SKILL_READY if ready else SKILL_WAIT, 4.0 if ready else 3.0, true)


# Her dashes as gems: bright when ready, dim while they come back.
func _draw_dashes() -> void:
	if area == null or area.hero == null:
		return
	var motor := area.hero.motor
	for index in motor.tuning.dash_charges:
		var center := Vector2(22 + index * 32, dashes.size.y * 0.5)
		dashes.draw_colored_polygon(_gem(center, 15.0), GEM_EDGE)
		dashes.draw_colored_polygon(_gem(center, 11.0), DASH_FULL if index < motor.dash_charges else DASH_EMPTY)


func _gem(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -half), center + Vector2(half * 0.75, 0), center + Vector2(0, half), center + Vector2(-half * 0.75, 0)])
