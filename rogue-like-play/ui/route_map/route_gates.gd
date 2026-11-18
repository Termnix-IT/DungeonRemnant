class_name RouteGates
extends Control

# The run's choice of the next area, as gates. She stands at a fork with her
# back to the player, and each way open now is a gate before her, lit from
# within in the colour of what it gives (a boon's gold, a heal's green, the
# echo's blue, an event's violet, the boss's red) with what leads it
# standing in the light (RouteStage.leader, an event's object): a dark shape
# until the cursor turns to its gate, and then it is seen, unless it is a
# foe she has not met, which stays a shape (figure_known). The gate turned
# to grows and its light runs down the floor to her feet; what waits behind
# it is told at her left and what it gives at her right, so the two are
# weighed across her.
#
# The chapter's whole route runs across the top as a thread: the way walked
# in gold, the ways open as rings, each area further on by the sign of what
# it gives, the boss a lozenge at its end; the areas the cursor's pick would
# put out of reach go dark on it. Any area on the thread can be read (the
# pointer on it, or Up and the arrows): a card under it tells what the map's
# card used to. The boss is kept in the dark until her way reaches it; then
# its gate stands dark a moment, tolls, and it comes out with its name.
#
# Left and right turn from gate to gate, 1-3 turn to one and ask at once,
# Enter (A) asks whether to go (the other gates go dark) and again goes: she
# walks into the light and the area is entered. Esc (B) takes the question
# back; with none asked Esc (Start) calls the run's menu.
#
# The page is one focusable control that fills the screen and draws itself
# in a design space of 1600x900 scaled to its rect, in the colours and faces
# of the theme's Gates type. Her figure is the fight's rig, and the keys at
# the foot are a KeyGuide.

# The pick was gone ahead with (the end of her walk, or take()).
signal taken(waypoint: RouteMap.Waypoint)
# The run's menu was asked for (Esc, Start).
signal menu_requested

# What an area is to her now.
enum Mark { TAKEN, OPEN, AHEAD, SHUT, PASSED }

const MIO_RIG := preload("res://art/characters/mio_rig/mio_rig.tscn")
const DESIGN := Vector2(1600.0, 900.0)
# The line the gates stand on, a gate's opening, its stone's thickness, and
# how far apart gates stand (three of them, or fewer).
const FLOOR := 548.0
const GATE := Vector2(236.0, 350.0)
const FRAME := 20.0
const GATE_GAP := 400.0
const GATE_GAP_WIDE := 480.0
const BOSS_SCALE := 1.04
# Where she stands, and how tall.
const HERO := Vector2(800.0, 800.0)
const HERO_HEIGHT := 130.0
# What waits, at her left; what it gives, at her right.
const LEFT := Rect2(70.0, 664.0, 520.0, 170.0)
const RIGHT := Rect2(1010.0, 664.0, 520.0, 170.0)
const TILE := 46.0
# The thread: its ends, its line, and the gap between a layer's areas.
const THREAD_FROM := 480.0
const THREAD_TO := 1120.0
const THREAD_Y := 64.0
const THREAD_ROW := 24.0
const CARD_WIDTH := 400.0
const CARD_TOP := 116.0
const EDGE := 52.0
const STATUS_WIDTH := 300.0
const EMBLEM := 30.0
# The keys at the foot stand where the hub's do.
const GUIDE_EDGE := Vector2(40.0, 16.0)
# The motion: turning to a gate, the gates rising as the page opens, the
# question, her walk into the light, and the boss's coming out (the gate
# dark, the lightening, the hold on its name, the name's fade).
const TURN_TIME := 0.18
const RISE_TIME := 0.5
const RISE_STAGGER := 0.12
const ASK_TIME := 0.28
const TRAVEL_TIME := 0.95
const REVEAL_DARK := 0.5
const COMING_OUT := 0.9
const REVEAL_HOLD := 1.0
const REVEAL_FADE := 0.3
const SHAKE := 7.0
const SHAKE_TIME := 0.45
const BOSS_BEAT := 1.8
# What the card says of an area she cannot pick now, and of the boss before
# her way reaches it.
const AHEAD_NOTE := "この先にある"
const SHUT_NOTE := "この道からは行けない"
const PASSED_NOTE := "通り過ぎた"
const VEILED_NAME := "？？？"
const VEILED_NOTE := "この章の最奥で、何かが待ち構えている"

# The encyclopedia's record, for which foes are pictured as met (all of them
# without one).
var meta: MetaProgress
var route: RouteMap
# The layer to choose from now.
var route_layer := 0
var run: RunState
# The areas open now, and every area still within her reach.
var open: Array = []
var reach: Dictionary = {}
# The gate turned to, and whether going there has been asked.
var cursor := 0
var asked := false
# She is walking to the pick (nothing else is taken meanwhile).
var traveling := false
# The run's menu lies over the page (cover()).
var covered := false
# Kept behind an event's window: shown where she stopped, taking no pick.
var held := false
# The keys are on the thread, and the area they are on.
var threading := false
var thread_at: RouteMap.Waypoint
# An area on the thread the pointer reads.
var peek: RouteMap.Waypoint
# The boss is coming out of the dark (nothing is picked meanwhile).
var revealing := false
# What the page writes of the run: the chapter (and the step), what the last
# area gave, the curses she carries.
var title_text := ""
var note_text := ""
var curses_text := ""
var hero: DirectionalRig
var guide: KeyGuide
var _max_hp := 1
# How far each gate is turned to (0 to 1), eased every frame.
var _lit: Array[float] = []
# The route whose boss has come out of the dark, and whether its bell has
# been tolled.
var _revealed_route: RouteMap
var _tolled := false
var _hover: Variant = null
var _clock := 0.0
var _kicks := {}
var _zones: Array = []
var _origin := Vector2.ZERO
var _zoom := 1.0
var _quiet := true
# The hints the keys at the foot show now.
var _hinted: StringName
# The pictures drawn, kept: a texture drawn and then let go is freed before
# the frame is rendered.
var _portraits: Dictionary = {}


func _ready() -> void:
	theme_type_variation = &"Gates"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guide = KeyGuide.new()
	add_child(guide)
	guide.anchor_top = 1.0
	guide.anchor_bottom = 1.0
	guide.offset_left = GUIDE_EDGE.x
	guide.offset_bottom = -GUIDE_EDGE.y
	guide.offset_top = -GUIDE_EDGE.y - 44.0
	resized.connect(_fit)
	theme_changed.connect(_fit)
	_fit()


# Places the design space in the rect, and her figure with it.
func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	_place_hero(HERO, 1.0)
	queue_redraw()


# --- The route ---

# Shows the route at `at_layer` (the next to choose), with the run's state
# and a note (what the last area gave).
func present(route_map: RouteMap, at_layer: int, run_state: RunState, max_hp: int, note: String = "") -> void:
	route = route_map
	route_layer = at_layer
	run = run_state
	_max_hp = maxi(1, max_hp)
	title_text = tr(route.chapter.display_name) if run.step == 0 else tr("%s　段階%d") % [tr(route.chapter.display_name), run.step]
	note_text = note
	curses_text = tr("呪い：%s") % run.curse_names() if not run.curses.is_empty() else ""
	var previous: RouteMap.Waypoint = run.taken[route_layer - 1] if route_layer > 0 and route_layer - 1 < run.taken.size() else null
	open = route.open_after(previous)
	reach = reach_from(open)
	cursor = 0
	asked = false
	traveling = false
	held = false
	threading = false
	thread_at = null
	peek = null
	_hover = null
	_lit.clear()
	for index in open.size():
		_lit.append(1.0 if index == 0 else 0.0)
	_kicks.clear()
	_kick(&"open")
	_quiet = true
	_stand_hero()
	# Her way reaches the boss: once a run, it comes out of the dark.
	revealing = not open.is_empty() and (open[0] as RouteMap.Waypoint).area.boss != null and _revealed_route != route
	_tolled = false
	if revealing:
		_revealed_route = route
		_lit[0] = 0.0
		_kick(&"reveal")
	_hint()
	if not covered:
		grab_focus()
	queue_redraw()


# Her figure: the fight's rig with the weapon she carries, her back to the
# player.
func _stand_hero() -> void:
	if hero != null:
		hero.free()
	hero = MIO_RIG.instantiate()
	hero.world_height = HERO_HEIGHT
	add_child(hero)
	move_child(hero, 0)
	if run != null and run.moveset != null and run.moveset.art != null:
		WeaponMount.hold(hero, run.moveset)
	hero.facing = Vector2i.UP
	hero.modulate = Color.WHITE
	hero.show()
	_place_hero(HERO, 1.0)


func _place_hero(at: Vector2, share: float) -> void:
	if hero == null:
		return
	hero.position = _origin + at * _zoom
	hero.scale = Vector2.ONE * _zoom * share


# Every area that can still be come to from these.
func reach_from(points: Array) -> Dictionary:
	var found := {}
	var frontier := points.duplicate()
	while not frontier.is_empty():
		var point: RouteMap.Waypoint = frontier.pop_back()
		if not found.has(point):
			found[point] = true
			frontier.append_array(point.next)
	return found


func selected() -> RouteMap.Waypoint:
	return open[cursor] if cursor >= 0 and cursor < open.size() else null


# Where she stands: the area last taken, or null at the start.
func here() -> RouteMap.Waypoint:
	return run.taken[route_layer - 1] if route_layer > 0 and route_layer - 1 < run.taken.size() else null


func mark(point: RouteMap.Waypoint) -> Mark:
	if open.has(point):
		return Mark.OPEN
	if point.layer < route_layer:
		return Mark.TAKEN if run.taken.has(point) else Mark.PASSED
	return Mark.AHEAD if reach.has(point) else Mark.SHUT


# The boss before her way reaches it, and while it has not come out yet.
func veiled(point: RouteMap.Waypoint) -> bool:
	if point.area.boss == null:
		return false
	return not open.has(point) or (revealing and _since(&"reveal") < REVEAL_DARK)


# The areas further on, within reach now, that picking `point` would put out
# of it (the other ways open now are not counted: a pick always leaves them).
func closes(point: RouteMap.Waypoint) -> Dictionary:
	var kept := reach_from([point])
	var lost := {}
	for other: RouteMap.Waypoint in reach:
		if not kept.has(other) and not open.has(other):
			lost[other] = true
	return lost


func is_met(foe: FoeData) -> bool:
	return meta == null or meta.has_met(foe.id)


# Whether what stands in an area's gate is seen once the gate is turned to:
# an event's object always, and the boss, whose coming out is the meeting;
# another fight's leading foe only once it has been met, as the encyclopedia
# shows a foe not met by its shape alone.
func figure_known(point: RouteMap.Waypoint) -> bool:
	var area := point.area
	if area.is_event() or area.boss != null:
		return true
	var foe := RouteStage.leader(area)
	return foe == null or is_met(foe)


# The echo an area brings in all: an echo reward's whole amount, else what
# every clearing gives (with a last-layer trial's share).
func echo_of(point: RouteMap.Waypoint) -> int:
	if point.area.is_event() or point.area.boss != null:
		return 0
	var trial := run.trial_echo(point.area, point.layer)
	if point.reward == AreaData.Reward.ECHO:
		return run.echo_reward(point.area.echo) + trial
	return run.clear_echo(point.area) + trial


# Everything told of an area, in words the page lays out: {point, mark,
# veiled, event, boss, name, kind, danger, time, reward (-1: none),
# reward_words, echo, goal, summary, foes ([FoeData, met] each), state}.
func tell(point: RouteMap.Waypoint) -> Dictionary:
	var area := point.area
	var state := mark(point)
	var note := ""
	if state != Mark.OPEN:
		note = tr({Mark.AHEAD: AHEAD_NOTE, Mark.SHUT: SHUT_NOTE}.get(state, PASSED_NOTE))
	var told := {
		point = point, mark = state, veiled = veiled(point), event = area.is_event(), boss = area.boss != null,
		name = tr(area.display_name), kind = area.kind_name(), danger = 0 if area.is_event() else area.difficulty,
		time = "", reward = -1, reward_words = "", echo = 0, goal = "", summary = "", foes = [], state = note,
	}
	if told.veiled:
		told.name = tr(VEILED_NAME)
		told.goal = tr(VEILED_NOTE)
		told.danger = 0
		return told
	if area.is_event():
		told.reward_words = tr(area.condition)
		told.summary = tr(area.foe_summary)
		return told
	told.time = tr("目安 %d分%02d秒") % [area.expected_time / 60, area.expected_time % 60]
	told.goal = tr(area.condition)
	told.summary = tr(area.foe_summary)
	if area.boss == null:
		told.reward = point.reward
		told.reward_words = AreaData.reward_name(point.reward)
		told.echo = echo_of(point)
	for foe in Chapters.area_foes(area):
		told.foes.append([foe, is_met(foe)])
	return told


# --- The steps of a pick ---

# Turns to a gate; the question, if asked, is taken back.
func choose(index: int) -> void:
	if traveling or held or revealing or index < 0 or index >= open.size():
		return
	if asked:
		asked = false
		_kick(&"unask")
		_hint()
	if index != cursor:
		cursor = index
		_kick(&"move")
		_sound(&"ui_move")
	queue_redraw()


# Asks whether to go to the gate turned to.
func ask() -> void:
	if traveling or held or revealing or covered or asked or selected() == null:
		return
	asked = true
	_leave_thread()
	_kick(&"ask")
	_sound(&"ui_open")
	_hint()


# A pick from the player (a number key, the tests): turns to its gate and asks.
func pick(waypoint: RouteMap.Waypoint) -> void:
	if not is_visible_in_tree() or covered or waypoint == null or not open.has(waypoint):
		return
	_end_reveal()
	choose(open.find(waypoint))
	ask()


# Enter (A): the question, and asked, the going.
func accept() -> void:
	if asked:
		go()
	else:
		ask()


# Esc (B) while the question is asked: takes it back.
func cancel() -> void:
	if not asked or traveling:
		return
	asked = false
	_kick(&"unask")
	_sound(&"ui_back")
	_hint()


# The pick gone ahead with: she walks into the gate's light, and then it is
# taken. Nothing else is taken on the way.
func go() -> void:
	if traveling or not asked or selected() == null:
		return
	traveling = true
	peek = null
	_kick(&"go")
	GameAudio.play(self, &"step", -16.0)
	_hint()


# The pick taken at once (the end of her walk, and the tests).
func take(waypoint: RouteMap.Waypoint) -> void:
	if waypoint == null or not open.has(waypoint):
		return
	cursor = open.find(waypoint)
	traveling = false
	asked = false
	revealing = false
	peek = null
	_leave_thread()
	taken.emit(waypoint)


# Kept behind an event's window: her gate stands lit, the others dark, and
# nothing is picked until the route is presented again.
func hold() -> void:
	held = true
	asked = false
	traveling = false
	peek = null
	_leave_thread()
	if hero != null:
		hero.hide()
	_hint()
	queue_redraw()


# The run's menu lies over the page (or is lifted off it): nothing is picked
# or read meanwhile, and lifted, the focus comes back.
func cover(on: bool) -> void:
	covered = on
	if on:
		peek = null
		_hover = null
	elif is_visible_in_tree():
		grab_focus()
	queue_redraw()


# 0 to 1 while the question is asked, easing both ways.
func asking() -> float:
	if held:
		return 1.0
	if asked:
		return _eased(&"ask", ASK_TIME)
	return 1.0 - _eased(&"unask", TURN_TIME) if _since(&"unask") < TURN_TIME else 0.0


# --- Reading the thread ---

# Up from the gates: the keys go to the thread, on the gate's own area.
func enter_thread() -> void:
	if asked or traveling or held or revealing or selected() == null:
		return
	threading = true
	thread_at = selected()
	_kick(&"read")
	_sound(&"ui_move")
	_hint()


func _leave_thread() -> void:
	if not threading:
		return
	threading = false
	thread_at = null
	_hint()


# The keys along the thread: a layer on or back, or the next area of the
# layer; down past a layer's last leaves the thread.
func move_thread(by: Vector2i) -> void:
	if not threading or thread_at == null:
		return
	var points := route.nodes(thread_at.layer)
	var row := points.find(thread_at)
	if by.x != 0:
		var layer := clampi(thread_at.layer + by.x, 0, route.size() - 1)
		if layer == thread_at.layer:
			return
		var there := route.nodes(layer)
		# The area nearest across: the same share of the way down its layer.
		var share := 0.5 if points.size() <= 1 else float(row) / (points.size() - 1)
		thread_at = there[roundi(share * (there.size() - 1))]
	elif by.y < 0:
		if row == 0:
			return
		thread_at = points[row - 1]
	else:
		if row >= points.size() - 1:
			_leave_thread()
			_sound(&"ui_back")
			return
		thread_at = points[row + 1]
	_kick(&"read")
	_sound(&"ui_move")


# The area read now: the one the keys are on, else the one pointed at.
func read() -> RouteMap.Waypoint:
	return thread_at if threading else peek


# --- The boss's coming out ---

func _reveal_time() -> float:
	return REVEAL_DARK + COMING_OUT + REVEAL_HOLD + REVEAL_FADE


# A key or a click during the coming out cuts it short.
func _end_reveal() -> void:
	if not revealing:
		return
	revealing = false
	_kick(&"move")
	if not _lit.is_empty():
		_lit[0] = 1.0
	_hint()


# How far the boss has come out (0: dark, 1: seen), while it does.
func _coming() -> float:
	return clampf((_since(&"reveal") - REVEAL_DARK) / COMING_OUT, 0.0, 1.0)


# --- Clock ---

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_quiet = false
	_clock += delta
	for index in _lit.size():
		var want := 1.0 if index == cursor else 0.0
		if revealing:
			want = _coming()
		_lit[index] = move_toward(_lit[index], want, delta / TURN_TIME)
	if revealing:
		if not _tolled and _since(&"reveal") >= REVEAL_DARK:
			_tolled = true
			GameAudio.play(self, &"boss", -10.0)
		if _since(&"reveal") >= _reveal_time():
			_end_reveal()
	if traveling:
		_walk()
		if _since(&"go") >= TRAVEL_TIME:
			GameAudio.play(self, &"confirm", -16.0)
			take(selected())
	elif hero != null and hero.visible:
		_place_hero(HERO, 1.0)
	queue_redraw()


# One moment of her walk: toward the gate, smaller and darker against its light.
func _walk() -> void:
	if hero == null:
		return
	var share := smoothstep(0.0, 0.8, _since(&"go") / TRAVEL_TIME)
	var gate := Vector2(gate_x(cursor), FLOOR)
	var next := HERO.lerp(gate, share)
	hero.step((_origin + next * _zoom) - hero.position)
	_place_hero(next, lerpf(1.0, 0.6, share))
	hero.modulate = Color.WHITE.lerp(_colour(&"shape"), share * 0.85)


func _kick(what: StringName) -> void:
	_kicks[what] = _clock


func _since(what: StringName) -> float:
	return _clock - float(_kicks.get(what, -1000.0))


func _eased(what: StringName, time: float) -> float:
	var share := clampf(_since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


func _breath(period := 2.1) -> float:
	return 0.5 + 0.5 * sin(_clock * TAU / period)


func _sound(cue: StringName) -> void:
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, cue, -22.0)


# --- Input ---

# The keys at the foot, for what the keys do now.
func _hint() -> void:
	var state: StringName = &"none" if held or traveling or revealing else (&"asked" if asked else (&"thread" if threading else &"gates"))
	if guide == null or state == _hinted:
		return
	_hinted = state
	guide.clear_hints(0)
	match state:
		&"gates":
			guide.add_hint(tr("← / →・1〜3"), tr("十字"), tr("門を選ぶ"))
			guide.add_hint("Enter", "A", tr("進む"))
			guide.add_hint("↑", tr("十字の上"), tr("道筋を読む"))
			guide.add_hint("Esc", "START", tr("メニュー"))
		&"asked":
			guide.add_hint("Enter", "A", tr("出発する"))
			guide.add_hint("Esc", "B", tr("やめる"))
		&"thread":
			guide.add_hint(tr("←→↑↓"), tr("十字"), tr("道筋をたどる"))
			guide.add_hint(tr("↓・Esc"), "B", tr("門へ戻る"))


func _gui_input(event: InputEvent) -> void:
	if covered or held:
		return
	if event is InputEventMouseMotion:
		var id: Variant = _zone_at(event.position)
		if id != _hover:
			_hover = id
			_point(id)
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			accept_event()
			if revealing:
				_end_reveal()
				return
			var id: Variant = _zone_at(event.position)
			if id != null:
				_press(id)
		return
	if _take_key(event):
		accept_event()


# Keys that come while nothing holds the focus.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or covered or held or has_focus():
		return
	if _take_key(event):
		get_viewport().set_input_as_handled()


# A key or a pad's button; true when it was this page's to take.
func _take_key(event: InputEvent) -> bool:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		return false
	if traveling:
		return true
	if revealing:
		if event.is_pressed() and not event.is_echo() and not event is InputEventJoypadMotion:
			_end_reveal()
		return true
	if event.is_action_pressed(&"ui_cancel"):
		if asked:
			cancel()
			return true
		if threading:
			_leave_thread()
			_sound(&"ui_back")
			return true
	# The run's menu (Esc, Start): the fork is where a run is rested or left.
	if event.is_action_pressed(&"pause"):
		if not asked:
			menu_requested.emit()
		return true
	if event.is_action_pressed(&"ui_accept"):
		if threading:
			# On an open area's place: its gate is turned to.
			var at := open.find(thread_at)
			_leave_thread()
			if at >= 0:
				choose(at)
		else:
			accept()
		return true
	for pair: Array in [[&"ui_left", Vector2i.LEFT], [&"ui_right", Vector2i.RIGHT], [&"ui_up", Vector2i.UP], [&"ui_down", Vector2i.DOWN]]:
		if event.is_action_pressed(pair[0], true):
			_arrow(pair[1])
			return true
		# Taken whole, so the focus never leaves for the keys at the foot.
		if event.is_action(pair[0]):
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
		if index >= 0 and index < open.size():
			pick(open[index])
			return true
	return false


func _arrow(way: Vector2i) -> void:
	if threading:
		move_thread(way)
	elif way == Vector2i.UP:
		enter_thread()
	elif way.x != 0:
		choose(clampi(cursor + way.x, 0, open.size() - 1))


# The pointer came over a zone (or left them all: null).
func _point(id: Variant) -> void:
	peek = null
	if not id is Array or traveling or revealing:
		return
	match (id as Array)[0]:
		&"gate":
			if not asked and (id as Array)[1] != cursor:
				choose((id as Array)[1])
		&"node":
			var point: RouteMap.Waypoint = (id as Array)[1]
			if not open.has(point):
				peek = point
			elif not asked:
				choose(open.find(point))


# A place the pointer clicked: [&"gate", index] and [&"node", waypoint]
# (turns to it; on the one turned to already, the question, and asked, the
# going), [&"go"].
func _press(id: Variant) -> void:
	var what: Array = id
	var index := -1
	match what[0]:
		&"gate":
			index = what[1]
		&"node":
			index = open.find(what[1])
		&"go":
			accept()
			return
	if index < 0:
		return
	_leave_thread()
	if index == cursor:
		accept()
	else:
		choose(index)


func _zone(rect: Rect2, id: Variant) -> void:
	_zones.append([rect, id])


func _zone_at(point: Vector2) -> Variant:
	var at := (point - _origin) / _zoom
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(at):
			return _zones[index][1]
	return null


# The zone of a gate, in the page's own space (for the layout's tests).
func gate_rect(index: int) -> Rect2:
	for zone: Array in _zones:
		if zone[1] is Array and zone[1] == [&"gate", index]:
			var rect: Rect2 = zone[0]
			return Rect2(_origin + rect.position * _zoom, rect.size * _zoom)
	return Rect2()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = null
		peek = null


# --- Layout ---

func _colour(item: StringName, share := 1.0) -> Color:
	var colour := get_theme_color(item)
	return Color(colour, colour.a * share)


func _face(item: StringName) -> Font:
	return get_theme_font(item)


func _size(item: StringName) -> int:
	return get_theme_font_size(item)


func _words(at: Vector2, words: String, face: StringName, size: StringName, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_face(face), at, words, align, width, _size(size), colour)


func _width(words: String, face: StringName, size: StringName) -> float:
	return _face(face).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(size)).x


# Japanese breaks between any two letters; a script with spaces, at them.
func _breaks() -> int:
	return TextServer.BREAK_MANDATORY | (TextServer.BREAK_GRAPHEME_BOUND if TranslationServer.get_locale().begins_with("ja") else TextServer.BREAK_WORD_BOUND)


# Wrapped words; returns the height they took.
func _lines(at: Vector2, words: String, face: StringName, size: StringName, colour: Color, width: float, most := 2, align := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	if words.is_empty():
		return 0.0
	draw_multiline_string(_face(face), at, words, align, width, _size(size), most, colour, _breaks())
	return _face(face).get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, width, _size(size), most, _breaks()).y


# The colour of what an area gives: its gate's light.
func light_of(told: Dictionary) -> Color:
	if told.boss:
		return _colour(&"boss")
	return _colour({AreaData.Reward.BOON: &"boon", AreaData.Reward.HEAL: &"heal", AreaData.Reward.ECHO: &"echo"}.get(told.reward, &"event"))


# Where a gate stands: its foot's middle.
func gate_x(index: int) -> float:
	var count := open.size()
	var gap := GATE_GAP if count >= 3 else GATE_GAP_WIDE
	return DESIGN.x * 0.5 + (index - (count - 1) * 0.5) * gap


# Where an area stands on the thread (null: the start).
func thread_spot(point: RouteMap.Waypoint) -> Vector2:
	var gap := (THREAD_TO - THREAD_FROM) / route.size()
	if point == null:
		return Vector2(THREAD_FROM, THREAD_Y)
	var points := route.nodes(point.layer)
	return Vector2(THREAD_FROM + gap * (point.layer + 1), THREAD_Y + (points.find(point) - (points.size() - 1) * 0.5) * THREAD_ROW)


# What stands in an area's gate: its leading foe's painted portrait (its
# picture where none is painted), or an event's object.
func portrait_of(area: AreaData) -> Texture2D:
	if not _portraits.has(area):
		var art: Texture2D = null
		if area.is_event():
			art = RouteStage.prop_for(area.event)
		else:
			var foe := RouteStage.leader(area)
			if foe != null:
				art = EnemySprites.codex_portrait(foe.visual_id)
				if art == null:
					art = HubCodex.tile_picture(foe.visual_id, true)
		_portraits[area] = art
	return _portraits[area]


# --- Drawing ---

# The transform of the design space, moved to `at` within it.
func _to(at := Vector2.ZERO) -> void:
	draw_set_transform(_origin + at * _zoom, 0.0, Vector2.ONE * _zoom)


func _draw() -> void:
	_zones.clear()
	if route == null:
		return
	_draw_backdrop()
	# The boss's toll shakes the whole fork.
	var shake := Vector2.ZERO
	if revealing:
		var since := _since(&"reveal") - REVEAL_DARK
		if since >= 0.0 and since < SHAKE_TIME:
			shake.y = sin(since / SHAKE_TIME * TAU * 4.0) * SHAKE * (1.0 - since / SHAKE_TIME)
	_origin += shake
	_to()
	for index in open.size():
		_draw_path(index)
	for index in open.size():
		if index != cursor:
			_draw_gate(index)
	if selected() != null:
		_draw_gate(cursor)
	_draw_thread()
	_draw_top()
	if not held and not revealing:
		_draw_weighing()
		_draw_question()
	if revealing:
		_draw_boss_title()
	if traveling:
		_draw_flood()
	var shown := read()
	if shown != null and not covered:
		_to()
		_draw_card(shown)
	_draw_tip()
	_origin -= shake
	draw_set_transform(Vector2.ZERO)


# The chapter's own painting, far back in the dark, over the whole screen,
# and the floor she stands on.
func _draw_backdrop() -> void:
	var night := _colour(&"night")
	var clear := Color(night, 0.0)
	draw_rect(Rect2(Vector2.ZERO, size), night)
	var line := _origin.y + (FLOOR + 72.0) * _zoom
	var art := route.chapter.illustration
	if art != null:
		var room := Rect2(0.0, 0.0, size.x, line)
		var full := art.get_size()
		var part := room.size / maxf(room.size.x / full.x, room.size.y / full.y)
		draw_texture_rect_region(art, room, Rect2((full - part) * Vector2(0.5, 0.25), part), _colour(&"art"))
	_fall(Rect2(0.0, 0.0, size.x, line * 0.25), Color(night, 0.92), Color(night, 0.35))
	_fall(Rect2(0.0, line * 0.25, size.x, line * 0.5), Color(night, 0.35), Color(night, 0.62))
	_fall(Rect2(0.0, line * 0.75, size.x, line * 0.25), Color(night, 0.62), night)
	var side := size.x * 0.19
	_fall_across(Rect2(0.0, 0.0, side, line), Color(night, 0.9), clear)
	_fall_across(Rect2(size.x - side, 0.0, side, line), clear, Color(night, 0.9))
	# The boss's toll: a red flush over it all.
	if revealing:
		var since := _since(&"reveal") - REVEAL_DARK
		if since >= 0.0:
			var flush := _colour(&"flush")
			var rise := COMING_OUT * 0.4
			draw_rect(Rect2(Vector2.ZERO, size), Color(flush, flush.a * (since / rise if since < rise else maxf(0.0, 1.0 - (since - rise) / COMING_OUT))))
	# The flagstones' lines, running to where the gates stand.
	_to()
	var seam := Color(1.0, 1.0, 1.0, 0.025)
	for index in 9:
		draw_line(Vector2(DESIGN.x * 0.5 + (index - 4) * 120.0, FLOOR + 6.0), Vector2(DESIGN.x * 0.5 + (index - 4) * 210.0, DESIGN.y), seam, 1.0, true)
	for index in 5:
		var y := FLOOR + 14.0 + index * index * 16.0
		draw_line(Vector2(-_origin.x / _zoom, y), Vector2(DESIGN.x + _origin.x / _zoom, y), Color(seam, 0.02), 1.0)
	draw_set_transform(Vector2.ZERO)


# A rect whose colour runs from `top` to `bottom`.
func _fall(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _fall_across(rect: Rect2, left: Color, right: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([left, right, right, left]))


# A soft round light, `squash` flattening it into an oval.
func _glow(centre: Vector2, radius: float, colour: Color, squash := 1.0) -> void:
	if colour.a <= 0.003:
		return
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([colour])
	for index in 33:
		points.append(centre + Vector2.from_angle(TAU * index / 32.0) * radius * Vector2(1.0, squash))
		colours.append(Color(colour, 0.0))
	for index in 32:
		draw_polygon(PackedVector2Array([points[0], points[index + 1], points[index + 2]]), PackedColorArray([colours[0], colours[index + 1], colours[index + 2]]))


func _lozenge(centre: Vector2, radius: float, colour: Color, width := 0.0) -> void:
	var points := PackedVector2Array([centre + Vector2(0.0, -radius), centre + Vector2(radius, 0.0), centre + Vector2(0.0, radius), centre + Vector2(-radius, 0.0)])
	if width <= 0.0:
		draw_colored_polygon(points, colour)
	else:
		points.append(points[0])
		draw_polyline(points, colour, width, true)


# A reward's sign: a boon's star, a heal's heart, the echo's ring; an event
# (reward -1) a lozenge with a dot.
func _sign(centre: Vector2, radius: float, reward: int, colour: Color) -> void:
	match reward:
		AreaData.Reward.BOON:
			HubUI.star(self, centre, radius * 1.25, colour)
		AreaData.Reward.HEAL:
			var points := PackedVector2Array()
			for step in 32:
				var t := TAU * step / 32.0
				points.append(centre + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * radius / 16.0 + Vector2(0.0, -radius * 0.12))
			draw_colored_polygon(points, colour)
		AreaData.Reward.ECHO:
			draw_arc(centre, radius * 0.92, 0.0, TAU, 24, colour, maxf(1.5, radius * 0.22), true)
			draw_circle(centre, radius * 0.36, colour)
		_:
			_lozenge(centre, radius, colour, maxf(1.5, radius * 0.2))
			draw_circle(centre, radius * 0.22, colour)


# How open a gate is: 1, or going dark while the question is asked of another.
func _open_share(index: int) -> float:
	return 1.0 if index == cursor else 1.0 - asking()


# How far a gate has risen as the page opened.
func _rise(index: int) -> float:
	return _eased(&"open", RISE_TIME + index * RISE_STAGGER)


# The light a gate throws down the floor to her feet.
func _draw_path(index: int) -> void:
	var told := tell(open[index])
	var colour := light_of(told)
	var lit := _lit[index]
	var x := gate_x(index)
	var strength := (0.07 + 0.3 * lit) * _open_share(index) * _rise(index)
	if told.veiled:
		strength = 0.0
	var half := GATE.x * 0.42
	draw_polygon(
		PackedVector2Array([Vector2(x - half, FLOOR + 4.0), Vector2(x + half, FLOOR + 4.0), Vector2(HERO.x + 44.0, HERO.y + 6.0), Vector2(HERO.x - 44.0, HERO.y + 6.0)]),
		PackedColorArray([Color(colour, strength), Color(colour, strength), Color(colour, strength * 0.12), Color(colour, strength * 0.12)]))
	_glow(Vector2(x, FLOOR + 10.0), 230.0, Color(colour, strength * 0.8), 0.16)


# The pointed arch of a gate `wide` across and `high` to its tip, standing
# on (0, 0).
static func arch(wide: float, high: float) -> PackedVector2Array:
	var spring := -(high - wide * 0.866)
	var points := PackedVector2Array([Vector2(-wide * 0.5, 0.0)])
	for step in 13:
		var turn := PI - PI / 3.0 * step / 12.0
		points.append(Vector2(wide * 0.5 + cos(turn) * wide, spring - sin(turn) * wide))
	for step in range(11, -1, -1):
		var turn := PI - PI / 3.0 * step / 12.0
		points.append(Vector2(-wide * 0.5 - cos(turn) * wide, spring - sin(turn) * wide))
	points.append(Vector2(wide * 0.5, 0.0))
	return points


func _draw_gate(index: int) -> void:
	var point: RouteMap.Waypoint = open[index]
	var told := tell(point)
	var colour := light_of(told)
	var lit := _lit[index]
	var open_share := _open_share(index)
	var boss: bool = told.boss
	var rise := _rise(index)
	var grown := (1.0 + 0.13 * lit - 0.03 * (1.0 - lit)) * (BOSS_SCALE if boss else 1.0)
	var foot := Vector2(gate_x(index), FLOOR + (1.0 - rise) * 26.0)
	var wide := GATE.x * grown
	var high := GATE.y * grown
	var pale := _colour(&"pale")
	_zone(Rect2(foot.x - wide * 0.5 - FRAME, foot.y - high - FRAME, wide + FRAME * 2.0, high + FRAME + 96.0), [&"gate", index])
	_to(foot)
	# The glow round it, and its stone.
	var beat := 0.75 + 0.25 * _breath(BOSS_BEAT) if boss else 1.0
	_glow(Vector2(0.0, -high * 0.5), wide * 1.5, Color(colour, (0.05 + 0.2 * lit) * open_share * rise * beat))
	var outer := arch(wide + FRAME * 2.0, high + FRAME * 1.6)
	var stone := PackedColorArray()
	for at in outer:
		stone.append(Color(_colour(&"stone").lerp(_colour(&"stone_dark"), clampf(-at.y / high, 0.0, 1.0) * 0.8).lerp(colour, 0.06 * lit * open_share), rise))
	draw_polygon(outer, stone)
	outer.append(outer[0])
	draw_polyline(outer, Color(1.0, 1.0, 1.0, (0.1 + 0.12 * lit) * rise), 1.0, true)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * (wide * 0.5 + FRAME * 0.5) - FRAME * 0.75, -10.0, FRAME * 1.5, 16.0), Color(_colour(&"stone").lightened(0.06), rise))
	# The light within: brightest at the threshold.
	var inner := arch(wide, high)
	var light := PackedColorArray()
	var strength := (0.42 + 0.58 * lit) * open_share * rise
	if told.veiled:
		strength = 0.08
	var dark := _colour(&"shape")
	for at in inner:
		var up := clampf(-at.y / high, 0.0, 1.0)
		light.append(dark.lerp(colour.lerp(Color.WHITE, 0.25 * (1.0 - up)), strength * pow(1.0 - up, 1.4) * 0.95))
	draw_polygon(inner, light)
	_glow(Vector2(0.0, -8.0), wide * 0.66, Color(colour.lerp(Color.WHITE, 0.4), 0.55 * strength), 0.55)
	# What leads it, standing in the light: a dark shape until it is turned to.
	var art := portrait_of(point.area)
	if art != null:
		var room := Vector2(wide * 0.94, high * 0.8 - 2.0)
		var full := art.get_size()
		var kept := full * minf(room.x / full.x, room.y / full.y)
		var foe := RouteStage.leader(point.area)
		# A foe not met stays a shape against the light, turned to or not.
		var seen := Color(dark, 0.94).lerp(foe.tint if foe != null and not point.area.is_event() else Color.WHITE, lit if figure_known(point) else 0.0)
		draw_texture_rect(art, Rect2(-kept.x * 0.5, -2.0 - kept.y, kept.x, kept.y), false, Color(seen, seen.a * rise * (0.25 + 0.75 * open_share)))
		# The light catching its feet.
		_glow(Vector2(0.0, -4.0), wide * 0.5, Color(colour.lerp(Color.WHITE, 0.5), 0.34 * strength), 0.3)
	inner.append(inner[0])
	draw_polyline(inner, Color(colour, ((0.3 + 0.7 * lit) * open_share if not told.veiled else 0.25) * rise), 1.5 + 1.5 * lit, true)
	# Its key on the keystone.
	var tip := Vector2(0.0, -high - FRAME * 1.6 + 8.0)
	_lozenge(tip, 20.0, Color(_colour(&"stone_dark"), rise))
	_lozenge(tip, 20.0, Color(colour, ((0.4 + 0.6 * lit) * open_share + 0.15) * rise), 1.5)
	_words(Vector2(tip.x - 14.0, tip.y + 7.0), str(index + 1), &"title_font", &"key_size", Color(pale, (0.5 + 0.5 * lit) * rise), HORIZONTAL_ALIGNMENT_CENTER, 28.0)
	# Its name and signs under the threshold (the boss's own title, while it
	# comes out).
	if not revealing:
		var fade := (0.55 + 0.45 * lit) * (0.3 + 0.7 * open_share) * rise
		_words(Vector2(-190.0, 46.0), told.name, &"title_font", &"name_size", Color(pale, fade), HORIZONTAL_ALIGNMENT_CENTER, 380.0)
		_draw_signs(Vector2(0.0, 72.0), told, fade)
	_to()


# How wide an area's signs stand in a row.
func _signs_width(told: Dictionary) -> float:
	var gives: String = "" if told.boss or told.veiled else (tr("取引") if told.event else told.reward_words)
	var danger: int = told.danger
	return _width(told.kind, &"font", &"label_size") + (16.0 + danger * 15.0 if danger > 0 else 0.0) + (40.0 + _width(gives, &"bold_font", &"label_size") if not gives.is_empty() else 0.0)


# An area's signs in a row round `centre`: its kind, its danger, what it gives.
func _draw_signs(centre: Vector2, told: Dictionary, fade: float) -> void:
	var colour := light_of(told)
	var gives: String = "" if told.boss or told.veiled else (tr("取引") if told.event else told.reward_words)
	var danger: int = told.danger
	var x := centre.x - _signs_width(told) * 0.5
	_words(Vector2(x, centre.y + 5.0), told.kind, &"font", &"label_size", _colour(&"dim", fade))
	x += _width(told.kind, &"font", &"label_size") + 16.0
	for index in danger:
		_lozenge(Vector2(x + 5.0, centre.y), 5.5, _colour(&"boss", fade))
		x += 15.0
	if not gives.is_empty():
		x += 10.0
		_sign(Vector2(x + 7.0, centre.y), 7.0, told.reward, Color(colour, fade))
		_words(Vector2(x + 22.0, centre.y + 5.0), gives, &"bold_font", &"label_size", Color(colour, fade))


# The chapter's whole route as one thread across the top.
func _draw_thread() -> void:
	var chosen := selected()
	var kept := reach_from([chosen]) if chosen != null else {}
	var colour := light_of(tell(chosen)) if chosen != null else _colour(&"pale")
	var pale := _colour(&"pale")
	var gold := _colour(&"boon")
	var walked := run.taken.slice(0, route_layer)
	var come := _eased(&"open", RISE_TIME)
	for point: RouteMap.Waypoint in route.nodes(0):
		_draw_strand(null, point, walked, kept, colour, come)
	for index in route.size() - 1:
		for from: RouteMap.Waypoint in route.nodes(index):
			for to: RouteMap.Waypoint in from.next:
				_draw_strand(from, to, walked, kept, colour, come)
	draw_circle(thread_spot(null), 3.5, Color(gold if not walked.is_empty() else pale, come))
	var reading := read()
	for index in route.size():
		for point: RouteMap.Waypoint in route.nodes(index):
			var at := thread_spot(point)
			var state := mark(point)
			_zone(Rect2(at - Vector2(20.0, THREAD_ROW * 0.5), Vector2(40.0, THREAD_ROW)), [&"node", point])
			if state != Mark.SHUT and state != Mark.PASSED:
				draw_circle(at, 9.0, _colour(&"night", 0.85 * come))
			if point.area.boss != null:
				var dark := veiled(point)
				_lozenge(at, 9.0, _colour(&"boss", (0.3 if dark else 1.0) * come))
				_lozenge(at, 13.0, _colour(&"boss", (0.4 + 0.3 * _breath(BOSS_BEAT)) * come), 1.0)
			else:
				match state:
					Mark.TAKEN:
						draw_circle(at, 5.0, Color(gold, come))
					Mark.OPEN:
						if point == chosen:
							draw_circle(at, 4.5, Color(colour, come))
							draw_arc(at, 9.0 + _breath() * 1.5, 0.0, TAU, 24, Color(colour, come), 1.5, true)
						else:
							draw_arc(at, 5.5, 0.0, TAU, 20, Color(pale, (0.9 - 0.6 * asking()) * come), 1.5, true)
					Mark.AHEAD:
						var told := tell(point)
						_sign(at, 5.5, told.reward, Color(light_of(told), (0.9 if kept.has(point) else 0.25) * come))
					_:
						draw_circle(at, 2.5, Color(pale, 0.18 * come))
			if reading == point:
				draw_arc(at, 13.0, 0.0, TAU, 28, pale, 1.5, true)
				for tick in 4:
					var way := Vector2.from_angle(TAU * tick / 4.0 + _clock * 0.5)
					draw_line(at + way * 13.0, at + way * 18.0, pale, 1.5, true)


func _draw_strand(from: RouteMap.Waypoint, to: RouteMap.Waypoint, walked: Array, kept: Dictionary, colour: Color, come: float) -> void:
	var a := thread_spot(from)
	var b := thread_spot(to)
	var pale := _colour(&"pale")
	var at := walked.find(to)
	if at >= 0 and (from == null and at == 0 or at > 0 and walked[at - 1] == from):
		draw_line(a, b, _colour(&"boon", come), 2.0, true)
	elif from == here() and open.has(to):
		var mine := to == selected()
		draw_line(a, b, Color(colour, come) if mine else Color(pale, (0.5 - 0.35 * asking()) * come), 2.0 if mine else 1.0, true)
	elif from != null and reach.has(from) and from.layer >= route_layer:
		draw_line(a, b, Color(colour, 0.55 * come) if kept.has(from) else Color(pale, 0.1 * come), 1.0, true)
	else:
		draw_line(a, b, Color(pale, 0.07 * come), 1.0, true)


# The chapter at the top left; her health, level, echo and boons at the top
# right.
func _draw_top() -> void:
	var pale := _colour(&"pale")
	var dim := _colour(&"dim")
	_words(Vector2(EDGE, 44.0), Chapters.short_name(route.chapter), &"font", &"label_size", dim)
	_words(Vector2(EDGE, 78.0), Chapters.title(route.chapter), &"title_font", &"title_size", pale)
	var where := tr("最奥") if selected() != null and selected().area.boss != null else tr("第%d層") % (route_layer + 1)
	var along := tr("%s　／　%s") % [where, tr("%d層とボス") % (route.size() - 1)]
	if run.step > 0:
		along += "　" + tr("段階%d") % run.step
	_words(Vector2(EDGE, 104.0), along, &"font", &"label_size", dim)
	if not note_text.is_empty():
		_words(Vector2(EDGE, 134.0), note_text, &"lead_font", &"note_size", _colour(&"boon", _eased(&"open", RISE_TIME)))
	var right := DESIGN.x - EDGE
	var left := right - STATUS_WIDTH
	var hp := run.hp if run.hp > 0 else _max_hp
	_words(Vector2(left, 44.0), "HP", &"bold_font", &"label_size", _colour(&"boss"))
	_words(Vector2(left + 30.0, 46.0), str(hp), &"title_font", &"name_size", pale)
	_words(Vector2(left + 30.0 + _width(str(hp), &"title_font", &"name_size") + 6.0, 46.0), "/ %d" % _max_hp, &"lead_font", &"body_size", dim)
	_words(Vector2(left, 46.0), "Lv %d" % run.progression.level, &"title_font", &"key_size", pale, HORIZONTAL_ALIGNMENT_RIGHT, STATUS_WIDTH)
	draw_rect(Rect2(left, 56.0, STATUS_WIDTH, 6.0), Color(1.0, 1.0, 1.0, 0.1))
	draw_rect(Rect2(left, 56.0, STATUS_WIDTH * clampf(hp / float(_max_hp), 0.0, 1.0), 6.0), _colour(&"boss"))
	_sign(Vector2(left + 8.0, 86.0), 7.0, AreaData.Reward.ECHO, _colour(&"echo"))
	_words(Vector2(left + 24.0, 91.0), tr("残響"), &"font", &"label_size", dim)
	_words(Vector2(left + 28.0 + _width(tr("残響"), &"font", &"label_size") + 6.0, 93.0), UIFormat.amount(run.echo), &"title_font", &"key_size", pale)
	# Her boons, the newest at the right; a second row once the first is full.
	var held_boons := run.build.owned()
	var per_row := 5
	for index in held_boons.size():
		var boon := held_boons[index]
		var from_end := held_boons.size() - 1 - index
		var at := Vector2(right - EMBLEM * 0.5 - (from_end % per_row) * (EMBLEM + 6.0), 86.0 + (from_end / per_row) * (EMBLEM + 6.0))
		var emblem := EmblemIcons.texture(boon.emblem)
		if emblem != null:
			draw_texture_rect(emblem, Rect2(at - Vector2.ONE * EMBLEM * 0.5, Vector2.ONE * EMBLEM), false)
		if boon.max_level > 1:
			_words(Vector2(at.x + 4.0, at.y + EMBLEM * 0.5 + 2.0), str(run.build.rank(boon.id)), &"bold_font", &"label_size", pale)
		_zone(Rect2(at - Vector2.ONE * EMBLEM * 0.5, Vector2.ONE * EMBLEM), [&"boon", index])
	if not curses_text.is_empty():
		var rows := 1 + (held_boons.size() - 1) / per_row if not held_boons.is_empty() else 0
		_words(Vector2(left, 122.0 + rows * (EMBLEM + 6.0) - EMBLEM), curses_text, &"bold_font", &"label_size", _colour(&"boss"), HORIZONTAL_ALIGNMENT_RIGHT, STATUS_WIDTH)


# What waits behind the gate turned to, at her left; what it gives, at her
# right.
func _draw_weighing() -> void:
	var point := selected()
	if point == null:
		return
	var told := tell(point)
	var colour := light_of(told)
	var pale := _colour(&"pale")
	var dim := _colour(&"dim")
	var fade := (0.25 + 0.75 * _eased(&"move", UIMotion.GOLD_TIME) if _since(&"move") < 0.6 else 1.0) * _eased(&"open", RISE_TIME)
	# Left: what waits.
	var x := LEFT.position.x
	var y := LEFT.position.y + 20.0
	var heading := tr("待ち受けるもの")
	_words(Vector2(x, y), heading, &"bold_font", &"label_size", _colour(&"boss", fade))
	var after := x + _width(heading, &"bold_font", &"label_size") + 14.0
	var until := LEFT.end.x
	if not told.time.is_empty():
		_words(Vector2(x, y), told.time, &"font", &"label_size", Color(dim, fade), HORIZONTAL_ALIGNMENT_RIGHT, LEFT.size.x)
		until -= _width(told.time, &"font", &"label_size") + 14.0
	HubUI.trail(self, Vector2(after, y - 5.0), Vector2(until, y - 5.0), _colour(&"boss", 0.5 * fade))
	y += 40.0
	if told.event:
		_words(Vector2(x, y), tr("戦闘なし"), &"title_font", &"goal_size", Color(pale, fade))
		_lines(Vector2(x, y + 32.0), told.summary, &"font", &"body_size", Color(dim, fade), LEFT.size.x)
	else:
		for index in 3:
			var at := Vector2(x + 10.0 + index * 24.0, y - 8.0)
			if index < told.danger:
				_lozenge(at, 9.0, _colour(&"boss", fade))
			else:
				_lozenge(at, 9.0, _colour(&"faint", fade), 1.0)
		draw_string(_face(&"title_font"), Vector2(x + 86.0, y), told.goal, HORIZONTAL_ALIGNMENT_LEFT, LEFT.size.x - 86.0, _size(&"goal_size"), Color(pale, fade))
		y += 16.0
		var foes: Array = told.foes
		var each := minf(TILE + 8.0, LEFT.size.x / maxf(1.0, foes.size()))
		for index in foes.size():
			var foe: FoeData = foes[index][0]
			var tile := HubCodex.tile_picture(foe.visual_id, foes[index][1], foe.tint)
			if tile == null:
				continue
			var cell := Rect2(x + index * each, y + TILE - (each - 8.0), each - 8.0, each - 8.0)
			if not foes[index][1]:
				draw_circle(cell.get_center(), cell.size.x * 0.5, Color(1.0, 1.0, 1.0, 0.07 * fade))
			draw_texture_rect(tile, cell, false, Color(1.0, 1.0, 1.0, fade))
		y += 70.0
		var words: String = told.summary
		if told.boss:
			words = tr("%s　%s") % [tr(point.area.boss.epithet), told.summary]
		_lines(Vector2(x, y), words, &"font", &"body_size", Color(dim, fade), LEFT.size.x)
	# Right: what it gives, and where it leads.
	x = RIGHT.position.x
	y = RIGHT.position.y + 20.0
	heading = tr("得るもの")
	var wide := _width(heading, &"bold_font", &"label_size")
	_words(Vector2(RIGHT.end.x - wide, y), heading, &"bold_font", &"label_size", Color(colour, fade))
	HubUI.trail(self, Vector2(RIGHT.end.x - wide - 14.0, y - 5.0), Vector2(x, y - 5.0), Color(colour, 0.5 * fade))
	y += 44.0
	if told.boss:
		_words(Vector2(x, y), tr("この章の踏破"), &"title_font", &"give_size", Color(colour, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
	elif told.event:
		_lines(Vector2(x, y - 6.0), told.reward_words, &"title_font", &"goal_size", Color(colour, fade), RIGHT.size.x, 2, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		var words: String = tr("残響 %s") % UIFormat.amount(told.echo) if told.reward == AreaData.Reward.ECHO else told.reward_words
		_words(Vector2(x, y), words, &"title_font", &"give_size", Color(colour, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
		_sign(Vector2(RIGHT.end.x - _width(words, &"title_font", &"give_size") - 26.0, y - 11.0), 12.0, told.reward, Color(colour, fade))
		if told.reward != AreaData.Reward.ECHO and told.echo > 0:
			_words(Vector2(x, y + 30.0), tr("＋ 残響 %s") % UIFormat.amount(told.echo), &"font", &"body_size", _colour(&"echo", fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
	if told.boss or point.next.is_empty():
		return
	y = RIGHT.position.y + 138.0
	var leads := point.next
	if (leads[0] as RouteMap.Waypoint).area.boss != null:
		_words(Vector2(x, y), tr("その先　ボスへ"), &"bold_font", &"body_size", _colour(&"boss", fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
		return
	var onward := tr("その先　%dつの道") % leads.size()
	_words(Vector2(x, y), onward, &"bold_font", &"body_size", Color(pale, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
	var lost := closes(point).size()
	if lost > 0:
		_words(Vector2(x, y + 24.0), tr("選ぶと %dつの場所へは行けなくなる") % lost, &"font", &"label_size", Color(dim, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
	var at := RIGHT.end.x - _width(onward, &"bold_font", &"body_size") - 28.0
	for index in range(leads.size() - 1, -1, -1):
		var next := tell(leads[index])
		_sign(Vector2(at, y - 5.0), 7.0, next.reward, Color(light_of(next), fade))
		for pip in next.danger:
			_lozenge(Vector2(at - 14.0 - pip * 9.0, y - 5.0), 3.5, _colour(&"boss", fade))
		at -= 26.0 + next.danger * 9.0 + 10.0


# The question at her feet.
func _draw_question() -> void:
	var share := asking()
	if share <= 0.0 or traveling:
		return
	var colour := light_of(tell(selected()))
	_words(Vector2(DESIGN.x * 0.5 - 300.0, 838.0), tr("この道を往く"), &"title_font", &"name_size", _colour(&"pale", share), HORIZONTAL_ALIGNMENT_CENTER, 600.0)
	_words(Vector2(DESIGN.x * 0.5 - 300.0, 862.0), tr("もう一度決定すると出発する"), &"font", &"label_size", Color(colour, share), HORIZONTAL_ALIGNMENT_CENTER, 600.0)
	_zone(Rect2(DESIGN.x * 0.5 - 200.0, 812.0, 400.0, 58.0), [&"go"])


# The boss's epithet and name, risen under its gate while it comes out.
func _draw_boss_title() -> void:
	var boss := (open[0] as RouteMap.Waypoint).area.boss
	if boss == null:
		return
	var since := _since(&"reveal") - REVEAL_DARK
	if since < 0.0:
		return
	var share := clampf(since / COMING_OUT, 0.0, 1.0) * clampf((_reveal_time() - _since(&"reveal")) / REVEAL_FADE, 0.0, 1.0)
	_words(Vector2(DESIGN.x * 0.5 - 500.0, FLOOR + 38.0), tr(boss.epithet), &"lead_font", &"goal_size", Color(_colour(&"boss").lerp(_colour(&"pale"), 0.6), share), HORIZONTAL_ALIGNMENT_CENTER, 1000.0)
	_words(Vector2(DESIGN.x * 0.5 - 500.0, FLOOR + 92.0), tr(boss.display_name), &"title_font", &"boss_size", _colour(&"pale", share), HORIZONTAL_ALIGNMENT_CENTER, 1000.0)


# The gate's light flooding out as she walks into it.
func _draw_flood() -> void:
	var share := clampf(_since(&"go") / TRAVEL_TIME, 0.0, 1.0)
	var colour := light_of(tell(selected())).lerp(Color.WHITE, 0.5)
	_glow(Vector2(gate_x(cursor), FLOOR - GATE.y * 0.4), 200.0 + 1900.0 * smoothstep(0.2, 0.95, share), Color(colour, 0.95 * smoothstep(0.15, 0.75, share)))


# The card under the thread: what an area read there is.
func _draw_card(point: RouteMap.Waypoint) -> void:
	var told := tell(point)
	var colour := light_of(told)
	var pale := _colour(&"pale")
	var dim := _colour(&"dim")
	var spot := thread_spot(point)
	var foes: Array = told.foes
	var summary := _face(&"font").get_multiline_string_size(told.summary, HORIZONTAL_ALIGNMENT_LEFT, CARD_WIDTH - 40.0, _size(&"label_size"), 2, _breaks()).y if not told.summary.is_empty() else 0.0
	var high := 118.0
	if told.event:
		high = 138.0 + _face(&"bold_font").get_multiline_string_size(told.reward_words, HORIZONTAL_ALIGNMENT_LEFT, CARD_WIDTH - 40.0, _size(&"body_size"), 2, _breaks()).y + summary
	elif not told.veiled:
		high = (216.0 if not foes.is_empty() else 162.0) + summary
	var rect := Rect2(clampf(spot.x - CARD_WIDTH * 0.5, EDGE, DESIGN.x - EDGE - CARD_WIDTH), CARD_TOP, CARD_WIDTH, high)
	var face := StyleBoxFlat.new()
	face.bg_color = _colour(&"plate")
	face.border_color = Color(pale, 0.22)
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	draw_style_box(face, rect)
	draw_line(spot + Vector2(0.0, 16.0), Vector2(spot.x, rect.position.y), Color(pale, 0.3), 1.0)
	var left := rect.position.x + 20.0
	var wide := rect.size.x - 40.0
	var y := rect.position.y + 30.0
	_words(Vector2(left, y), told.kind, &"font", &"label_size", dim)
	_words(Vector2(left, y), told.state, &"bold_font", &"label_size", _colour(&"boon"), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y += 36.0
	draw_string(_face(&"title_font"), Vector2(left, y), told.name, HORIZONTAL_ALIGNMENT_LEFT, wide, _size(&"name_size"), pale)
	y += 14.0
	HubUI.hairline(self, Vector2(left, y), Vector2(left + wide, y), Color(pale, 0.35))
	y += 26.0
	if told.veiled:
		_lines(Vector2(left, y), told.goal, &"font", &"body_size", dim, wide)
		return
	if told.event:
		_words(Vector2(left, y), tr("戦闘なし"), &"bold_font", &"label_size", Color(colour))
		y += 26.0
		y += _lines(Vector2(left, y), told.reward_words, &"bold_font", &"body_size", Color(colour), wide) + 8.0
		_lines(Vector2(left, y), told.summary, &"font", &"label_size", dim, wide)
		return
	for index in 3:
		var at := Vector2(left + 8.0 + index * 19.0, y - 5.0)
		if index < told.danger:
			_lozenge(at, 7.0, _colour(&"boss"))
		else:
			_lozenge(at, 7.0, _colour(&"faint"), 1.0)
	_words(Vector2(left, y), told.time, &"font", &"label_size", dim, HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y += 28.0
	if told.boss:
		_words(Vector2(left, y), tr(point.area.boss.epithet), &"lead_font", &"body_size", _colour(&"boss"))
	else:
		_sign(Vector2(left + 8.0, y - 6.0), 8.0, told.reward, colour)
		var words: String = tr("残響 %s") % UIFormat.amount(told.echo) if told.reward == AreaData.Reward.ECHO else told.reward_words
		_words(Vector2(left + 26.0, y), words, &"bold_font", &"note_size", colour)
		if told.reward != AreaData.Reward.ECHO and told.echo > 0:
			_words(Vector2(left, y), tr("＋ 残響 %s") % UIFormat.amount(told.echo), &"font", &"label_size", _colour(&"echo"), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y += 26.0
	draw_string(_face(&"font"), Vector2(left, y), told.goal, HORIZONTAL_ALIGNMENT_LEFT, wide, _size(&"body_size"), pale)
	y += 12.0
	if not foes.is_empty():
		var each := minf(44.0, wide / foes.size())
		for index in foes.size():
			var foe: FoeData = foes[index][0]
			var tile := HubCodex.tile_picture(foe.visual_id, foes[index][1], foe.tint)
			if tile == null:
				continue
			var cell := Rect2(left + index * each, y + 40.0 - (each - 6.0), each - 6.0, each - 6.0)
			if not foes[index][1]:
				draw_circle(cell.get_center(), cell.size.x * 0.5, Color(1.0, 1.0, 1.0, 0.07))
			draw_texture_rect(tile, cell, false)
		y += 54.0
	_lines(Vector2(left, y + 8.0), told.summary, &"font", &"label_size", dim, wide)


# The name of the boon the pointer rests on, under it.
func _draw_tip() -> void:
	if not (_hover is Array and (_hover as Array)[0] == &"boon") or covered or run == null:
		return
	var held_boons := run.build.owned()
	var index: int = (_hover as Array)[1]
	if index < 0 or index >= held_boons.size():
		return
	var boon := held_boons[index]
	var words := tr(boon.display_name) if boon.max_level == 1 else "%s %d" % [tr(boon.display_name), run.build.rank(boon.id)]
	var from_end := held_boons.size() - 1 - index
	var wide := _width(words, &"font", &"label_size") + 24.0
	var right := DESIGN.x - EDGE - (from_end % 5) * (EMBLEM + 6.0)
	var rect := Rect2(minf(right - EMBLEM * 0.5 - wide * 0.5, DESIGN.x - EDGE - wide), 86.0 + (from_end / 5) * (EMBLEM + 6.0) + EMBLEM * 0.5 + 8.0, wide, 30.0)
	_to()
	var face := StyleBoxFlat.new()
	face.bg_color = _colour(&"plate")
	face.border_color = _colour(&"pale", 0.22)
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	draw_style_box(face, rect)
	_words(Vector2(rect.position.x, rect.position.y + 21.0), words, &"font", &"label_size", _colour(&"pale"), HORIZONTAL_ALIGNMENT_CENTER, wide)
