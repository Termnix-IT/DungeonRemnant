class_name RouteMapView
extends CanvasLayer

# The run's route between areas, as roguelites commonly show it: a node map,
# here a whole-screen map of the chapter's ground that scrolls sideways, so
# the way reads as a journey rather than a diagram on one board. The layers
# stand in columns from left to right, the boss last; the map grows with the
# chapter's layers and scrolls past the screen's edges.
# - Each area is a RouteNode: what clearing it gives and its difficulty
#   (stars) only. The rest (its name, kind, time, reward, goal, foes) is on
#   a card that comes up beside the node pointed at or focused, on its left,
#   the side already passed, so the other choices and the ways on stay in
#   sight.
# - The ways already walked and the ways open now are roads, painted in the
#   chapter's own ground (ROADS); the open ones glow gold and draw out from
#   her as the map opens. The ways further on are the same road, narrower
#   and see-through: plainer while still within her reach, fainter once her
#   picks have cut them off (drawn under the others, so crossings stay
#   readable).
# - She herself stands on the road where she is, small, idling; a pick she
#   goes ahead with walks her along the road to it.
# - The run so far sits in the corners as the fight's HUD has it: the
#   chapter and her boons at the top left, what the last area gave at the
#   top centre, her level, echo and curses at the top right, her health at
#   the bottom left, the keys at the bottom.
# The view follows her: at a chapter's start it shows the boss first and
# pans back to her; the wheel or the right stick looks along the map, and
# focusing a node off the screen brings it in. Only the nodes the last
# area's paths lead to can be chosen (the whole first layer at the start).
# Mouse: pointing reads a node, a click on an open one picks it. Keys and
# pad: the arrows move between the open nodes, Enter (A) picks; 1-3 pick one
# at once. A pick asks first, then she walks there and it is entered.

signal chosen(waypoint: RouteMap.Waypoint)

# What a way between two areas is to her now.
enum Way { WALKED, OPEN, AHEAD, SHUT }

const FOCUS_DELAY := 0.25
# The map's ground: each chapter's battle floor (AreaGround's atlases), laid
# at its painted size and darkened. Past the map's ends, plain dark.
const GROUNDS := {&"ash_corridor": 0, &"gale_woods": 4, &"amethyst_mausoleum": 5, &"abyss_of_echoes": 6}
const GROUND_TINT := Color(0.38, 0.38, 0.4)
const BEYOND := Color(0.02, 0.025, 0.035)
# Each chapter's road (built by tools/build_route_roads.py), repeated along
# a path; a chapter without one draws its roads in plain gold.
const ROADS := {
	&"ash_corridor": "res://art/ui/route/road_ash_corridor.png",
	&"gale_woods": "res://art/ui/route/road_gale_woods.png",
	&"amethyst_mausoleum": "res://art/ui/route/road_amethyst_mausoleum.png",
	&"abyss_of_echoes": "res://art/ui/route/road_abyss_of_echoes.png",
}
const ROAD_WIDTH := 36.0
const ROAD_PLAIN := Color(0.84, 0.72, 0.48, 0.9)
const GLOW_WIDTH := 76.0
const PATH_GLOW := Color(1.0, 0.82, 0.48, 0.42)
# The ways not walked are the same road, narrower and see-through: plainer
# while still within her reach, fainter once her picks have cut them off.
const FAINT_WIDTH := 28.0
const AHEAD_ALPHA := 0.36
const SHUT_ALPHA := 0.13
# A road's middle: this share of its width (the rim is the rest), its cut
# edges fading over this share of the band.
const MIDDLE_SHARE := 0.64
const MIDDLE_FADE := 0.22
# Points along each path's curve.
const CURVE_STEPS := 24
# Where things stand: her start, the gap between layers (room for a card
# between her and the next layer), the room past the boss, the gap between a
# layer's stages, and how far the rows' middle (the stages' ground) sits
# above the screen's (below it when negative: the figures stand above).
const START_X := 190.0
const COLUMN_GAP := 600.0
const END_MARGIN := 300.0
const NODE_GAP := 226.0
const MAP_RISE := -24.0
# The start's stage is this share of an area's, its signpost right of her.
const START_SCALE := 0.8
const SIGN_HEIGHT := 112.0
const SIGN_PLACE := Vector2(34.0, 4.0)
# The view keeps her this share of the width in from the left. At a
# chapter's start it rests on the boss (PAN_HOLD), then pans to her.
const FOLLOW_SHARE := 0.28
const PAN_HOLD := 0.6
const PAN_TIME := 1.3
const REVEAL_TIME := 0.3
# Looking along the map: px per wheel notch, and px a second at the right
# stick's full tilt.
const LOOK_STEP := 150.0
const LOOK_SPEED := 1100.0
const STICK_DEADZONE := 0.25
# The node's card.
const CARD_WIDTH := 340.0
const CARD_GAP := 22.0
const FOE_SIZE := 44.0
# What the card says of a node she cannot pick now.
const AHEAD_NOTE := "この先にある"
const SHUT_NOTE := "この道からは行けない"
const PASSED_NOTE := "通り過ぎた"
# What the card says of the boss before her way reaches it.
const VEILED_NAME := "？？？"
const VEILED_NOTE := "この章の最奥で、何かが待ち構えている"
# Her figure: the fight's rig, small; where she stands from a node's middle
# (on the road coming in, left of it).
const MIO_RIG := preload("res://art/characters/mio_rig/mio_rig.tscn")
const HERO_HEIGHT := 100.0
const HERO_OFFSET := Vector2(-44.0, 2.0)
const IDLE_FACING := Vector2i(1, 1)
# The boss coming out once her way reaches it: the view's move to it and
# back, its lightening, the hold on it, the title's fade, the flush, the
# shake, and how far above the bottom the title stands.
const REVEAL_PAN := 0.7
const COMING_OUT := 0.9
const REVEAL_HOLD := 1.0
const REVEAL_FADE := 0.3
const FLUSH := Color(0.7, 0.05, 0.03, 0.26)
const SHAKE := 7.0
const SHAKE_STEPS := 8
const SHAKE_TIME := 0.45
const BOSS_TITLE_RISE := 150.0
# Opening, the open roads draw out from her (DRAW_TIME); a pick she goes
# ahead with walks her there (TRAVEL_TIME) before it is entered.
const DRAW_TIME := 0.45
const TRAVEL_TIME := 1.0
const ARRIVE_TIME := 0.14
# The HUD: its inset from the screen's edges, the boons' emblems, how far
# the edges' shade reaches in, and the space kept clear of it for the card.
const EDGE := 32.0
const EMBLEM_SIZE := 34.0
const BOONS_WIDTH := 380.0
const HP_BAR_WIDTH := 300.0
const TOP_SHADE := 150.0
const BOTTOM_SHADE := 150.0
const TOP_CLEAR := 120.0
const BOTTOM_CLEAR := 110.0

var route: RouteMap
# The layer to choose from now.
var route_layer := 0
var current: Array = []
var buttons: Array[Button] = []
var nodes_by_point: Dictionary = {}
# The nodes still within her reach: the open ones and every one past them.
var reachable: Dictionary = {}
var selected: RouteMap.Waypoint
# The encyclopedia's record, for which foes the card shows as met (all of
# them without one).
var meta: MetaProgress
var _run: RunState
var _frame: Control
var _world: Control
var _ground: Control
var _roads: Node2D
var _start_stage: Control
var _hero_holder: Node2D
var _title: Label
var _boons: HFlowContainer
var _note: Label
var _level: Label
var _echo: Label
# The curses she carries, in red under the echo.
var _curses: Label
var _hp: Label
var _hp_gauge: FramedGauge
var _guide: KeyGuide
var _card: PanelContainer
var _detail_name: Label
var _detail_kind: Label
var _detail_reward: Label
var _detail_goal: Label
var _detail_foe_row: HBoxContainer
var _detail_foes: Label
var _detail_state: Label
# The node the card tells of: the one pointed at, else the selected one.
var told: RouteMap.Waypoint
var _pointed: RouteMap.Waypoint
var hero: DirectionalRig
# How far the open roads have drawn out (0 to 1), and whether she is
# walking to a pick (nothing else is taken meanwhile).
var draw_progress := 1.0
var traveling := false
# The open roads and their glows, with the ends they join.
var _open_roads: Array[Dictionary] = []
# Each chapter's road's middle band, cut once.
static var _middles: Dictionary = {}
# How far the map is scrolled (px from its left end), and the route whose
# opening pan has been shown.
var scroll := 0.0:
	set(value):
		scroll = clampf(value, 0.0, scroll_limit())
		if _world != null:
			_world.position.x = _world_left() - roundf(scroll)
var panning := false
# The route whose boss has come out of the dark.
var _revealed_route: RouteMap
# The boss's coming out: the red flush over the map and its title.
var _flush: ColorRect
var _boss_title: VBoxContainer
var _boss_epithet: Label
var _boss_name: Label
var _panned_route: RouteMap
var _camera: Tween
var _opening: Tween
# The question asked before a pick is gone ahead with, and the area it asks about.
var prompt: ChoicePrompt
var asked: RouteMap.Waypoint


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var beyond := ColorRect.new()
	beyond.color = BEYOND
	beyond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beyond.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(beyond)
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_world)
	_ground = Control.new()
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.draw.connect(_draw_ground)
	_world.add_child(_ground)
	_roads = Node2D.new()
	_world.add_child(_roads)
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_build_shade(hud)
	_build_top(hud)
	_build_bottom(hud)
	_build_card(hud)
	_build_boss_title(hud)
	hide()


# Dark at the very edge, clear by the reach in, so the HUD's words read
# over the ground.
func _build_shade(hud: Control) -> void:
	var dark := hud.get_theme_color(&"shade", &"HudEdge")
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
		hud.add_child(band)


# The chapter and her boons at the top left, what the last area gave at the
# top centre, her level, echo and curses at the top right.
func _build_top(hud: Control) -> void:
	var chapter := VBoxContainer.new()
	chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter.position = Vector2(EDGE, 22.0)
	hud.add_child(chapter)
	_title = _label(chapter, &"TitleLabel")
	_boons = HFlowContainer.new()
	_boons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boons.custom_minimum_size.x = BOONS_WIDTH
	chapter.add_child(_boons)
	_note = _label(hud, &"HudObjective")
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note.offset_top = 34.0
	var tally := VBoxContainer.new()
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tally.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tally.offset_right = -EDGE
	tally.offset_top = 26.0
	hud.add_child(tally)
	_level = _label(_tally_row(tally, "Lv"), &"HudValue")
	_echo = _label(_tally_row(tally, "残響"), &"HudGoldValue")
	_curses = _label(tally, &"CurseLabel")
	_curses.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_curses.hide()


# Her health at the bottom left in the fight's painted frame; the keys at
# the bottom centre.
func _build_bottom(hud: Control) -> void:
	var vitals := VBoxContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vitals.offset_left = EDGE
	vitals.offset_bottom = -EDGE
	hud.add_child(vitals)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(row)
	var indent := Control.new()
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indent.custom_minimum_size.x = ActionHud.HP_CAP_LEFT - row.get_theme_constant(&"separation")
	row.add_child(indent)
	_label(row, &"HpCaption").text = "HP"
	_hp = _label(row, &"HudValue")
	_hp_gauge = FramedGauge.new(ActionHud.HP_FRAME, ActionHud.HP_CAP_LEFT, ActionHud.HP_CAP_RIGHT,
		ActionHud.HP_CHANNEL_TOP, ActionHud.HP_CHANNEL_BOTTOM, &"HpCurrent", &"HpTrail")
	_hp_gauge.custom_minimum_size.x = ActionHud.HP_CAP_LEFT + HP_BAR_WIDTH + ActionHud.HP_CAP_RIGHT
	vitals.add_child(_hp_gauge)
	_guide = KeyGuide.new()
	hud.add_child(_guide)
	_guide.add_hint("←→↑↓・1〜3", "十字", "エリアを選ぶ")
	_guide.add_hint("Enter", "A", "進む")
	_guide.add_hint("ホイール", "右スティック", "地図を見渡す")
	_guide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_guide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_guide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_guide.offset_bottom = -EDGE + 6.0


# The boss's coming out: a red flush over the whole map, and its epithet and
# name in the lower third, as the fight's boss entrance sets them.
func _build_boss_title(hud: Control) -> void:
	_flush = ColorRect.new()
	_flush.color = Color(FLUSH, 0.0)
	_flush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flush.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_flush)
	hud.move_child(_flush, 0)
	_boss_title = VBoxContainer.new()
	_boss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_title.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_title.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_boss_title.offset_bottom = -BOSS_TITLE_RISE
	hud.add_child(_boss_title)
	_boss_epithet = _label(_boss_title, &"BossEpithet")
	_boss_name = _label(_boss_title, &"BossName")
	for label: Label in [_boss_epithet, _boss_name]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_title.hide()


# The card a node shows when pointed at or focused.
func _build_card(hud: Control) -> void:
	_card = PanelContainer.new()
	_card.theme_type_variation = &"QuietWindow"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size.x = CARD_WIDTH
	hud.add_child(_card)
	var lines := VBoxContainer.new()
	lines.theme_type_variation = &"DetailStack"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(lines)
	_detail_name = _label(lines, &"HeadingLabel")
	_detail_kind = _label(lines, &"MutedLabel")
	HubUI.rule(lines)
	_detail_reward = _label(lines, &"GoldLabel")
	_detail_goal = _label(lines, &"BodyLabel")
	_detail_foe_row = HBoxContainer.new()
	_detail_foe_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(_detail_foe_row)
	_detail_foes = _label(lines, &"DescriptionLabel")
	_detail_state = _label(lines, &"MutedLabel")
	for label: Label in [_detail_goal, _detail_foes]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.hide()


func _label(parent: Control, role: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


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


# Shows the route at `at_layer` (the next to choose), with the run's state
# and a note (what the last area gave).
func present(route_map: RouteMap, at_layer: int, run: RunState, max_hp: int, note: String = "") -> void:
	route = route_map
	route_layer = at_layer
	_run = run
	_title.text = route.chapter.display_name if run.step == 0 else "%s　段階%d" % [route.chapter.display_name, run.step]
	var hp := run.hp if run.hp > 0 else max_hp
	_hp.text = "%d / %d" % [hp, max_hp]
	for bar: ProgressBar in [_hp_gauge.bar, _hp_gauge.trail]:
		bar.max_value = max_hp
		bar.value = hp
	_level.text = str(run.progression.level)
	_echo.text = UIFormat.amount(run.echo)
	_curses.text = "呪い：%s" % run.curse_names()
	_curses.visible = not run.curses.is_empty()
	_show_boons(run)
	_note.text = note
	_note.visible = not note.is_empty()
	traveling = false
	_pointed = null
	show()
	_lay_nodes()
	UIMotion.bind_buttons(_world)
	_open()
	_select(current[0] if not current.is_empty() else null)


# The map opens: at a chapter's start the view rests on the boss and pans
# back to her; then the open roads draw out from her and the first open node
# takes focus.
func _open() -> void:
	if _camera != null:
		_camera.kill()
	if _opening != null:
		_opening.kill()
	draw_progress = 0.0
	_draw_out(0.0)
	_opening = create_tween()
	if route != _panned_route and scroll_limit() > 0.0:
		_panned_route = route
		panning = true
		scroll = scroll_limit()
		_opening.tween_interval(PAN_HOLD)
		_opening.tween_property(self, "scroll", follow_scroll(), PAN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_opening.tween_callback(func():
			panning = false
			_tell(told))
	else:
		_panned_route = route
		scroll = follow_scroll()
	_opening.tween_method(_draw_out, 0.0, 1.0, DRAW_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var boss := waiting_boss()
	if boss != null:
		_reveal_boss(boss)
	_opening.tween_interval(FOCUS_DELAY)
	_opening.tween_callback(_focus_first)


# The boss's stage, while it is open now and still veiled.
func waiting_boss() -> RouteNode:
	for point: RouteMap.Waypoint in current:
		var node: RouteNode = nodes_by_point.get(point)
		if node != null and node.veiled:
			return node
	return null


# Her way reaches the boss: the view goes to it, it comes out of the dark
# with a red flush, a shake and a low toll, its epithet and name rise over
# it, and after a hold the view comes back to her. Once a run.
func _reveal_boss(boss: RouteNode) -> void:
	_revealed_route = route
	panning = true
	var middle := _center(boss.waypoint).x - _frame.size.x * 0.5
	_opening.tween_property(self, "scroll", clampf(middle, 0.0, scroll_limit()), REVEAL_PAN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_opening.tween_callback(func():
		boss.reveal(COMING_OUT)
		GameAudio.play(self, &"boss", -10.0)
		_boss_epithet.text = boss.waypoint.area.boss.epithet
		_boss_name.text = boss.waypoint.area.boss.display_name
		_boss_title.modulate.a = 0.0
		_boss_title.show()
		var show := create_tween().set_parallel()
		show.tween_property(_boss_title, "modulate:a", 1.0, COMING_OUT)
		show.tween_property(_flush, "color:a", FLUSH.a, COMING_OUT * 0.4)
		show.chain().tween_property(_flush, "color:a", 0.0, COMING_OUT)
		_shake())
	_opening.tween_interval(COMING_OUT + REVEAL_HOLD)
	_opening.tween_property(_boss_title, "modulate:a", 0.0, REVEAL_FADE)
	_opening.tween_property(self, "scroll", follow_scroll(), REVEAL_PAN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_opening.tween_callback(func():
		panning = false
		_boss_title.hide()
		_tell(told))


func _shake() -> void:
	var shake := create_tween()
	for step in SHAKE_STEPS:
		var reach := SHAKE * (1.0 - float(step) / SHAKE_STEPS)
		shake.tween_property(_world, "position:y", reach if step % 2 == 0 else -reach, SHAKE_TIME / SHAKE_STEPS)
	shake.tween_property(_world, "position:y", 0.0, SHAKE_TIME / SHAKE_STEPS)


# A key, the wheel or the stick during the opening pan, or the boss's
# coming out, cuts it short.
func _end_pan() -> void:
	if not panning:
		return
	panning = false
	if _opening != null:
		_opening.kill()
	for node: RouteNode in nodes_by_point.values():
		if node.waypoint.area.boss != null and current.has(node.waypoint):
			node.unveil()
	_boss_title.hide()
	_flush.color.a = 0.0
	_world.position.y = 0.0
	scroll = follow_scroll()
	_draw_out(1.0)
	_tell(told)
	_focus_first()


func _show_boons(run: RunState) -> void:
	for child in _boons.get_children():
		child.free()
	for boon in run.build.owned():
		var icon := TextureRect.new()
		icon.texture = EmblemIcons.texture(boon.emblem)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
		icon.tooltip_text = boon.display_name if boon.max_level == 1 else "%s %d" % [boon.display_name, run.build.rank(boon.id)]
		_boons.add_child(icon)


# Every layer's nodes, placed in columns along the map, the roads and dots
# between them, and her.
func _lay_nodes() -> void:
	for child in _world.get_children():
		if child is RouteNode:
			child.free()
	for child in _roads.get_children():
		child.free()
	if _hero_holder != null:
		_hero_holder.free()
	buttons.clear()
	nodes_by_point.clear()
	_open_roads.clear()
	var screen := _frame.size
	_world.size = Vector2(START_X + COLUMN_GAP * route.size() + END_MARGIN, screen.y)
	_ground.size = _world.size
	scroll = scroll
	_lay_start()
	var previous: RouteMap.Waypoint = _run.taken[route_layer - 1] if route_layer > 0 and route_layer - 1 < _run.taken.size() else null
	current = route.open_after(previous)
	reachable.clear()
	var frontier := current.duplicate()
	while not frontier.is_empty():
		var point: RouteMap.Waypoint = frontier.pop_back()
		if not reachable.has(point):
			reachable[point] = true
			frontier.append_array(point.next)
	for index in route.size():
		var taken_here: RouteMap.Waypoint = _run.taken[index] if index < _run.taken.size() else null
		var points := route.nodes(index)
		for row in points.size():
			var point: RouteMap.Waypoint = points[row]
			# Ahead and in reach, or dimmed: passed by, or cut off by her picks.
			var mark := RouteNode.Mark.AHEAD if reachable.has(point) else RouteNode.Mark.PASSED
			if current.has(point):
				mark = RouteNode.Mark.OPEN
			elif index < route_layer:
				mark = RouteNode.Mark.TAKEN if point == taken_here else RouteNode.Mark.PASSED
			var node := RouteNode.new()
			_world.add_child(node)
			node.setup(point, mark, RouteNode.plate_for(route.chapter.id), point.area.boss != null and (not current.has(point) or _revealed_route != route))
			node.position = _spot(index, row, points.size()) - node.ground()
			nodes_by_point[point] = node
			node.mouse_entered.connect(_point_at.bind(point))
			node.mouse_exited.connect(_point_at.bind(null))
			if mark == RouteNode.Mark.OPEN:
				node.pressed.connect(pick.bind(point))
				node.focus_entered.connect(_on_focused.bind(point))
				buttons.append(node)
			else:
				node.disabled = true
	# The open nodes are walked with the arrows, top to bottom and round.
	for row in buttons.size():
		var path := buttons[row].get_path_to(buttons[(row + 1) % buttons.size()])
		var back := buttons[row].get_path_to(buttons[(row - 1 + buttons.size()) % buttons.size()])
		buttons[row].focus_neighbor_bottom = path
		buttons[row].focus_neighbor_right = path
		buttons[row].focus_neighbor_top = back
		buttons[row].focus_neighbor_left = back
	_lay_roads()
	_ground.queue_redraw()
	# She stands, small, on the road where she is.
	_hero_holder = Node2D.new()
	_world.add_child(_hero_holder)
	hero = MIO_RIG.instantiate()
	hero.world_height = HERO_HEIGHT
	_hero_holder.add_child(hero)
	if _run.moveset != null and _run.moveset.art != null:
		WeaponMount.hold(hero, _run.moveset)
	hero.facing = IDLE_FACING
	hero.position = hero_spot()


# Every way between the areas in the chapter's road, in layers: the ways cut
# off, then those still within her reach (so the plainer lies over the
# fainter where they cross), then the open ways' glow, then the ways walked
# and the open ones. Within a layer every road is drawn whole first (its
# rim) and then once more by its middle only, so where roads meet their
# middles run into one surface and the rims stay on the outside, as at a
# fork in a real road. A see-through layer is drawn whole into one picture
# and then made faint, so two faint roads crossing are no plainer than one.
func _lay_roads() -> void:
	var walked := mini(route_layer, _run.taken.size())
	var shut: Array = []
	var ahead: Array = []
	for index in route.size() - 1:
		var taken_here: RouteMap.Waypoint = _run.taken[index] if index < walked else null
		var next: RouteMap.Waypoint = _run.taken[index + 1] if index + 1 < walked else null
		for from: RouteMap.Waypoint in route.nodes(index):
			for to: RouteMap.Waypoint in from.next:
				if from == taken_here and (to == next or index + 1 == route_layer):
					continue
				if index >= route_layer and reachable.has(from):
					ahead.append([_center(from), _center(to), Way.AHEAD])
				else:
					shut.append([_center(from), _center(to), Way.SHUT])
	var solid: Array = []
	if walked > 0:
		solid.append([_start(), _center(_run.taken[0]), Way.WALKED])
	for index in walked - 1:
		solid.append([_center(_run.taken[index]), _center(_run.taken[index + 1]), Way.WALKED])
	for to: RouteMap.Waypoint in current:
		solid.append([anchor(), _center(to), Way.OPEN])
	_lay_layer(shut, SHUT_ALPHA)
	_lay_layer(ahead, AHEAD_ALPHA)
	var glows := Node2D.new()
	glows.name = "Glows"
	_roads.add_child(glows)
	_lay_layer(solid, 1.0, glows)


# One layer of roads: each whole, then each by its middle. A faint layer is a
# CanvasGroup, drawn whole and then made see-through as one.
func _lay_layer(ways: Array, alpha: float, glows: Node2D = null) -> void:
	if ways.is_empty():
		return
	var layer: Node2D = CanvasGroup.new() if alpha < 1.0 else Node2D.new()
	layer.self_modulate.a = alpha
	_roads.add_child(layer)
	var lines: Array[Line2D] = []
	for way: Array in ways:
		lines.append(_road(layer, way[0], way[1], way[2], false))
	for index in ways.size():
		var way: Array = ways[index]
		var middle := _road(layer, way[0], way[1], way[2], true)
		if way[2] == Way.OPEN and glows != null:
			var glow := Line2D.new()
			glow.width = GLOW_WIDTH
			glow.texture = _glow_texture()
			glow.texture_mode = Line2D.LINE_TEXTURE_STRETCH
			glow.joint_mode = Line2D.LINE_JOINT_ROUND
			glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
			glow.end_cap_mode = Line2D.LINE_CAP_ROUND
			glow.points = middle.points
			glows.add_child(glow)
			_open_roads.append({"line": lines[index], "middle": middle, "glow": glow, "from": way[0], "to": way[1]})


# A road along the curve: whole (it carries its way as meta) or by its middle
# only, the same road narrower so its stones line up with the whole one's.
func _road(layer: Node2D, from: Vector2, to: Vector2, way: Way, middle: bool) -> Line2D:
	var line := Line2D.new()
	var width := FAINT_WIDTH if way == Way.AHEAD or way == Way.SHUT else ROAD_WIDTH
	line.width = width * MIDDLE_SHARE if middle else width
	if not middle:
		line.set_meta(&"way", way)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	var texture := middle_texture() if middle else road_texture()
	if texture != null:
		line.texture = texture
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	else:
		line.default_color = ROAD_PLAIN
	line.points = curve(from, to)
	layer.add_child(line)
	return line


# The whole roads, in the order drawn (bottom first), each carrying its way.
func road_lines() -> Array[Line2D]:
	var lines: Array[Line2D] = []
	for line in _roads.find_children("*", "Line2D", true, false):
		if line.has_meta(&"way"):
			lines.append(line)
	return lines


# The open road's glow: gold along its middle, fading out to both sides.
func _glow_texture() -> GradientTexture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color(PATH_GLOW, 0.0))
	fade.set_color(1, Color(PATH_GLOW, 0.0))
	fade.add_point(0.5, PATH_GLOW)
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 32
	return texture


# The chapter's road, or null when it has none.
func road_texture() -> Texture2D:
	return road_for(route.chapter.id)


static func road_for(chapter_id: StringName) -> Texture2D:
	var path: String = ROADS.get(chapter_id, "")
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


# The middle band of the chapter's road: its rim cut away and the cut edges
# fading out, so a middle laid over another road's rim shows no seam.
func middle_texture() -> Texture2D:
	return middle_of(road_texture())


static func middle_of(road: Texture2D) -> Texture2D:
	if road == null:
		return null
	if _middles.has(road.resource_path):
		return _middles[road.resource_path]
	var image := road.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var high := roundi(image.get_height() * MIDDLE_SHARE)
	var top := (image.get_height() - high) / 2
	var band := image.get_region(Rect2i(0, top, image.get_width(), high))
	var fade := high * MIDDLE_FADE
	for y in high:
		var keep := clampf(minf(y + 0.5, high - y - 0.5) / fade, 0.0, 1.0)
		if keep >= 1.0:
			continue
		for x in band.get_width():
			var color := band.get_pixel(x, y)
			color.a *= keep
			band.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(band)
	_middles[road.resource_path] = texture
	return texture


func _draw_out(value: float) -> void:
	draw_progress = value
	for entry in _open_roads:
		var points := curve(entry.from, entry.to, value)
		for part: Line2D in [entry.line, entry.middle, entry.glow]:
			part.points = points
			part.visible = value > 0.0


# Points along the gentle S from one place to another: it leaves and arrives
# level, as a road between two columns would; `upto` stops it part way.
func curve(from: Vector2, to: Vector2, upto: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in CURVE_STEPS + 1:
		points.append(along(from, to, upto * step / CURVE_STEPS))
	return points


func along(from: Vector2, to: Vector2, t: float) -> Vector2:
	var bend := Vector2((to.x - from.x) * 0.5, 0.0)
	return from.bezier_interpolate(from + bend, to - bend, to, t)


# The chapter's floor, tile by tile, darkened.
func _draw_ground() -> void:
	if route == null:
		return
	var atlas: Texture2D = AreaGround.ATLASES[GROUNDS.get(route.chapter.id, 0)]
	var cell := float(AreaGround.PAINTED_CELL)
	for y in ceili(_ground.size.y / cell):
		for x in ceili(_ground.size.x / cell):
			var index := AreaGround.FLOOR_START + posmod(y, AreaGround.FLOOR_PERIOD) * AreaGround.FLOOR_PERIOD + posmod(x, AreaGround.FLOOR_PERIOD)
			var source := Rect2(Vector2(index % AreaGround.COLUMNS, index / AreaGround.COLUMNS) * cell, Vector2.ONE * cell)
			_ground.draw_texture_rect_region(atlas, Rect2(Vector2(x, y) * cell, Vector2.ONE * cell), source, GROUND_TINT)


# Where a layer's row sits on the map.
func _spot(index: int, row: int, count: int) -> Vector2:
	return Vector2(START_X + COLUMN_GAP * (index + 1), _middle() + (row - (count - 1) * 0.5) * NODE_GAP)


func _middle() -> float:
	return _world.size.y * 0.5 - MAP_RISE


# Where the run set out from, left of the first layer.
func _start() -> Vector2:
	return Vector2(START_X, _middle())


func _center(point: RouteMap.Waypoint) -> Vector2:
	var node: RouteNode = nodes_by_point[point]
	return node.position + node.ground()


# Where the run set out from: a smaller stage of the chapter's ground with a
# signpost, where she stands before the first pick.
func _lay_start() -> void:
	if _start_stage != null:
		_start_stage.free()
	_start_stage = Control.new()
	_start_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_start_stage)
	var width := RouteNode.PLATE_WIDTH * START_SCALE
	var plate := RouteNode.plate_for(route.chapter.id)
	var high := RouteNode.plate_height(plate, width)
	_start_stage.position = _start() - Vector2(width * 0.5, high * RouteNode.PLATE_TOP)
	_start_stage.size = Vector2(width, high)
	_start_stage.draw.connect(func():
		if plate != null:
			_start_stage.draw_texture_rect(plate, Rect2(Vector2.ZERO, _start_stage.size), false))
	var sign := RouteNode.prop_for(&"sign")
	if sign != null:
		var post := Sprite2D.new()
		post.texture = sign
		post.centered = false
		post.scale = Vector2.ONE * SIGN_HEIGHT / sign.get_height()
		post.offset = Vector2(-sign.get_width() * 0.5, -sign.get_height())
		post.position = Vector2(width * 0.5, high * RouteNode.PLATE_TOP) + SIGN_PLACE
		_start_stage.add_child(post)


# Where the open roads leave from: the area last taken, or the start.
func anchor() -> Vector2:
	if route_layer > 0 and route_layer - 1 < _run.taken.size():
		return _center(_run.taken[route_layer - 1])
	return _start()


# Where she stands before this layer's pick.
func hero_spot() -> Vector2:
	return anchor() + HERO_OFFSET


func scroll_limit() -> float:
	if _world == null or _frame == null:
		return 0.0
	return maxf(0.0, _world.size.x - _frame.size.x)


# A map narrower than the screen sits in its middle.
func _world_left() -> float:
	return maxf(0.0, (_frame.size.x - _world.size.x) * 0.5)


# The scroll that keeps her FOLLOW_SHARE of the width in from the left.
func follow_scroll() -> float:
	var spot := hero.position.x if hero != null else anchor().x
	return clampf(spot - _frame.size.x * FOLLOW_SHARE, 0.0, scroll_limit())


func _move_view(to: float, time: float) -> void:
	if _camera != null:
		_camera.kill()
	_camera = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_camera.tween_property(self, "scroll", clampf(to, 0.0, scroll_limit()), time)


# Looking along the map by hand.
func look(by: float) -> void:
	_end_pan()
	if _camera != null:
		_camera.kill()
	scroll += by


# A node focused off the screen (or with no room for its card on its left)
# is brought in.
func _reveal(point: RouteMap.Waypoint) -> void:
	if panning or not nodes_by_point.has(point):
		return
	var x := _center(point).x - scroll
	var left := CARD_WIDTH + CARD_GAP + RouteNode.PLATE_WIDTH
	var right := _frame.size.x - RouteNode.PLATE_WIDTH
	if x < left:
		_move_view(scroll - (left - x), REVEAL_TIME)
	elif x > right:
		_move_view(scroll + (x - right), REVEAL_TIME)


func _select(point: RouteMap.Waypoint) -> void:
	selected = point
	for node: RouteNode in nodes_by_point.values():
		node.selected = node.waypoint == point
	_tell(_pointed if _pointed != null else point)


func _on_focused(point: RouteMap.Waypoint) -> void:
	_select(point)
	_reveal(point)


func _point_at(point: RouteMap.Waypoint) -> void:
	_pointed = point
	_tell(point if point != null else selected)


# The card tells of a node: what it is, what it gives, its goal and foes,
# and, for one she cannot pick now, why.
func _tell(point: RouteMap.Waypoint) -> void:
	told = point
	if point == null:
		_card.hide()
		return
	var area := point.area
	var node: RouteNode = nodes_by_point.get(point)
	_detail_name.text = area.display_name
	for child in _detail_foe_row.get_children():
		child.free()
	if node != null and node.veiled:
		# The boss still in the dark: only that something waits there.
		_detail_name.text = VEILED_NAME
		_detail_kind.text = area.kind_name()
		_detail_reward.text = ""
		_detail_goal.text = VEILED_NOTE
		_detail_foes.text = ""
	elif area.is_event():
		_detail_kind.text = "イベント　戦闘なし"
		_detail_reward.text = area.condition
		_detail_goal.text = area.foe_summary
		_detail_foes.text = ""
	else:
		_detail_kind.text = "%s　%s　目安 %d分%02d秒" % [area.kind_name(), area.stars(), area.expected_time / 60, area.expected_time % 60]
		_detail_reward.text = "報酬：%s" % AreaData.reward_name(point.reward)
		_detail_goal.text = area.condition
		_detail_foes.text = area.foe_summary
		for foe in Chapters.area_foes(area):
			var met := meta == null or meta.has_met(foe.id)
			var picture := TextureRect.new()
			picture.texture = HubCodex.tile_picture(foe.visual_id, met, foe.tint)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = Vector2.ONE * FOE_SIZE
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_detail_foe_row.add_child(picture)
	_detail_reward.visible = not _detail_reward.text.is_empty()
	_detail_foes.visible = not _detail_foes.text.is_empty()
	_detail_foe_row.visible = _detail_foe_row.get_child_count() > 0
	var state := ""
	if node != null and node.mark != RouteNode.Mark.OPEN:
		state = {RouteNode.Mark.AHEAD: AHEAD_NOTE, RouteNode.Mark.TAKEN: PASSED_NOTE}.get(node.mark, SHUT_NOTE if point.layer >= route_layer else PASSED_NOTE)
	_detail_state.text = state
	_detail_state.visible = not state.is_empty()
	_card.reset_size()
	_card.visible = visible and not traveling and not panning
	_place_card()


# Beside the node, on its left (the side already passed); on its right when
# there is no room, and within the screen, clear of the HUD's top and bottom.
func _place_card() -> void:
	var node: RouteNode = nodes_by_point.get(told)
	if node == null:
		return
	var rect := node.get_global_rect()
	var screen := _frame.size
	var width := _card.size.x
	var x := rect.position.x - CARD_GAP - width
	if x < EDGE:
		x = rect.end.x + CARD_GAP
	x = clampf(x, EDGE, screen.x - EDGE - width)
	var y := clampf(rect.get_center().y - _card.size.y * 0.5, TOP_CLEAR, maxf(TOP_CLEAR, screen.y - BOTTOM_CLEAR - _card.size.y))
	_card.position = Vector2(x, y)


func _process(delta: float) -> void:
	if not visible:
		return
	if traveling and hero != null:
		scroll = lerpf(scroll, follow_scroll(), minf(1.0, delta * 6.0))
	if not traveling and not (prompt != null and prompt.visible):
		var tilt := 0.0
		for device in Input.get_connected_joypads():
			tilt += Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
		if absf(tilt) > STICK_DEADZONE:
			look(tilt * LOOK_SPEED * delta)
	if _card.visible:
		_card.reset_size()
		_place_card()


func _input(event: InputEvent) -> void:
	if not visible or traveling or (prompt != null and prompt.visible):
		return
	if event is InputEventMouseButton and event.pressed:
		var notch: float = {MOUSE_BUTTON_WHEEL_UP: -1.0, MOUSE_BUTTON_WHEEL_LEFT: -1.0, MOUSE_BUTTON_WHEEL_DOWN: 1.0, MOUSE_BUTTON_WHEEL_RIGHT: 1.0}.get(event.button_index, 0.0)
		if notch != 0.0:
			look(notch * LOOK_STEP)
			get_viewport().set_input_as_handled()


func _focus_first() -> void:
	if visible and not traveling and not buttons.is_empty():
		buttons[current.find(selected) if current.has(selected) else 0].grab_focus()


# A pick from the player: first the question whether to go there.
func pick(waypoint: RouteMap.Waypoint) -> void:
	if not visible or traveling or waypoint == null or not current.has(waypoint) or (prompt != null and prompt.visible):
		return
	_end_pan()
	if prompt == null:
		prompt = ChoicePrompt.new()
		add_child(prompt)
		prompt.confirmed.connect(_on_go)
		prompt.canceled.connect(_on_stay)
	asked = waypoint
	_select(waypoint)
	_card.hide()
	var area := waypoint.area
	if area.is_event():
		prompt.ask(area.kind_name(), "「%s」に立ち寄りますか？" % area.display_name, area.condition, "立ち寄る", "やめる")
	else:
		prompt.ask("%s　%s" % [area.kind_name(), area.stars()], "「%s」に進みますか？" % area.display_name, "報酬：%s　%s" % [AreaData.reward_name(waypoint.reward), area.condition], "進む", "やめる")


func _on_go() -> void:
	prompt.hide()
	if asked != null:
		travel(asked)


func _on_stay() -> void:
	prompt.hide()
	if asked != null and nodes_by_point.has(asked):
		nodes_by_point[asked].grab_focus()
		_tell(asked)
	asked = null


# The pick gone ahead with: she walks the road to it, the view following,
# the node answers, and then it is chosen. Nothing else is taken on the way.
func travel(waypoint: RouteMap.Waypoint) -> void:
	if not visible or traveling or waypoint == null or not current.has(waypoint):
		return
	traveling = true
	_card.hide()
	if _camera != null:
		_camera.kill()
		_camera = null
	for button in buttons:
		button.release_focus()
	GameAudio.play(self, &"step", -16.0)
	var from := anchor()
	var to := _center(waypoint)
	var journey := create_tween()
	journey.tween_method(_walk.bind(from, to), 0.0, 1.0, TRAVEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	journey.tween_callback(func():
		hero.idle()
		hero.facing = IDLE_FACING
		UIMotion.of(nodes_by_point[waypoint]).pulse(1.08, ARRIVE_TIME)
		GameAudio.play(self, &"confirm", -16.0))
	journey.tween_interval(ARRIVE_TIME)
	journey.tween_callback(_choose.bind(waypoint))


# One moment of her walk: placed along the road, turned and stepping the way
# she goes.
func _walk(t: float, from: Vector2, to: Vector2) -> void:
	var spot := along(from, to, t) + HERO_OFFSET
	var heading := spot - hero.position
	hero.position = spot
	if heading.length() < 0.01:
		return
	var facing := Vector2i(int(signf(heading.x)), 0)
	if absf(heading.y) > absf(heading.x) * 0.5:
		facing.y = 1 if heading.y > 0.0 else -1
	if facing != Vector2i.ZERO:
		hero.facing = facing
	hero.step(heading)


# Kept behind an event's window: shown where she stopped, taking no pick
# until the map is presented again.
func hold() -> void:
	show()
	traveling = true
	_card.hide()


# The pick taken at once (tests, and the end of her walk).
func _choose(waypoint: RouteMap.Waypoint) -> void:
	if not visible or waypoint == null or not current.has(waypoint):
		return
	traveling = false
	_card.hide()
	hide()
	chosen.emit(waypoint)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or traveling or (prompt != null and prompt.visible):
		return
	if panning and (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_end_pan()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if index >= 0 and index < current.size():
		get_viewport().set_input_as_handled()
		pick(current[index])
