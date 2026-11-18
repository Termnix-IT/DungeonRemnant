class_name RouteGates
extends Control

# The run's choice of the next area, as gates. She stands at a fork with her
# back to the player, and each way open now is a gate before her, lit from
# within in the colour of what it gives (a boon's gold, a heal's green, the
# echo's blue, an event's violet, the boss's red) with what leads it
# standing in the light (RouteStage.leader, an event's object): a dark shape
# until the cursor turns to its gate, and then it is seen, unless it is a
# foe she has not met, which stays a shape (figure_known).
#
# What is told stands where it is looked for, in three steps. Under every
# gate, always: its name, its danger and what it gives, so the ways are
# compared without turning to each. Under the gate turned to, which grows
# and throws its light down the floor to her feet: its goal (an event's
# trade), its foes, and what the ways on from it give. And for whoever wants
# the rest (an area's kind, the time it takes, the echo every clearing
# brings, what its foes are like), the card of the tablet below.
#
# The chapter's whole route is cut into a stone tablet that hangs over the
# hall (RouteTablet): the way walked filled with gold, the ways open as
# jewels in their gates' colours, each area further on by the sign of what
# it gives, the boss a lozenge at its end; the areas the cursor's pick would
# put out of reach go dark on it. Any area on the tablet can be read in full
# (the pointer on it, or Up, which starts on the gate's own area, and the
# arrows): a card under it tells all of it. The boss is kept in the dark
# until her way reaches it; then its gate stands dark a moment, tolls, and it
# comes out with its name.
#
# One light ties the hall together. A gate turned to throws its light out
# over the floor, sends it running down the bronze channel of its causeway
# to the round stone she stands on, and up to its socket on the tablet;
# asked, the grilles of the other gates fall, their causeways and their
# jewels go dark, and the view leans in; going, she walks the causeway into
# the gate while the view follows her through it and the star on the tablet
# walks the groove with her.
#
# Left and right turn from gate to gate, 1-3 turn to one and ask at once,
# Enter (A) asks whether to go (the other gates go dark, and the one word of
# the question stands under the gate) and again goes: she walks into the
# gate and the area is entered (Enter again on the way hurries her). Esc (B)
# takes the question back; with none asked Esc (Start) calls the run's menu.
#
# The page is one focusable control that fills the screen, laid in a design
# space of 1600x900 scaled to its rect. The hall is built of layers behind
# its words: the chapter's painting and a paved floor in perspective, lit
# by the gates (one shader over the whole screen, route_hall.gdshader); the
# gates themselves, each a RouteGateView of painted stone with the place it
# leads to, dust and an iron grille in it; her figure, the fight's rig; and
# a dark pillar at either edge, nearer than all of it. These are seen by a
# camera (a place of the page at the screen's middle, and a zoom) that leans
# in as the question is asked and goes through the gate with her. Over them,
# not moved by the camera, hang the tablet and what the page writes of the
# run; the page draws its words and the card in the colours and faces of the
# theme's Gates type. The keys at the foot are a KeyGuide.

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
const HALL := preload("res://ui/route_map/route_hall.gdshader")
const STONE := preload("res://ui/route_map/route_gate_stone.gdshader")
const PILLAR := "res://art/ui/route/hall_pillar.png"
# The floor: the hall's paving, a causeway's slabs and the round stone the
# causeways meet at; and the slab the card of an area is written on.
const FLAGS := "res://art/ui/route/floor_flags.png"
const ROAD := "res://art/ui/route/road_strip.png"
const DAIS := "res://art/ui/route/floor_dais.png"
const PLATE := "res://art/ui/route/route_plate.png"
# Each chapter's floor: its battle ground (AreaGround's atlases).
const GROUNDS := {&"ash_corridor": 0, &"gale_woods": 4, &"amethyst_mausoleum": 5, &"abyss_of_echoes": 6}
# The line the gates stand on, and how far apart they stand (three of them,
# or fewer).
const FLOOR := 532.0
const GATE_GAP := 400.0
const GATE_GAP_WIDE := 480.0
# Where she stands, and how tall.
const HERO := Vector2(800.0, 872.0)
const HERO_HEIGHT := 104.0
# The pillars nearer than everything: how tall they stand, where their feet
# are, and how far in from the screen's edge their middles stand.
const PILLAR_HEIGHT := 1000.0
const PILLAR_FOOT := 940.0
const PILLAR_IN := -66.0
# What stands under a gate: its name and signs, and under the one turned to
# its goal, its foes' pictures and the ways on, no wider than this; then the
# question's word, this tall.
const BLOCK_WIDTH := 380.0
const NAME_LINE := 44.0
const SIGNS_LINE := 68.0
const BLOCK_TOP := 86.0
const TILE := 36.0
const ONWARD_LINE := 26.0
const QUESTION := Vector2(220.0, 30.0)
# The card of an area read on the tablet: its width, and how far under the
# tablet it hangs.
const CARD_WIDTH := 400.0
const CARD_GAP := 12.0
# The bronze at the slab's ends and along its edges (px of its picture).
const PLATE_SIDE := 30.0
const PLATE_EDGE := 9.0
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
const TRAVEL_TIME := 1.3
# How long a gate's light takes to run down its causeway to her feet, how
# far down it the light of a gate not turned to lies, and how brightly that
# channel shows.
const RUN_TIME := 0.34
# How long her choice takes to run up the channel to the gate, which then
# answers it (its flare, its sparks, its sound).
const SPUR_TIME := 0.2
const REST_RUN := 0.3
const REST_ROAD := 0.16
# A grille falls under this pull (shares of its way a second, squared) and
# is drawn back up in this long; the second to fall waits this long after
# the first; and landing shakes its gate this far for this long.
const GRILLE_PULL := 26.0
const LIFT_TIME := 0.3
const GRILLE_WAIT := 0.07
const LAND_SHAKE := 5.0
const LAND_TIME := 0.3
# The flare a gate gives as it is turned to and as it is chosen, and how
# fast it dies down (a second).
const TURN_FLARE := 0.5
const ASK_FLARE := 0.42
const FLARE_FADE := 2.4
# How fast the view leans toward the gate turned to, and how far the painting
# and the pillars slide for it. The camera: how far it leans to the gate and
# pushes in while the question is asked, how far a landing grille knocks it,
# how far it pushes in as she goes through the gate, how much less the far
# painting follows it, and from what share of her walk the screen goes dark.
const LOOK_TIME := 0.35
const FAR_SLIDE := 12.0
const NEAR_SLIDE := 16.0
const ASK_LEAN := 0.1
const ASK_PUSH := 0.035
const THUMP := 3.5
const PUSH := 2.7
const FAR_FOLLOW := 0.3
const CURTAIN_FROM := 0.74
# Where on the gate's threshold her walk ends, as a share of the way from
# where she stands, and how small the floor's depth makes her there.
const THRESHOLD := 0.8
const FAR_SIZE := 0.7
const REVEAL_DARK := 0.85
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
# The keys are on the tablet, and the area they are on.
var threading := false
var thread_at: RouteMap.Waypoint
# An area on the tablet the pointer reads.
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
# The gates, in the order of `open`.
var gates: Array[RouteGateView] = []
var _max_hp := 1
# How far each gate is turned to (0 to 1), eased every frame.
var _lit: Array[float] = []
# Each gate's grille: how far down it is (0 to 1), how fast it falls, and
# since when it has stood on the threshold (-1: it has not landed).
var _drop: Array[float] = []
var _fall_speed: Array[float] = []
var _landed: Array[float] = []
# The flare each gate gives over its steady light, dying down.
var _flare: Array[float] = []
# How far down its causeway each gate's light has run (0 to 1), eased.
var _run: Array[float] = []
# How far the view leans toward the gate turned to (-1 to 1).
var _look := 0.0
# The camera: the place of the page at the screen's middle, and its zoom.
var _eye := DESIGN * 0.5
var _eye_zoom := 1.0
# The hall behind the words: the painting, floor and light; the layers of
# the gates, her figure and the pillars, as the camera sees them; and what
# hangs before it all, the tablet of the chapter's route.
var _hall: ColorRect
var _stage: Node2D
var _gate_room: Node2D
var _hero_room: Node2D
var _pillars: Array[Sprite2D] = []
var _front: Node2D
var tablet: RouteTablet
# The route whose boss has come out of the dark, and whether its bell has
# been tolled.
var _revealed_route: RouteMap
var _tolled := false
var _hover: Variant = null
var _clock := 0.0
# The steps of her walk heard so far.
var _steps := 0
# The gate chosen has answered the question (its flare and its sparks).
var _answered := true
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
var _slab: StyleBoxTexture
# Each chapter's painting and floor as the hall's shader takes them (with
# their smaller copies for the far and the slanted), made once.
static var _paintings: Dictionary = {}
static var _grounds: Dictionary = {}


func _ready() -> void:
	theme_type_variation = &"Gates"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The hall, behind the page's own words.
	_hall = ColorRect.new()
	_hall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hall.show_behind_parent = true
	var lit := ShaderMaterial.new()
	lit.shader = HALL
	_hall.material = lit
	add_child(_hall)
	_stage = Node2D.new()
	_stage.show_behind_parent = true
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_stage)
	_gate_room = Node2D.new()
	_stage.add_child(_gate_room)
	_hero_room = Node2D.new()
	_stage.add_child(_hero_room)
	_stand_pillars()
	_front = Node2D.new()
	_front.show_behind_parent = true
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_front)
	tablet = RouteTablet.new(self)
	_front.add_child(tablet)
	for pair: Array in [[&"flags", FLAGS], [&"road", ROAD], [&"dais", DAIS]]:
		if ResourceLoader.exists(pair[1]):
			lit.set_shader_parameter(pair[0], load(pair[1]))
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


# A dark pillar at either edge, nearer than the gates: the hall's own stone,
# catching a little of the gates' light on the side turned to them.
func _stand_pillars() -> void:
	if not ResourceLoader.exists(PILLAR):
		return
	var art: Texture2D = load(PILLAR)
	var inward := Gradient.new()
	inward.set_color(0, Color(0.0, 0.0, 0.0))
	inward.set_color(1, Color(0.0, 1.0, 0.0))
	var falls := GradientTexture2D.new()
	falls.gradient = inward
	falls.width = 64
	falls.height = 4
	for side in 2:
		var pillar := Sprite2D.new()
		pillar.texture = art
		pillar.centered = false
		pillar.flip_h = side == 1
		pillar.scale = Vector2.ONE * PILLAR_HEIGHT / art.get_height()
		var stone := ShaderMaterial.new()
		stone.shader = STONE
		stone.set_shader_parameter(&"light_map", falls)
		stone.set_shader_parameter(&"ambient", 0.13)
		stone.set_shader_parameter(&"ambient_tone", Color(0.5, 0.55, 0.72))
		stone.set_shader_parameter(&"heart", Vector2(1.6 if side == 0 else -0.6, 0.5))
		pillar.material = stone
		_stage.add_child(pillar)
		_pillars.append(pillar)


# Places the design space in the rect, and the hall's layers with it.
func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _stage == null:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	_front.position = _origin
	_front.scale = Vector2.ONE * _zoom
	var hall := _hall.material as ShaderMaterial
	hall.set_shader_parameter(&"extent", size)
	hall.set_shader_parameter(&"night", get_theme_color(&"night"))
	hall.set_shader_parameter(&"walked", get_theme_color(&"boon"))
	_see()
	hall.set_shader_parameter(&"art", get_theme_color(&"art"))
	queue_redraw()


# Lays the hall as the camera sees it: the place `_eye` at the screen's
# middle, `_eye_zoom` times larger, knocked aside by `shake` (px of the page).
func _see(shake := Vector2.ZERO) -> void:
	if _stage == null:
		return
	_stage.scale = Vector2.ONE * _zoom * _eye_zoom
	_stage.position = _origin + (DESIGN * 0.5 - _eye * _eye_zoom + shake) * _zoom
	var hall := _hall.material as ShaderMaterial
	hall.set_shader_parameter(&"origin", _stage.position)
	hall.set_shader_parameter(&"zoom", _stage.scale.x)
	hall.set_shader_parameter(&"far_focus", _stage.position + _eye * _stage.scale.x)
	hall.set_shader_parameter(&"far_zoom", 1.0 + (_eye_zoom - 1.0) * FAR_FOLLOW)


# A place of the hall (the design space) on the page, as the camera sees it,
# and a place of the page in the hall.
func seen(at: Vector2) -> Vector2:
	return _stage.position + at * _stage.scale.x


func in_hall(at: Vector2) -> Vector2:
	return (at - _stage.position) / _stage.scale.x


# A chapter's painting with its smaller copies, for the hall to draw it soft.
static func painting_of(chapter: ChapterData) -> Texture2D:
	if not _paintings.has(chapter.id):
		var soft: Texture2D = null
		if chapter.illustration != null:
			var image := chapter.illustration.get_image()
			if image.is_compressed():
				image.decompress()
			image.generate_mipmaps()
			soft = ImageTexture.create_from_image(image)
		_paintings[chapter.id] = soft
	return _paintings[chapter.id]


# A chapter's floor: the block of its battle ground's floor tiles that
# repeats, as one picture the hall lays in perspective.
static func ground_of(chapter: StringName) -> Texture2D:
	if not _grounds.has(chapter):
		var atlas: Texture2D = AreaGround.ATLASES[GROUNDS.get(chapter, 0)]
		var tiles := atlas.get_image()
		if tiles.is_compressed():
			tiles.decompress()
		tiles.convert(Image.FORMAT_RGBA8)
		var cell := AreaGround.PAINTED_CELL
		var period := AreaGround.FLOOR_PERIOD
		var block := Image.create_empty(cell * period, cell * period, false, Image.FORMAT_RGBA8)
		for row in period:
			for column in period:
				var index := AreaGround.FLOOR_START + row * period + column
				block.blit_rect(tiles, Rect2i(index % AreaGround.COLUMNS * cell, index / AreaGround.COLUMNS * cell, cell, cell), Vector2i(column * cell, row * cell))
		block.generate_mipmaps()
		_grounds[chapter] = ImageTexture.create_from_image(block)
	return _grounds[chapter]


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
	_kicks.clear()
	_kick(&"open")
	_quiet = true
	_look = 0.0
	_eye = DESIGN * 0.5
	_eye_zoom = 1.0
	_stage.modulate = Color.WHITE
	_stand_gates()
	_stand_hero()
	tablet.present()
	var hall := _hall.material as ShaderMaterial
	hall.set_shader_parameter(&"painting", painting_of(route.chapter))
	hall.set_shader_parameter(&"ground", ground_of(route.chapter.id))
	if route.chapter.illustration != null:
		hall.set_shader_parameter(&"painting_size", route.chapter.illustration.get_size())
	hall.set_shader_parameter(&"floor_line", FLOOR)
	hall.set_shader_parameter(&"far_line", FLOOR - 78.0)
	hall.set_shader_parameter(&"stand", HERO + Vector2(0.0, 4.0))
	hall.set_shader_parameter(&"dusk", 0.0)
	_see()
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


# A gate for each way open now, the first turned to.
func _stand_gates() -> void:
	for gate in gates:
		gate.free()
	gates.clear()
	_lit.clear()
	_drop.clear()
	_fall_speed.clear()
	_landed.clear()
	_flare.clear()
	_run.clear()
	for index in open.size():
		var point: RouteMap.Waypoint = open[index]
		var told := tell(point)
		var gate := RouteGateView.new()
		_gate_room.add_child(gate)
		gate.setup(route.chapter.id, kind_of(point.area), portrait_of(point.area), _colour(&"shape"))
		gate.colour = light_of(told)
		gate.known = figure_known(point)
		var foe := RouteStage.leader(point.area)
		gate.tone = foe.tint if foe != null and not point.area.is_event() else Color.WHITE
		gate.alive = not point.area.is_event()
		gates.append(gate)
		_lit.append(1.0 if index == 0 else 0.0)
		_run.append(REST_RUN)
		_drop.append(0.0)
		_fall_speed.append(0.0)
		_landed.append(-1.0)
		_flare.append(0.0)
	_lay_gates()


# What a gate is dressed as: its area's kind.
static func kind_of(area: AreaData) -> StringName:
	match area.kind:
		AreaData.Kind.ARENA:
			return RouteGateView.ARENA
		AreaData.Kind.EVENT:
			return RouteGateView.EVENT
		AreaData.Kind.BOSS:
			return RouteGateView.BOSS
	return RouteGateView.BOSS if area.boss != null else RouteGateView.FIELD


# Her figure: the fight's rig with the weapon she carries, her back to the
# player.
func _stand_hero() -> void:
	if hero != null:
		hero.free()
	hero = MIO_RIG.instantiate()
	hero.world_height = HERO_HEIGHT
	_hero_room.add_child(hero)
	if run != null and run.moveset != null and run.moveset.art != null:
		WeaponMount.hold(hero, run.moveset)
	hero.facing = Vector2i.UP
	hero.modulate = Color.WHITE
	hero.show()
	hero.idle()
	_place_hero(HERO, 1.0)


func _place_hero(at: Vector2, share: float) -> void:
	if hero == null:
		return
	hero.position = at
	hero.scale = Vector2.ONE * share


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
		_sound(&"gate_turn", -15.0)
		# The gate answers: a flare of its light, sparks off its threshold,
		# and one sent up to its socket on the tablet.
		if index < gates.size():
			_flare[index] = TURN_FLARE
			if not _quiet:
				gates[index].kindle()
				tablet.send_spark(gate_foot(index) + gates[index].keystone(), selected(), gates[index].colour)
		tablet.turn()
		if threading:
			thread_at = selected()
	queue_redraw()


# Asks whether to go to the gate turned to.
func ask() -> void:
	if traveling or held or revealing or covered or asked or selected() == null:
		return
	asked = true
	_answered = false
	_leave_thread()
	_kick(&"ask")
	_sound(&"ui_open")
	_sound(&"gate_charge", -14.0)
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
	_sound(&"gate_lift", -16.0)
	_hint()


# The pick gone ahead with: she walks into the gate's light, and then it is
# taken. Nothing else is taken on the way.
func go() -> void:
	if traveling or not asked or selected() == null:
		return
	traveling = true
	peek = null
	_kick(&"go")
	_steps = 0
	GameAudio.play(self, &"gate_go", -13.0)
	_hint()


# A key or a click on her way hurries her: the walk jumps on to where the
# screen goes dark.
func hurry() -> void:
	if not traveling:
		return
	var along := _since(&"go") / TRAVEL_TIME
	if along < CURTAIN_FROM:
		_kicks[&"go"] = _clock - TRAVEL_TIME * CURTAIN_FROM


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
	_eye = DESIGN * 0.5
	_eye_zoom = 1.0
	_stage.modulate = Color.WHITE
	(_hall.material as ShaderMaterial).set_shader_parameter(&"dusk", 0.0)
	for gate in gates:
		gate.near = 0.0
		gate.flood = 0.0
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


# How far she has gone on her walk (0 to 1), and how dark the screen has
# gone over it (0 to 1): the layer that holds the page draws that dark.
func going() -> float:
	return clampf(_since(&"go") / TRAVEL_TIME, 0.0, 1.0) if traveling else 0.0


func leaving() -> float:
	return smoothstep(CURTAIN_FROM, 0.98, going())


# How far down the grille of an area's gate is (0 to 1; 0 for an area with
# no gate now).
func grille_of(point: RouteMap.Waypoint) -> float:
	var index := open.find(point)
	return _drop[index] if index >= 0 and index < _drop.size() else 0.0


func theme_colour(item: StringName) -> Color:
	return get_theme_color(item)


# --- Reading the tablet ---

# Up from the gates: the keys go to the tablet, on the gate's own area.
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


# The keys along the tablet: a layer on or back, or the next area of the
# layer; down past a layer's last leaves the tablet.
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
		_flare[index] = maxf(0.0, _flare[index] - delta * FLARE_FADE)
		# Its light runs down its causeway to her feet while it is turned to,
		# and draws back to the gate when it is not (or is shut).
		var far := 1.0 if index == cursor and not revealing else (0.0 if _drop[index] > 0.0 else REST_RUN)
		_run[index] = move_toward(_run[index], far, delta / RUN_TIME)
	_move_grilles(delta)
	# Asked, her choice runs up the channel, and the gate answers it.
	if asked and not _answered and _since(&"ask") >= SPUR_TIME:
		_answered = true
		if cursor < _flare.size():
			_flare[cursor] = ASK_FLARE
			gates[cursor].kindle(true)
	if revealing:
		if not _tolled and _since(&"reveal") >= REVEAL_DARK:
			_tolled = true
			GameAudio.play(self, &"boss", -10.0)
			GameAudio.play(self, &"gate_wake", -13.0)
			if not gates.is_empty():
				_flare[0] = TURN_FLARE * 1.6
				gates[0].kindle()
		if _since(&"reveal") >= _reveal_time():
			_end_reveal()
	if traveling:
		_walk()
		if _since(&"go") >= TRAVEL_TIME:
			take(selected())
			return
	elif hero != null and hero.visible:
		_place_hero(HERO, 1.0)
		hero.modulate = _hero_tone()
		# She looks to the gate turned to.
		var toward := gate_x(cursor) - HERO.x if not open.is_empty() else 0.0
		hero.facing = Vector2i(int(signf(toward)) if absf(toward) > 60.0 else 0, -1)
	_look = lerpf(_look, clampf((gate_x(cursor) - DESIGN.x * 0.5) / GATE_GAP, -1.0, 1.0) if not open.is_empty() else 0.0, minf(1.0, delta / LOOK_TIME * 2.2))
	_aim()
	_lay_gates(delta)
	_light_hall()
	tablet.step(delta)
	queue_redraw()


# Where the camera looks now: leaning in to the gate while the question is
# asked, knocked by a landing grille and by the boss's toll. Her walk aims
# it itself (_walk).
func _aim() -> void:
	if not traveling:
		var leaning := asking() if not held else 0.0
		var middle := DESIGN * 0.5
		if cursor < gates.size():
			_eye = middle.lerp(Vector2(gate_x(cursor), FLOOR - 120.0), ASK_LEAN * leaning)
		else:
			_eye = middle
		_eye_zoom = 1.0 + ASK_PUSH * leaning
	var shake := toll_shake()
	for index in _landed.size():
		shake += _land_shake(index) * (THUMP / LAND_SHAKE)
	_see(shake)


# The grilles: down in the gates not chosen while the question is asked (or
# the page is held behind an event), each falling under its own weight and
# landing with a shake and a knock of dust; drawn back up when it is taken
# back.
func _move_grilles(delta: float) -> void:
	var waited := 0
	for index in _drop.size():
		var shut := (asked or held or traveling) and index != cursor
		if shut:
			var since := 10.0 if held else _since(&"ask")
			if since < waited * GRILLE_WAIT:
				waited += 1
				continue
			waited += 1
			if _drop[index] < 1.0:
				_fall_speed[index] += GRILLE_PULL * delta
				_drop[index] = minf(1.0, _drop[index] + _fall_speed[index] * delta)
				if _drop[index] >= 1.0 and _landed[index] < 0.0:
					_landed[index] = _clock
					gates[index].land()
					_sound(&"gate_shut", -13.0)
		else:
			_fall_speed[index] = 0.0
			_landed[index] = -1.0
			_drop[index] = move_toward(_drop[index], 0.0, delta / LIFT_TIME)


# How far a gate's landing grille shakes it now.
func _land_shake(index: int) -> Vector2:
	if _landed[index] < 0.0:
		return Vector2.ZERO
	var since := _clock - _landed[index]
	if since >= LAND_TIME:
		return Vector2.ZERO
	return Vector2(0.0, sin(since / LAND_TIME * TAU * 3.0) * LAND_SHAKE * (1.0 - since / LAND_TIME))


# Where a gate's foot stands now.
func gate_foot(index: int) -> Vector2:
	return Vector2(gate_x(index), FLOOR + (1.0 - _rise(index)) * 26.0)


# How the hall's own dim light and the gate turned to colour her.
func _hero_tone() -> Color:
	var tone := Color(0.8, 0.83, 0.93)
	if cursor < gates.size():
		tone = tone.lerp(gates[cursor].colour, 0.14 * _lit[cursor])
	return tone


# How much of the words under the gates is left as she walks off over them.
func _words_left() -> float:
	return 1.0 - smoothstep(0.0, 0.22, _since(&"go") / TRAVEL_TIME) if traveling else 1.0


# Tells each gate how it stands, and lays it.
func _lay_gates(delta := 0.0) -> void:
	var along := going()
	var flooding := smoothstep(0.42, 1.0, along)
	for index in gates.size():
		var gate := gates[index]
		gate.lit = _lit[index]
		gate.flare = _flare[index] + (flooding * 0.5 if index == cursor else 0.0)
		gate.drop = _drop[index]
		gate.open_share = 1.0 - smoothstep(0.0, 1.0, _drop[index])
		gate.rise = _rise(index)
		gate.dark = veiled(open[index])
		gate.flood = flooding if index == cursor else 0.0
		gate.near = smoothstep(0.15, 1.0, along) if index == cursor else 0.0
		gate.parted = smoothstep(0.3, 0.72, along) if index == cursor else 0.0
		gate.lean = _look
		gate.aside = clampf((gate_x(index) - DESIGN.x * 0.5) / GATE_GAP, -1.0, 1.0)
		gate.position = gate_foot(index) + _land_shake(index)
		# As she goes through hers, the others fall back into the dark.
		gate.modulate = Color.WHITE if index == cursor else Color.WHITE.lerp(_colour(&"night"), smoothstep(0.2, 0.8, along) * 0.85)
		gate.apply(_clock, delta)
	# The pillars, sliding a little against the view's lean.
	for side in _pillars.size():
		var pillar := _pillars[side]
		var wide := pillar.texture.get_width() * pillar.scale.x
		var middle := PILLAR_IN if side == 0 else DESIGN.x - PILLAR_IN
		# Nearer than the gates, they leave the view faster as it pushes in.
		var parting := (_eye_zoom - 1.0) * 420.0 * (-1.0 if side == 0 else 1.0)
		pillar.position = Vector2(middle - wide * 0.5 - _look * NEAR_SLIDE + parting, PILLAR_FOOT - PILLAR_HEIGHT) + toll_shake() * 0.4
		var stone := pillar.material as ShaderMaterial
		var turned: RouteGateView = gates[cursor] if cursor < gates.size() else null
		stone.set_shader_parameter(&"colour", turned.colour if turned != null else Color.WHITE)
		stone.set_shader_parameter(&"power", (turned.power() if turned != null else 0.0) * 0.16)


# The boss's toll shakes the whole hall.
func toll_shake() -> Vector2:
	if not revealing:
		return Vector2.ZERO
	var since := _since(&"reveal") - REVEAL_DARK
	if since < 0.0 or since >= SHAKE_TIME:
		return Vector2.ZERO
	return Vector2(0.0, sin(since / SHAKE_TIME * TAU * 4.0) * SHAKE * (1.0 - since / SHAKE_TIME))


# Tells the hall's shader what lights it: each gate's place, colour and
# strength, where she stands, and where the words want the light hushed.
func _light_hall() -> void:
	var hall := _hall.material as ShaderMaterial
	var places := PackedFloat32Array([0.0, 0.0, 0.0])
	var halves := PackedFloat32Array([1.0, 1.0, 1.0])
	var powers := PackedFloat32Array([0.0, 0.0, 0.0])
	var tones := PackedColorArray([Color.BLACK, Color.BLACK, Color.BLACK])
	for index in mini(gates.size(), 3):
		places[index] = gate_x(index)
		halves[index] = gates[index].opening().x * 0.5
		powers[index] = gates[index].power() * (1.0 + gates[index].flood * 0.6) * (1.0 if index == cursor else 1.0 - smoothstep(0.2, 0.8, going()))
		tones[index] = gates[index].colour
	# Each gate's causeway and fires, and what stands in it, for its shadow.
	var roads := PackedFloat32Array([0.0, 0.0, 0.0])
	var runs := PackedFloat32Array([0.0, 0.0, 0.0])
	var shades := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var fires := PackedFloat32Array([0.0, 0.0, 0.0])
	var fire_offs := PackedFloat32Array([0.0, 0.0, 0.0])
	var fire_tones := PackedColorArray([Color.BLACK, Color.BLACK, Color.BLACK])
	var asked_share := asking()
	for index in mini(gates.size(), 3):
		var gate := gates[index]
		var mine := index == cursor and not revealing
		roads[index] = gate.rise * (1.0 - _drop[index]) * (lerpf(REST_ROAD, 1.0, _lit[index]) + _flare[index] * 0.8 + (0.5 * asked_share if mine else 0.0)) * (0.0 if gate.dark else 1.0)
		runs[index] = _run[index]
		shades[index] = gate.figure_size() * gate.rise
		fires[index] = gate.fire_power() * gate.rise
		fire_offs[index] = gate.fire_off()
		fire_tones[index] = gate.fire_colour()
		hall.set_shader_parameter([&"shade_0", &"shade_1", &"shade_2"][index], gate.figure.texture)
	hall.set_shader_parameter(&"road_power", roads)
	hall.set_shader_parameter(&"road_fill", runs)
	hall.set_shader_parameter(&"shade_size", shades)
	hall.set_shader_parameter(&"fire_power", fires)
	hall.set_shader_parameter(&"fire_off", fire_offs)
	hall.set_shader_parameter(&"fire_colour", fire_tones)
	# The round stone she stands on takes the light that has reached it.
	var reached := 0.0
	var reached_tone := _colour(&"pale")
	if cursor < gates.size() and not revealing:
		reached = smoothstep(0.86, 1.0, _run[cursor]) * gates[cursor].rise
		reached_tone = gates[cursor].colour
	hall.set_shader_parameter(&"dais_colour", reached_tone)
	hall.set_shader_parameter(&"dais_power", 0.1 + reached * (0.75 + 0.6 * asked_share + _flare[cursor] if cursor < _flare.size() else 0.0))
	hall.set_shader_parameter(&"dusk", smoothstep(0.25, 0.85, going()) * 0.8)
	var spur := _since(&"ask") / SPUR_TIME
	hall.set_shader_parameter(&"spur", Vector2(cursor, spur if asked and spur <= 1.0 else -1.0))
	hall.set_shader_parameter(&"gate_count", mini(gates.size(), 3))
	hall.set_shader_parameter(&"gate_x", places)
	hall.set_shader_parameter(&"gate_half", halves)
	hall.set_shader_parameter(&"gate_power", powers)
	hall.set_shader_parameter(&"gate_colour", tones)
	hall.set_shader_parameter(&"hero", hero.position if hero != null else HERO)
	hall.set_shader_parameter(&"hero_shadow", 1.0 if hero != null and hero.visible else 0.0)
	hall.set_shader_parameter(&"lamp_x", gate_x(cursor) if not open.is_empty() else HERO.x)
	hall.set_shader_parameter(&"drift", _look * FAR_SLIDE)
	hall.set_shader_parameter(&"clock", _clock)
	# The words under the gate turned to.
	var hushed := Rect2()
	var share := 0.0
	if selected() != null and not held and not revealing and cursor < gates.size():
		var foot := gate_foot(cursor)
		hushed = Rect2(foot.x - BLOCK_WIDTH * 0.5, foot.y + 24.0, BLOCK_WIDTH, block_height(selected()) - 24.0 + (QUESTION.y + 8.0) * asking())
		share = _lit[cursor] * _rise(cursor) * _words_left()
	hall.set_shader_parameter(&"hush", Vector4(hushed.position.x, hushed.position.y, hushed.size.x, hushed.size.y))
	hall.set_shader_parameter(&"hush_share", share)
	# The boss's toll: a red flush over it all.
	var flush := _colour(&"flush")
	var flushed := 0.0
	if revealing:
		var since := _since(&"reveal") - REVEAL_DARK
		var swell := COMING_OUT * 0.4
		if since >= 0.0:
			flushed = since / swell if since < swell else maxf(0.0, 1.0 - (since - swell) / COMING_OUT)
	hall.set_shader_parameter(&"flush", Color(flush, flush.a * flushed))


# One moment of her walk: up her causeway to the gate's threshold, smaller
# with the floor's depth and darker against the gate's light, and on into
# the place beyond; the camera goes after her, through the gate, and the
# hall behind falls dark.
func _walk() -> void:
	if hero == null or cursor >= gates.size():
		return
	var along := going()
	var gate := Vector2(gate_x(cursor), FLOOR - 2.0)
	var share := smoothstep(0.0, THRESHOLD, along)
	var within := smoothstep(THRESHOLD, 1.0, along)
	var next := HERO.lerp(gate, share) + Vector2(0.0, -10.0 * within)
	hero.step(next - hero.position)
	_place_hero(next, lerpf(1.0, FAR_SIZE, share) * lerpf(1.0, 0.86, within))
	hero.modulate = _hero_tone().lerp(_colour(&"shape"), smoothstep(0.25, 1.0, share) * 0.92)
	# Her steps on the stone.
	var step := floori(along / 0.19)
	if step > _steps and along < THRESHOLD:
		_steps = step
		GameAudio.play(self, &"step", -17.0 - 2.0 * step)
	var push := along * along * (3.0 - 2.0 * along)
	push *= push
	_eye = (DESIGN * 0.5).lerp(Vector2(gate.x, FLOOR - gates[cursor].opening().y * 0.44), smoothstep(0.0, 0.85, along))
	_eye_zoom = 1.0 + ASK_PUSH + (PUSH - 1.0) * push


func _kick(what: StringName) -> void:
	_kicks[what] = _clock


func _since(what: StringName) -> float:
	return _clock - float(_kicks.get(what, -1000.0))


func _eased(what: StringName, time: float) -> float:
	var share := clampf(_since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


func _breath(period := 2.1) -> float:
	return 0.5 + 0.5 * sin(_clock * TAU / period)


func _sound(cue: StringName, volume := -22.0) -> void:
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, cue, volume)


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
			guide.add_hint("↑", tr("十字の上"), tr("詳細"), enter_thread).focus_mode = Control.FOCUS_NONE
			guide.add_hint("Esc", "START", tr("メニュー"))
		&"asked":
			guide.add_hint("Enter", "A", tr("出発する"))
			guide.add_hint("Esc", "B", tr("やめる"))
		&"thread":
			guide.add_hint(tr("←→↑↓"), tr("十字"), tr("道筋をたどる"))
			guide.add_hint(tr("↓・Esc"), "B", tr("門へ戻る"), _leave_thread).focus_mode = Control.FOCUS_NONE


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
			if traveling:
				hurry()
				return
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
		if event.is_action_pressed(&"ui_accept"):
			hurry()
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


# A place the pointer may be on: in the hall (seen by the camera) or, with
# `hung`, among what hangs before it (the tablet, her boons).
func _zone(rect: Rect2, id: Variant, hung := false) -> void:
	_zones.append([rect, id, hung])


func _zone_at(point: Vector2) -> Variant:
	var hung_at := (point - _origin) / _zoom
	var hall_at := in_hall(point)
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(hung_at if _zones[index][2] else hall_at):
			return _zones[index][1]
	return null


# The zone of a gate, in the page's own space (for the layout's tests).
func gate_rect(index: int) -> Rect2:
	for zone: Array in _zones:
		if zone[1] is Array and zone[1] == [&"gate", index]:
			var rect: Rect2 = zone[0]
			return Rect2(seen(rect.position), rect.size * _stage.scale.x)
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


# Words that stand over the lit floor: with a shade under them.
func _shaded(at: Vector2, words: String, face: StringName, size: StringName, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var shade := Color(_colour(&"night"), 0.85 * minf(1.0, colour.a * 1.7))
	draw_string_outline(_face(face), at + Vector2(0.0, 1.5), words, align, width, _size(size), 5, Color(shade, shade.a * 0.5))
	draw_string(_face(face), at + Vector2(0.0, 1.5), words, align, width, _size(size), shade)
	draw_string(_face(face), at, words, align, width, _size(size), colour)


# How far a line under the gate turned to has come in, and how far it still
# has to settle (px): each a moment after the one above it.
func _line_in(order: int) -> Vector2:
	var since := minf(_since(&"move"), _since(&"open") - RISE_TIME * 0.7)
	var share := clampf((since - 0.05 * order) / 0.18, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - share, 3.0)
	return Vector2(eased, (1.0 - eased) * 8.0)


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


# Where an area lies on the tablet (null: the start).
func thread_spot(point: RouteMap.Waypoint) -> Vector2:
	return tablet.spot(point)


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

# Draws in the hall as the camera sees it, from `at` within it.
func _to(at := Vector2.ZERO) -> void:
	draw_set_transform(seen(at), 0.0, Vector2.ONE * _stage.scale.x)


# Draws among what hangs before the hall (the design space, unmoved by the
# camera), from `at` within it.
func _hung(at := Vector2.ZERO) -> void:
	draw_set_transform(_origin + at * _zoom, 0.0, Vector2.ONE * _zoom)


func _draw() -> void:
	_zones.clear()
	if route == null:
		return
	_to()
	for index in open.size():
		if index != cursor:
			_draw_gate_words(index)
	if selected() != null:
		_draw_gate_words(cursor)
	if revealing:
		_to()
		_draw_boss_title()
	_hung()
	# Each area's place on the tablet is the pointer's to read.
	for index in route.size():
		for point: RouteMap.Waypoint in route.nodes(index):
			var at := tablet.spot(point)
			_zone(Rect2(at - Vector2(18.0, RouteTablet.ROW * 0.5), Vector2(36.0, RouteTablet.ROW)), [&"node", point], true)
	_draw_top()
	var shown := read()
	if shown != null and not covered:
		_hung()
		_draw_card(shown)
	_draw_tip()
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
	RouteSigns.lozenge(self, centre, radius, colour, width)


# A reward's sign: a boon's star, a heal's heart, the echo's ring; an event
# (reward -1) a lozenge with a dot.
func _sign(centre: Vector2, radius: float, reward: int, colour: Color) -> void:
	RouteSigns.reward(self, centre, radius, reward, colour)


# How open a gate is: 1, or going dark while the question is asked of another.
func _open_share(index: int) -> float:
	return 1.0 if index == cursor else 1.0 - asking()


# How far a gate has risen as the page opened.
func _rise(index: int) -> float:
	return _eased(&"open", RISE_TIME + index * RISE_STAGGER)


# The words of a gate: its key on its keystone, its name and signs under its
# threshold, and under the one turned to its goal, its foes and the ways on.
func _draw_gate_words(index: int) -> void:
	if index >= gates.size():
		return
	var point: RouteMap.Waypoint = open[index]
	var told := tell(point)
	var gate := gates[index]
	var colour := light_of(told)
	var lit := _lit[index]
	var open_share := _open_share(index)
	var rise := _rise(index)
	var foot := gate_foot(index)
	var box := gate.box()
	var pale := _colour(&"pale")
	var mine := index == cursor and not held and not revealing
	var under := block_height(point) if mine else SIGNS_LINE + 16.0
	var left := minf(box.position.x, -BLOCK_WIDTH * 0.5 if mine else 0.0)
	var right := maxf(box.end.x, BLOCK_WIDTH * 0.5 if mine else 0.0)
	_zone(Rect2(foot.x + left, foot.y + box.position.y, right - left, -box.position.y + under), [&"gate", index])
	_to(foot)
	# Its key, a rune on its keystone, alight in the gate's colour once it is
	# turned to.
	var key := gate.keystone()
	var alight := (0.3 + 0.7 * lit) * (0.3 + 0.7 * open_share) * rise
	_glow(key, 26.0 + 8.0 * lit, Color(colour, 0.5 * lit * open_share * rise))
	_words(Vector2(key.x - 20.0, key.y + 9.0), str(index + 1), &"title_font", &"key_size", Color(_colour(&"night"), 0.7 * rise), HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	_words(Vector2(key.x - 20.0, key.y + 7.0), str(index + 1), &"title_font", &"key_size", Color(colour.lerp(Color.WHITE, 0.25 + 0.5 * lit), alight), HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	# Its name and signs under the threshold (the boss's own title, while it
	# comes out).
	if not revealing:
		var fade := (0.55 + 0.45 * lit) * (0.3 + 0.7 * open_share) * rise * _words_left()
		_shaded(Vector2(-BLOCK_WIDTH * 0.5, NAME_LINE), told.name, &"title_font", &"name_size", Color(pale, fade), HORIZONTAL_ALIGNMENT_CENTER, BLOCK_WIDTH)
		_draw_signs(Vector2(0.0, SIGNS_LINE), told, fade)
		if mine:
			_draw_block(point, told, foot, lit * rise * _words_left())
	_to()


# What an area's goal line says: a fight's goal, an event's trade.
func _goal_of(told: Dictionary) -> String:
	return told.reward_words if told.event else told.goal


func _goal_height(told: Dictionary) -> float:
	var words := _goal_of(told)
	if words.is_empty():
		return 0.0
	return _face(&"title_font").get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, BLOCK_WIDTH, _size(&"goal_size"), 2, _breaks()).y


# How far under its threshold the words of the gate turned to reach: its
# name and signs, its goal, its foes' pictures and the ways on.
func block_height(point: RouteMap.Waypoint) -> float:
	var told := tell(point)
	var reach := BLOCK_TOP + _goal_height(told)
	if not told.foes.is_empty():
		reach += TILE + 10.0
	if not told.boss and not point.next.is_empty():
		reach += ONWARD_LINE
	return reach + 6.0


# Under the gate turned to (in its own space, `foot` its place on the page):
# its goal or trade, its foes as pictures, what the ways on from it give,
# and, asked, the question's one word.
func _draw_block(point: RouteMap.Waypoint, told: Dictionary, foot: Vector2, share: float) -> void:
	var colour := light_of(told)
	var pale := _colour(&"pale")
	var half := BLOCK_WIDTH * 0.5
	var y := BLOCK_TOP
	# Each line comes in a moment after the one above it, settling upward.
	var goal := _goal_of(told)
	if not goal.is_empty():
		var come := _line_in(0)
		var ink := Color(colour if told.event else pale, share * come.x)
		var at := Vector2(-half, y + come.y + _face(&"title_font").get_ascent(_size(&"goal_size")))
		draw_multiline_string_outline(_face(&"title_font"), at + Vector2(0.0, 1.5), goal, HORIZONTAL_ALIGNMENT_CENTER, BLOCK_WIDTH, _size(&"goal_size"), 2, 5, Color(_colour(&"night"), 0.45 * ink.a), _breaks())
		draw_multiline_string(_face(&"title_font"), at, goal, HORIZONTAL_ALIGNMENT_CENTER, BLOCK_WIDTH, _size(&"goal_size"), 2, ink, _breaks())
		y += _goal_height(told)
	var foes: Array = told.foes
	if not foes.is_empty():
		var come := _line_in(1)
		var each := minf(TILE + 6.0, BLOCK_WIDTH / foes.size())
		var from := -each * foes.size() * 0.5
		for index in foes.size():
			var foe: FoeData = foes[index][0]
			var tile := HubCodex.tile_picture(foe.visual_id, foes[index][1], foe.tint)
			if tile == null:
				continue
			var cell := Rect2(from + index * each + 3.0, y + come.y + 4.0 + TILE - (each - 6.0), each - 6.0, each - 6.0)
			# Each stands on a small shade, so it reads over the lit stone.
			_glow(Vector2(cell.get_center().x, cell.end.y - 2.0), cell.size.x * 0.62, Color(_colour(&"night"), 0.55 * share * come.x), 0.3)
			if not foes[index][1]:
				draw_circle(cell.get_center(), cell.size.x * 0.5, Color(1.0, 1.0, 1.0, 0.07 * share * come.x))
			draw_texture_rect(tile, cell, false, Color(1.0, 1.0, 1.0, share * come.x))
		y += TILE + 10.0
	if not told.boss and not point.next.is_empty():
		var come := _line_in(2)
		_draw_onward(Vector2(0.0, y + 12.0 + come.y), point.next, share * come.x)
		y += ONWARD_LINE
	# The question, once asked: its one word, struck in under the rest, and
	# the place the pointer goes on from.
	var asked_share := asking()
	if asked_share > 0.0 and not traveling:
		var struck := 1.0 + 0.16 * (1.0 - asked_share) if asked else 1.0
		var rect := Rect2(-QUESTION.x * 0.5 * struck, y + 8.0 - QUESTION.y * (struck - 1.0) * 0.5, QUESTION.x * struck, QUESTION.y * struck)
		_glow(rect.get_center(), QUESTION.x * 0.75, Color(colour, 0.2 * asked_share * (0.7 + 0.3 * _breath(1.4))), 0.34)
		var face := StyleBoxFlat.new()
		face.bg_color = Color(_colour(&"night").lerp(colour, 0.22), 0.86 * asked_share)
		face.border_color = Color(colour, asked_share)
		face.set_border_width_all(1)
		face.set_corner_radius_all(3)
		draw_style_box(face, rect)
		for end in [-1.0, 1.0]:
			HubUI.mark(self, Vector2(rect.get_center().x + end * rect.size.x * 0.5, rect.get_center().y), 5.0, Color(colour, asked_share))
		_words(Vector2(rect.position.x, rect.get_center().y + 7.0), tr("この道を往く"), &"title_font", &"key_size", Color(pale, asked_share), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		_zone(Rect2(foot + rect.position, rect.size), [&"go"])


# What the ways on from an area give, in a row round `centre`: each way's
# danger and sign, or the boss.
func _draw_onward(centre: Vector2, leads: Array, fade: float) -> void:
	var label := tr("その先")
	var to_boss: bool = (leads[0] as RouteMap.Waypoint).area.boss != null
	var wide := _width(label, &"font", &"label_size") + 14.0
	if to_boss:
		wide += 20.0 + _width(tr("ボス"), &"bold_font", &"label_size")
	else:
		for next_point: RouteMap.Waypoint in leads:
			wide += tell(next_point).danger * 9.0 + 34.0
		wide -= 12.0
	var x := centre.x - wide * 0.5
	_shaded(Vector2(x, centre.y + 5.0), label, &"font", &"label_size", _colour(&"dim", fade))
	x += _width(label, &"font", &"label_size") + 14.0
	if to_boss:
		_lozenge(Vector2(x + 6.0, centre.y), 6.0, _colour(&"boss", fade))
		_words(Vector2(x + 20.0, centre.y + 5.0), tr("ボス"), &"bold_font", &"label_size", _colour(&"boss", fade))
		return
	for next_point: RouteMap.Waypoint in leads:
		var next := tell(next_point)
		for pip in next.danger:
			_lozenge(Vector2(x + 3.5 + pip * 9.0, centre.y), 3.5, _colour(&"boss", fade))
		x += next.danger * 9.0 + 4.0
		_sign(Vector2(x + 8.0, centre.y), 7.0, next.reward, Color(light_of(next), fade))
		x += 30.0

# What an area gives, in a word beside its sign: the reward (the echo with
# its amount), an event, the boss.
func _gives(told: Dictionary) -> String:
	if told.veiled:
		return ""
	if told.boss:
		return tr("ボス")
	if told.event:
		return told.kind
	if told.reward == AreaData.Reward.ECHO:
		return tr("残響 %s") % UIFormat.amount(told.echo)
	return told.reward_words


# How wide an area's signs stand in a row.
func _signs_width(told: Dictionary) -> float:
	var gives := _gives(told)
	var danger: int = told.danger
	var wide := 45.0 if danger > 0 else 0.0
	if not gives.is_empty():
		wide += (12.0 if danger > 0 else 0.0) + (0.0 if told.boss else 22.0) + _width(gives, &"bold_font", &"label_size")
	return wide


# An area's signs in a row round `centre`: its danger, then what it gives by
# its sign and its word.
func _draw_signs(centre: Vector2, told: Dictionary, fade: float) -> void:
	var colour := light_of(told)
	var gives := _gives(told)
	var danger: int = told.danger
	var x := centre.x - _signs_width(told) * 0.5
	if danger > 0:
		for index in 3:
			if index < danger:
				_lozenge(Vector2(x + 5.0, centre.y), 5.5, _colour(&"boss", fade))
			else:
				_lozenge(Vector2(x + 5.0, centre.y), 5.0, _colour(&"faint", fade), 1.0)
			x += 15.0
	if gives.is_empty():
		return
	if danger > 0:
		x += 12.0
	if not told.boss:
		_sign(Vector2(x + 7.0, centre.y), 7.0, told.reward, Color(colour, fade))
		x += 22.0
	_shaded(Vector2(x, centre.y + 5.0), gives, &"bold_font", &"label_size", Color(colour, fade))


# The chapter at the top left; her health, level, echo and boons at the top
# right: plain words, as they must be read at a glance, with the hall's own
# ornament (the tapering line and the small star) to hold them.
func _draw_top() -> void:
	var pale := _colour(&"pale")
	var dim := _colour(&"dim")
	var gold := _colour(&"boon")
	var come := _eased(&"open", RISE_TIME)
	# Where along the chapter she is, the tablet tells.
	var number := Chapters.short_name(route.chapter)
	_shaded(Vector2(EDGE, 46.0), number, &"font", &"label_size", dim)
	var x := EDGE + _width(number, &"font", &"label_size") + 12.0
	_shaded(Vector2(x, 48.0), Chapters.title(route.chapter), &"title_font", &"name_size", pale)
	if run.step > 0:
		_shaded(Vector2(x + _width(Chapters.title(route.chapter), &"title_font", &"name_size") + 14.0, 46.0), tr("段階%d") % run.step, &"font", &"label_size", dim)
	HubUI.mark(self, Vector2(EDGE + 4.0, 61.0), 4.0, Color(gold, 0.9 * come))
	HubUI.hairline(self, Vector2(EDGE + 14.0, 61.0), Vector2(EDGE + 14.0 + 250.0 * come, 61.0), Color(gold, 0.55))
	if not note_text.is_empty():
		_shaded(Vector2(EDGE, 84.0), note_text, &"font", &"label_size", Color(dim, come))
	var right := DESIGN.x - EDGE
	var left := right - STATUS_WIDTH
	var hp := run.hp if run.hp > 0 else _max_hp
	_shaded(Vector2(left, 44.0), "HP", &"bold_font", &"label_size", _colour(&"boss"))
	_shaded(Vector2(left + 30.0, 46.0), str(hp), &"title_font", &"name_size", pale)
	_shaded(Vector2(left + 30.0 + _width(str(hp), &"title_font", &"name_size") + 6.0, 46.0), "/ %d" % _max_hp, &"lead_font", &"body_size", dim)
	_shaded(Vector2(left, 46.0), "Lv %d" % run.progression.level, &"title_font", &"key_size", pale, HORIZONTAL_ALIGNMENT_RIGHT, STATUS_WIDTH)
	_draw_gauge(Rect2(left, 55.0, STATUS_WIDTH, 8.0), clampf(hp / float(_max_hp), 0.0, 1.0), _colour(&"boss"))
	_sign(Vector2(left + 8.0, 88.0), 7.0, AreaData.Reward.ECHO, _colour(&"echo"))
	_shaded(Vector2(left + 24.0, 93.0), tr("残響"), &"font", &"label_size", dim)
	_shaded(Vector2(left + 28.0 + _width(tr("残響"), &"font", &"label_size") + 6.0, 95.0), UIFormat.amount(run.echo), &"title_font", &"key_size", pale)
	# Her boons, the newest at the right; a second row once the first is full.
	var held_boons := run.build.owned()
	var per_row := 5
	for index in held_boons.size():
		var boon := held_boons[index]
		var from_end := held_boons.size() - 1 - index
		var at := Vector2(right - EMBLEM * 0.5 - (from_end % per_row) * (EMBLEM + 6.0), 88.0 + (from_end / per_row) * (EMBLEM + 6.0))
		var emblem := EmblemIcons.texture(boon.emblem)
		if emblem != null:
			draw_texture_rect(emblem, Rect2(at - Vector2.ONE * EMBLEM * 0.5, Vector2.ONE * EMBLEM), false)
		if boon.max_level > 1:
			_shaded(Vector2(at.x + 4.0, at.y + EMBLEM * 0.5 + 2.0), str(run.build.rank(boon.id)), &"bold_font", &"label_size", pale)
		_zone(Rect2(at - Vector2.ONE * EMBLEM * 0.5, Vector2.ONE * EMBLEM), [&"boon", index], true)
	if not curses_text.is_empty():
		var rows := 1 + (held_boons.size() - 1) / per_row if not held_boons.is_empty() else 0
		_shaded(Vector2(left, 124.0 + rows * (EMBLEM + 6.0) - EMBLEM), curses_text, &"bold_font", &"label_size", _colour(&"boss"), HORIZONTAL_ALIGNMENT_RIGHT, STATUS_WIDTH)


# A gauge: a dark trough between two fine lines with a lozenge at either
# end, filled to `share` in `colour`, brighter along its top and at its head.
func _draw_gauge(rect: Rect2, share: float, colour: Color) -> void:
	var pale := _colour(&"pale")
	draw_rect(rect, Color(_colour(&"night"), 0.82))
	var full := Rect2(rect.position, Vector2(rect.size.x * share, rect.size.y))
	if full.size.x > 0.0:
		_fall(full, colour.lerp(Color.WHITE, 0.24), colour.darkened(0.3))
		draw_rect(Rect2(full.position, Vector2(full.size.x, 1.5)), Color(1.0, 1.0, 1.0, 0.3))
		draw_rect(Rect2(full.end.x - 2.0, rect.position.y, 2.0, rect.size.y), colour.lerp(Color.WHITE, 0.6))
	for y: float in [rect.position.y - 1.0, rect.end.y]:
		draw_rect(Rect2(rect.position.x, y, rect.size.x, 1.0), Color(pale, 0.28))
	for x: float in [rect.position.x - 5.0, rect.end.x + 5.0]:
		_lozenge(Vector2(x, rect.get_center().y), 4.0, Color(pale, 0.5))


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


# A slab like the tablet's own, for what is written before the hall: the
# card of an area, the name of a boon.
func _plate(rect: Rect2) -> void:
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	shade.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	shade.shadow_size = 16
	shade.shadow_offset = Vector2(0.0, 5.0)
	shade.draw_center = false
	draw_style_box(shade, rect.grow(-4.0))
	if _slab == null and ResourceLoader.exists(PLATE):
		_slab = StyleBoxTexture.new()
		_slab.texture = load(PLATE)
		_slab.texture_margin_left = PLATE_SIDE
		_slab.texture_margin_right = PLATE_SIDE
		_slab.texture_margin_top = PLATE_EDGE
		_slab.texture_margin_bottom = PLATE_EDGE
		_slab.modulate_color = Color(0.6, 0.6, 0.64)
	if _slab != null:
		draw_style_box(_slab, rect)
		draw_rect(rect.grow_individual(-PLATE_SIDE + 4.0, -PLATE_EDGE, -PLATE_SIDE + 4.0, -PLATE_EDGE), Color(_colour(&"plate"), 0.78))
	else:
		draw_rect(rect, _colour(&"plate"))


# The card under the tablet: what an area read there is.
func _draw_card(point: RouteMap.Waypoint) -> void:
	var told := tell(point)
	var colour := light_of(told)
	var pale := _colour(&"pale")
	var dim := _colour(&"dim")
	var spot := thread_spot(point)
	var foes: Array = told.foes
	var inner := CARD_WIDTH - (PLATE_SIDE + 8.0) * 2.0
	var summary := _face(&"font").get_multiline_string_size(told.summary, HORIZONTAL_ALIGNMENT_LEFT, inner, _size(&"label_size"), 2, _breaks()).y if not told.summary.is_empty() else 0.0
	var high := 118.0
	if told.event:
		high = 138.0 + _face(&"bold_font").get_multiline_string_size(told.reward_words, HORIZONTAL_ALIGNMENT_LEFT, inner, _size(&"body_size"), 2, _breaks()).y + summary
	elif not told.veiled:
		high = (232.0 if not foes.is_empty() else 178.0) + summary
	var top := tablet.rect().end.y + CARD_GAP
	var rect := Rect2(clampf(spot.x - CARD_WIDTH * 0.5, EDGE, DESIGN.x - EDGE - CARD_WIDTH), top, CARD_WIDTH, high + 8.0)
	_plate(rect)
	# It hangs from its area's socket.
	HubUI.hairline(self, Vector2(spot.x, rect.position.y + 2.0), spot + Vector2(0.0, 18.0), Color(colour, 0.8), 1.5)
	var left := rect.position.x + PLATE_SIDE + 8.0
	var wide := rect.size.x - (PLATE_SIDE + 8.0) * 2.0
	var y := rect.position.y + 34.0
	_words(Vector2(left, y), told.kind, &"font", &"label_size", dim)
	_words(Vector2(left, y), told.state, &"bold_font", &"label_size", _colour(&"boon"), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y += 36.0
	draw_string(_face(&"title_font"), Vector2(left, y), told.name, HORIZONTAL_ALIGNMENT_LEFT, wide, _size(&"name_size"), pale)
	y += 14.0
	HubUI.hairline(self, Vector2(left, y), Vector2(left + wide, y), Color(colour, 0.7))
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
	var rect := Rect2(minf(right - EMBLEM * 0.5 - wide * 0.5, DESIGN.x - EDGE - wide), 88.0 + (from_end / 5) * (EMBLEM + 6.0) + EMBLEM * 0.5 + 8.0, wide, 30.0)
	_hung()
	var face := StyleBoxFlat.new()
	face.bg_color = _colour(&"plate")
	face.border_color = _colour(&"boon", 0.5)
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	face.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	face.shadow_size = 8
	draw_style_box(face, rect)
	_words(Vector2(rect.position.x, rect.position.y + 21.0), words, &"font", &"label_size", _colour(&"pale"), HORIZONTAL_ALIGNMENT_CENTER, wide)
