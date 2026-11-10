class_name ActionHud
extends CanvasLayer

# The HUD of the real-time fight, laid out as action roguelites and
# survivor games commonly do, the ground round the hero kept clear:
# - along the top edge, the run's experience, its level at the right end;
# - at the top centre, the goal (the area, what to do, a bar of how far it
#   has come); the boss's gauge takes its place once the boss is in;
# - at the top left, the boons taken as their emblems with their ranks;
# - at the top right, the echo earned in the run (gold, the larger) over the
#   foes felled in the whole run (left out while the area's goal itself counts the foes, so
#   one count is not shown twice);
# - at the bottom left, her health in a painted frame with a heart crest,
#   the boss gauge's counterpart (a trail shows what a blow took);
# - at the bottom right, her actions as round slots (attack, dash, skills,
#   special move) with their keys, a sweep while they come back, pips for
#   the dashes, a ring while she charges, the seconds a skill has left over
#   its emblem, and the special's gauge as its sweep and a percentage over
#   its emblem (it pulses gold once full);
# - the rest of the controls along the bottom as the key guide the other
#   screens use (keys named on a keyboard, painted caps on a gamepad), at
#   the centre, and moved left as far as it takes to keep clear of the
#   action slots once there are enough of them to reach under it; and a
#   banner in the middle
#   for the area's name, its clearing, her fall and the boss's rage;
# - at 30% health or less, the screen's edges pulse red, deeper and faster
#   the less is left;
# - toward a boss, an elite, or the last few foes of an arena's wave that
#   stand outside the view, a small arrow at the edge of the ground kept
#   clear, so what is left to fell (and what may shoot from out of sight)
#   can be found.
# A faint shade darkens the top and bottom edges, under all of it, so the
# words read the same on a bright, busy floor as on a dark one.
# It only reads the area (and its `run`, `director`, `waves` and `boss_foe`,
# when it has them). A trial area (the sandbox) adds its keys and counters.

# The controls under the fight: [keys, gamepad buttons, what they do].
const CONTROLS := [
	["WASD", "左スティック", "移動"],
	["左クリック長押し", "X長押し", "溜め攻撃"],
	["Esc", "START", "メニュー"],
]
# The action slots' emblems, and their keys on a keyboard and a gamepad.
const SLOTS := [
	[&"strike", "weapon_sword", "左クリック", "X"],
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
# The key guide keeps this far from the action slots and from the health.
const GUIDE_GAP := 24.0
# The health fill's length, inside the frame's channel.
const BAR_WIDTH := 360.0
# The health bar's frame (built by tools/build_gauges.py) and, measured by
# `python tools/build_gauges.py hero --measure`, its caps and channel; update
# them when the picture changes.
const HP_FRAME := preload("res://art/ui/hero_gauge.png")
const HP_CAP_LEFT := 45
const HP_CAP_RIGHT := 17
const HP_CHANNEL_TOP := 17
const HP_CHANNEL_BOTTOM := 32
const GOAL_WIDTH := 380.0
const EMBLEM_SIZE := 40.0
const BOONS_WIDTH := 360.0
# How far the edges' shade reaches in from the top and from the bottom.
const TOP_SHADE := 120.0
const BOTTOM_SHADE := 150.0
# The share of health from which the edges pulse, and their pulse rates (per
# second) at that share and at the last of it.
const DANGER_SHARE := 0.3
const DANGER_RATE := Vector2(1.2, 2.6)
# The arrows toward foes out of view stand on a frame this far in from the
# screen's sides, top and bottom (clear of the HUD's rows); an arena's
# crowd is pointed at once this few are left in its wave.
const POINTER_INSET := Vector2(56.0, 0.0)
const POINTER_TOP := 132.0
const POINTER_BOTTOM := 156.0
const POINTER_FEW := 5
const POINTER_SIZE := 11.0

var area: CombatArea
var hp_gauge: FramedGauge
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
# The tally's rows: the echo (its caption and value) and the foes felled.
var echo_row: HBoxContainer
var kills_row: HBoxContainer
var trial_label: Label
var slots: Dictionary[StringName, ActionSlot] = {}
# The skill slot's key (the seconds left while it comes back).
var skill_label: Label
var guide: KeyGuide
# The health (bottom left) and the action slots (bottom right), which the
# guide stands between.
var vitals: VBoxContainer
var actions: HBoxContainer
# A trial area's own keys, over the guide.
var trial_keys: Label
var banner: PanelContainer
var message: Label
var boss_gauge: BossGauge
var danger: TextureRect
# The arrows toward foes out of view, drawn every frame.
var pointers: Control
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
	_build_shade(root)
	pointers = Control.new()
	pointers.set_anchors_preset(Control.PRESET_FULL_RECT)
	pointers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointers.draw.connect(_draw_pointers)
	root.add_child(pointers)
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


# Dark at the very edge, clear by the reach in; one band at the top, one at
# the bottom.
func _build_shade(root: Control) -> void:
	var dark := root.get_theme_color(&"shade", &"HudEdge")
	for top: bool in [true, false]:
		var fade := Gradient.new()
		fade.set_color(0, Color(dark, dark.a if top else 0.0))
		fade.set_color(1, Color(dark, 0.0 if top else dark.a))
		var texture := GradientTexture2D.new()
		texture.gradient = fade
		texture.fill_from = Vector2(0.5, 0.0)
		texture.fill_to = Vector2(0.5, 1.0)
		texture.width = 4
		texture.height = 64
		var band := TextureRect.new()
		band.texture = texture
		band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		band.stretch_mode = TextureRect.STRETCH_SCALE
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			band.offset_bottom = TOP_SHADE
		else:
			band.offset_top = -BOTTOM_SHADE
		root.add_child(band)


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
	echo_row = _tally_row(tally, "残響")
	echo_label = _label(echo_row, &"HudGoldValue")
	kills_row = _tally_row(tally, "総撃破")
	kills_label = _label(kills_row, &"HudTallyValue")
	trial_label = _label(tally, &"HudSmall")
	trial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_bottom(root: Control) -> void:
	vitals = VBoxContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vitals.offset_left = EDGE
	vitals.offset_bottom = -EDGE
	root.add_child(vitals)
	# The numbers start over the channel, past the crest, as the boss's name
	# does over its gauge.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(row)
	var indent := Control.new()
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indent.custom_minimum_size.x = HP_CAP_LEFT - row.get_theme_constant(&"separation")
	row.add_child(indent)
	var caption := _label(row, &"HpCaption")
	caption.text = "HP"
	hp_value = _label(row, &"HudValue")
	# The bar over its trail in the frame, with quarter notches on top.
	hp_gauge = FramedGauge.new(HP_FRAME, HP_CAP_LEFT, HP_CAP_RIGHT, HP_CHANNEL_TOP, HP_CHANNEL_BOTTOM, &"HpCurrent", &"HpTrail")
	hp_gauge.custom_minimum_size.x = HP_CAP_LEFT + BAR_WIDTH + HP_CAP_RIGHT
	vitals.add_child(hp_gauge)
	hp_trail = hp_gauge.trail
	hp_bar = hp_gauge.bar
	actions = HBoxContainer.new()
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
	# In the tree before its hints, so they take their style from the theme.
	guide = KeyGuide.new()
	root.add_child(guide)
	for entry: Array in CONTROLS:
		guide.add_hint(entry[0], entry[1], entry[2])
	guide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	guide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	guide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	guide.offset_bottom = -EDGE + 6.0
	trial_keys = _label(root, &"HudCaption")
	trial_keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	trial_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trial_keys.grow_horizontal = Control.GROW_DIRECTION_BOTH
	trial_keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	trial_keys.offset_bottom = -EDGE - 40.0
	trial_keys.hide()


# A row of the tally, right-aligned: its caption, then (added by the caller)
# its value.
func _tally_row(tally: VBoxContainer, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"HudTallyRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally.add_child(row)
	var label := _label(row, &"HudCaption")
	label.text = caption
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


func _label(parent: Control, role: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# An area may add keys of its own over the controls (trial_keys()).
func watch(combat_area: CombatArea) -> void:
	area = combat_area
	trial_keys.visible = area.has_method(&"trial_keys")
	if trial_keys.visible:
		trial_keys.text = area.trial_keys()


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
	_place_guide()
	pointers.queue_redraw()
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


# The foes worth pointing at when out of view: the boss, the elites, and an
# arena's crowd once only a few of its wave are left.
func pointer_targets() -> Array[Foe]:
	var targets: Array[Foe] = []
	var waves: WaveRunner = area.get(&"waves")
	var few := waves != null and waves.wave >= 0 and not waves.done() and waves.remaining() <= POINTER_FEW
	for foe in area.foes:
		if not foe.dying and (foe.data.boss or foe.data.elite or few):
			targets.append(foe)
	return targets


# Where on the screen the arrow toward a point of the world stands: on the
# frame kept clear, along the line from the screen's middle; INF while the
# point is in view.
func pointer_spot(world_at: Vector2) -> Vector2:
	var view := area.view_rect()
	if view.has_point(world_at):
		return Vector2.INF
	var screen := pointers.size
	var at := (world_at - view.position) / view.size * screen
	var middle := screen * 0.5
	var toward := (at - middle).normalized()
	var frame := Rect2(POINTER_INSET.x, POINTER_TOP, screen.x - POINTER_INSET.x * 2.0, screen.y - POINTER_TOP - POINTER_BOTTOM)
	var reach := INF
	if not is_zero_approx(toward.x):
		reach = minf(reach, ((frame.end.x if toward.x > 0.0 else frame.position.x) - middle.x) / toward.x)
	if not is_zero_approx(toward.y):
		reach = minf(reach, ((frame.end.y if toward.y > 0.0 else frame.position.y) - middle.y) / toward.y)
	return middle + toward * reach


func _draw_pointers() -> void:
	if area == null or area.hero == null or not area.hero.health.alive():
		return
	var threat := pointers.get_theme_color(&"font_color", &"HpCaption")
	var plain := pointers.get_theme_color(&"font_color", &"HudValue")
	var rim := pointers.get_theme_color(&"font_outline_color", &"HudValue")
	var middle := pointers.size * 0.5
	for foe in pointer_targets():
		var spot := pointer_spot(foe.global_position)
		if spot == Vector2.INF:
			continue
		var toward := (spot - middle).normalized()
		var across := toward.orthogonal()
		var size := POINTER_SIZE * (1.5 if foe.data.boss else (1.2 if foe.data.elite else 1.0))
		# An arrowhead notched at the back: a plain triangle this small reads
		# as pointing any of three ways.
		var arrow := PackedVector2Array([spot + toward * size, spot - toward * size * 0.9 + across * size * 0.75, spot - toward * size * 0.3, spot - toward * size * 0.9 - across * size * 0.75])
		pointers.draw_colored_polygon(arrow, threat if foe.data.boss or foe.data.elite else plain)
		pointers.draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]), rim, 1.5, true)


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
		return waves.progress()
	if data.kill_target > 0:
		return clampf(float(area.kills) / data.kill_target, 0.0, 1.0)
	if data.survive_time > 0.0:
		return clampf(float(area.get(&"elapsed")) / data.survive_time, 0.0, 1.0)
	return -1.0


# The run's echo and the foes felled; a trial area's counters under them.
# While the area's goal counts the foes, the goal alone shows them.
func _show_tally() -> void:
	var run: RunState = area.get(&"run")
	kills_label.text = str((run.kills if run != null else 0) + area.kills)
	var data: AreaData = area.get(&"data")
	kills_row.visible = not (goal.visible and data != null and data.kill_target > 0)
	echo_row.visible = run != null
	if run != null:
		echo_label.text = UIFormat.amount(run.echo)
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
	# The attack's slot shows the weapon held.
	var weapon := EmblemIcons.texture(motor.moveset.emblem)
	if weapon != null and slots[&"strike"].icon != weapon:
		slots[&"strike"].icon = weapon
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
		skill.note_label.text = "%d" % ceili(left) if left > 0.0 else ""


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
	slot.note_label.text = "" if full else "%d%%" % floori(hero.special_share() * 100.0)


# The key guide at the bottom centre, as wide as its hints; moved left when
# the action slots would reach under it (two skills and the special make
# five), but never onto the health.
func _place_guide() -> void:
	var half := guide.get_combined_minimum_size().x * 0.5
	var middle := guide.get_parent_area_size().x * 0.5
	var slots_left := actions.position.x + actions.size.x - actions.get_combined_minimum_size().x
	var shift := minf(0.0, slots_left - GUIDE_GAP - (middle + half))
	shift = maxf(shift, minf(0.0, vitals.position.x + vitals.size.x + GUIDE_GAP - (middle - half)))
	guide.offset_left = shift - half
	guide.offset_right = shift + half


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
