class_name ActionHud
extends CanvasLayer

# The HUD of the real-time fight, laid out as action roguelites and
# survivor games commonly do, the ground round the hero kept clear:
# - along the top edge, the run's experience, its level at the right end;
# - at the top centre, the goal (the area, what to do, a bar of how far it
#   has come); the boss's gauge takes its place once the boss is in;
# - at the top left, the boons taken as their emblems with their ranks;
# - at the top right, the foes felled and the echo earned in the run;
# - at the bottom left, her health (a trail shows what a blow took);
# - at the bottom right, her actions as round slots (attack, dash, skills,
#   special move) with their keys, a sweep while they come back, pips for
#   the dashes, a ring while she charges, and the special's gauge as its
#   sweep (it pulses gold once full);
# - the rest of the controls along the bottom, and a banner in the middle
#   for the area's name, its clearing, her fall and the boss's rage;
# - at 30% health or less, the screen's edges pulse red, deeper and faster
#   the less is left.
# It only reads the area (and its `run`, `director`, `waves` and `boss_foe`,
# when it has them). A trial area (the sandbox) adds its keys and counters.

const CONTROLS := "WASD 移動　／　長押しで溜め攻撃　／　Esc メニュー"
# The action slots' emblems, and their keys on a keyboard and a gamepad.
const SLOTS := [
	[&"strike", "sword_damage", "左クリック", "X"],
	[&"dash", "double_dash", "Space", "A"],
	[&"skill", "hammer_damage", "Q", "Y"],
	[&"skill_2", "hammer_damage", "E", "B"],
	[&"special", "seal_special", "R", "LB"],
]
# The skill slots' HUD keys, in the motor's slot order.
const SKILL_SLOTS: Array[StringName] = [&"skill", &"skill_2"]
const CHARGE_COLOR := Color("ffd27a")
# The special's slot pulses this fast (per second) and this much once full.
const SPECIAL_PULSE := 1.6
const SPECIAL_SWELL := 0.08
# The banner sits this far above the middle, clear of the hero.
const MESSAGE_RISE := 190.0
const EDGE := 32.0
const BAR_WIDTH := 360.0
const GOAL_WIDTH := 380.0
const EMBLEM_SIZE := 40.0
const BOONS_WIDTH := 360.0
# The share of health from which the edges pulse, and their pulse rates (per
# second) at that share and at the last of it.
const DANGER_SHARE := 0.3
const DANGER_RATE := Vector2(1.2, 2.6)

var area: CombatArea
var hp_bar: ProgressBar
var hp_trail: ProgressBar
var hp_value: Label
var exp_bar: ProgressBar
var level_label: Label
# The goal at the top centre: the area's name, what to do, how far it has come.
var goal: VBoxContainer
var area_label: Label
var info: Label
var goal_bar: ProgressBar
var boons: HFlowContainer
var kills_label: Label
var echo_label: Label
var trial_label: Label
var slots: Dictionary[StringName, ActionSlot] = {}
# The skill slot's key (the seconds left while it comes back).
var skill_label: Label
var guide: Label
var banner: PanelContainer
var message: Label
var boss_gauge: BossGauge
var danger: TextureRect
var _boons_shown := ""
var _special_full := false
var _special_time := 0.0
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
	_build_bottom(root)
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
	exp_bar.offset_left = EDGE
	exp_bar.offset_right = -EDGE - 96.0
	exp_bar.offset_top = 14
	exp_bar.offset_bottom = 24
	root.add_child(exp_bar)
	level_label = _label(root, &"HudValue")
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	level_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	level_label.offset_right = -EDGE
	level_label.offset_top = 4
	goal = VBoxContainer.new()
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.alignment = BoxContainer.ALIGNMENT_BEGIN
	goal.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	goal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	goal.custom_minimum_size.x = GOAL_WIDTH
	goal.offset_left = -GOAL_WIDTH * 0.5
	goal.offset_right = GOAL_WIDTH * 0.5
	goal.offset_top = 36
	root.add_child(goal)
	area_label = _label(goal, &"HudCaption")
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info = _label(goal, &"HudObjective")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_bar = ProgressBar.new()
	goal_bar.theme_type_variation = &"ExpBar"
	goal_bar.show_percentage = false
	goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_bar.custom_minimum_size = Vector2(GOAL_WIDTH, 8)
	goal.add_child(goal_bar)
	boons = HFlowContainer.new()
	boons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boons.position = Vector2(EDGE, 40)
	boons.custom_minimum_size.x = BOONS_WIDTH
	root.add_child(boons)
	var tally := VBoxContainer.new()
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tally.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tally.offset_right = -EDGE
	tally.offset_top = 40
	root.add_child(tally)
	kills_label = _label(tally, &"HudValue")
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	echo_label = _label(tally, &"HudGoldCaption")
	echo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trial_label = _label(tally, &"HudSmall")
	trial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_bottom(root: Control) -> void:
	var vitals := VBoxContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vitals.offset_left = EDGE
	vitals.offset_bottom = -EDGE
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
	gauge.custom_minimum_size = Vector2(BAR_WIDTH, 20)
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
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	actions.offset_right = -EDGE
	actions.offset_bottom = -EDGE + 8.0
	root.add_child(actions)
	for entry: Array in SLOTS:
		var slot := ActionSlot.new()
		slot.icon = EmblemIcons.texture(entry[1])
		slot.custom_minimum_size.x = 92.0
		actions.add_child(slot)
		slots[entry[0]] = slot
	skill_label = slots[&"skill"].key_label
	slots[&"skill_2"].visible = false
	slots[&"special"].visible = false
	guide = _label(root, &"HudSmall")
	guide.text = CONTROLS
	guide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	guide.position.y -= 36


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
	var boss: Foe = area.get(&"boss_foe")
	var boss_in := boss != null and is_instance_valid(boss) and not boss.dying
	_show_goal(boss_in)
	_show_tally()
	_show_actions()
	_show_special(delta)
	var run: RunState = area.get(&"run")
	exp_bar.visible = run != null
	level_label.visible = run != null
	if run != null:
		exp_bar.max_value = maxi(1, run.progression.required_exp())
		exp_bar.value = run.progression.exp
		level_label.text = "Lv %d" % run.progression.level
		_show_boons(run.build)
	if boss_in:
		if boss_gauge.bar == null or not boss_gauge.visible or boss_gauge.bar.value != boss.health.hp:
			boss_gauge.present(boss.data.display_name, boss.health.hp, boss.health.max_hp)
	elif boss_gauge.visible:
		boss_gauge.present("", 0, 0)


func _show_danger(share: float, delta: float) -> void:
	danger.visible = share > 0.0 and share <= DANGER_SHARE
	if not danger.visible:
		_danger_time = 0.0
		return
	var depth := 1.0 - share / DANGER_SHARE
	_danger_time += delta * lerpf(DANGER_RATE.x, DANGER_RATE.y, depth)
	var pulse := 0.5 + 0.5 * sin(_danger_time * TAU)
	danger.modulate.a = lerpf(0.45, 1.0, depth) * lerpf(0.55, 1.0, pulse)


# The area's goal and how far it has come, until the boss's gauge takes over.
func _show_goal(boss_in: bool) -> void:
	var data: AreaData = area.get(&"data")
	info.text = area.objective_text() if area.has_method(&"objective_text") else ""
	goal.visible = data != null and not info.text.is_empty() and not boss_in
	if not goal.visible:
		return
	area_label.text = data.display_name
	var progress := _goal_progress(data)
	goal_bar.visible = progress >= 0.0
	goal_bar.value = progress * 100.0


# How far the goal has come, 0 to 1; -1 when it has no measure.
func _goal_progress(data: AreaData) -> float:
	if data.boss != null:
		return -1.0
	var waves: WaveRunner = area.get(&"waves")
	if waves != null:
		return 1.0 if waves.done() else clampf(float(maxi(waves.wave, 0)) / maxf(1.0, data.waves.size()), 0.0, 1.0)
	if data.kill_target > 0:
		return clampf(float(area.kills) / data.kill_target, 0.0, 1.0)
	if data.survive_time > 0.0:
		return clampf(float(area.get(&"elapsed")) / data.survive_time, 0.0, 1.0)
	return -1.0


# The foes felled and the run's echo; a trial area's counters under them.
func _show_tally() -> void:
	var run: RunState = area.get(&"run")
	kills_label.text = "撃破 %d" % ((run.kills if run != null else 0) + area.kills)
	echo_label.visible = run != null
	if run != null:
		echo_label.text = "残響 %s" % UIFormat.amount(run.echo)
	trial_label.visible = area.has_method(&"trial_keys")
	if trial_label.visible:
		var director: EnemyDirector = area.get(&"director")
		var line := "敵 %d　%d FPS" % [area.foes.size(), Engine.get_frames_per_second()]
		if director != null:
			var sending := "固定 %d体" % director.fixed_alive if director.fixed_alive > 0 else "時間で増加（目標 %d体）" % director.target_alive()
			line = "%d:%02d　%s\n%s" % [floori(director.elapsed / 60.0), floori(director.elapsed) % 60, line, sending]
		trial_label.text = line


# Attack, dash and skill: what is ready, what is coming back, the charge.
func _show_actions() -> void:
	var hero := area.hero
	var motor := hero.motor
	var pad := hero.using_pad()
	for entry: Array in SLOTS:
		slots[entry[0]].key_label.text = entry[3] if pad else entry[2]
	slots[&"strike"].show_state(1.0, motor.charge_progress() if motor.charging() else 0.0)
	slots[&"dash"].show_state(1.0 if motor.dash_charges > 0 else motor.dash_recharge(), 0.0, motor.dash_charges, motor.tuning.dash_charges if motor.tuning.dash_charges > 1 else 0)
	# Each skill slot shows the skill set in it, or nothing when it is empty.
	for index in SKILL_SLOTS.size():
		var skill: ActionSlot = slots[SKILL_SLOTS[index]]
		skill.visible = motor.skill_attacks[index] != null
		if not skill.visible:
			continue
		var emblem := EmblemIcons.texture(motor.skill_emblems[index]) if not motor.skill_emblems[index].is_empty() else null
		if emblem != null and skill.icon != emblem:
			skill.icon = emblem
			skill.queue_redraw()
		var cooldown := motor.skill_cooldowns[index]
		var left := motor.skill_cooldowns_left[index]
		skill.show_state(1.0 if cooldown <= 0.0 else 1.0 - left / cooldown)
		if left > 0.0:
			skill.key_label.text = "%d秒" % ceili(left)


# The special move: its emblem, its gauge as the sweep, a pulse and a chime
# the moment it is full.
func _show_special(delta: float) -> void:
	var hero := area.hero
	var slot: ActionSlot = slots[&"special"]
	slot.visible = hero.special != null
	if not slot.visible:
		return
	var emblem := EmblemIcons.texture(hero.special.emblem)
	if emblem != null and slot.icon != emblem:
		slot.icon = emblem
	slot.pivot_offset = Vector2(slot.size.x * 0.5, ActionSlot.SIZE * 0.5)
	var full := hero.special_ready()
	# The gauge as the sweep and as a ring of its own round the slot.
	slot.show_state(hero.special_share(), 0.0 if full else hero.special_share())
	if full and not _special_full:
		_special_time = 0.0
		GameAudio.play(self, &"charge", -16.0)
	_special_full = full
	if full:
		_special_time += delta
		slot.scale = Vector2.ONE * (1.0 + SPECIAL_SWELL * (0.5 + 0.5 * sin(_special_time * TAU * SPECIAL_PULSE)))
	else:
		slot.scale = Vector2.ONE
		slot.key_label.text = "%d%%" % floori(hero.special_share() * 100.0)


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
