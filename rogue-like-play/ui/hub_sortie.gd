class_name HubSortie
extends Control

# Where to set out, as a vista: the chosen chapter's painting is the whole
# screen, as if she stood at its gate, and it is a place: its fires flicker,
# the light at its way in swells and falls, mist drifts through it and motes
# float in its air (vista.gdshader; what lives where in each painting is
# PLACES). Turning to another chapter turns the head: one place slides off
# as the next comes in from the side turned to. The chapter's number and
# name stand large at the lower left over a dark fall, with how far it has
# been taken (未踏, 第2層まで, 踏破 2回, or 封印中) and what it is. A row of
# small views along the top tells where among the chapters she is: each is
# its painting seen through a stone window (vista_view.gdshader), the one
# turned to lit and larger, each marked once cleared and chained under a
# seal until it opens. Along the foot run the way, the record and the boss
# (unnamed until met, as in the encyclopedia), the foes that come in it
# (pictured when met and dark shapes when not) and what she carries. At the
# right stand the difficulty step, once the ending has opened the steps
# (the step, what it adds and the echo it brings back), and the one action,
# a crest button (CrestButton) with the departure's medallion that sets out.
# A sealed chapter is dark and still under its seal; it can be chosen to
# read what opens it, not set out for.
#
# Setting out is shown by the game's cover (SceneTransition), which takes
# the painting as it stands here (outlook()) and goes into its way in.
#
# Left and right (the d-pad, the left stick) and the wheel turn from chapter
# to chapter, Q / E (LB / RB) change the step, and Enter (A) sets out at
# once. The pointer chooses a chapter by its view or the arrows at the
# sides, and sets out with the button.
#
# The page is one focusable control that draws itself in a design space of
# 1520x686 scaled to its rect, in the colours and faces of the theme's
# Vista type. The painting and its shades are drawn by a child that covers
# the whole screen, behind the hub's title and keys; the button is a node.
# The pointer acts through zones named while drawing, which also carry the
# tooltips (a foe's name, what a step's constraints are).

signal departure_requested(chapter: ChapterData)
# The chosen chapter, when it is open: the lobby shows it next.
signal chapter_chosen(chapter: ChapterData)
# The difficulty step chosen to set out at.
signal step_chosen(step: int)

const DESIGN := Vector2(1520.0, 686.0)
# Where across each chapter's painting its small view looks: on the way in,
# the lit stair or gate each painting is drawn round.
const VIEW_FOCUS := {
	&"ash_corridor": 0.8,
	&"gale_woods": 0.84,
	&"amethyst_mausoleum": 0.73,
	&"abyss_of_echoes": 0.74,
}
# What lives in each chapter's painting, in the painting's UV: the way in
# (the gate, stair or door it is drawn round) with how far its light reaches
# and that light's colour, its fires (where each burns, and how far its
# light reaches as a share of the painting's height), its mist (the alpha is
# how thick), and the motes in its air (their colour, and the way they
# drift).
const PLACES := {
	&"ash_corridor": {
		way = Vector2(0.8, 0.46), reach = 0.17, light = Color(1.0, 0.72, 0.38),
		fires = [Vector3(0.755, 0.49, 0.06), Vector3(0.872, 0.49, 0.06), Vector3(0.807, 0.44, 0.045)],
		mist = Color(0.72, 0.76, 0.84, 0.2), motes = Color(0.94, 0.88, 0.72), drift = Vector2(0.25, -1.0),
	},
	&"gale_woods": {
		way = Vector2(0.855, 0.45), reach = 0.17, light = Color(1.0, 0.74, 0.4),
		fires = [Vector3(0.773, 0.49, 0.065), Vector3(0.912, 0.47, 0.065)],
		mist = Color(0.66, 0.8, 0.8, 0.22), motes = Color(0.8, 0.84, 0.5), drift = Vector2(-1.0, 0.45),
	},
	&"amethyst_mausoleum": {
		way = Vector2(0.735, 0.6), reach = 0.14, light = Color(0.6, 1.0, 0.8),
		fires = [Vector3(0.175, 0.4, 0.07), Vector3(0.068, 0.52, 0.05), Vector3(0.545, 0.17, 0.06), Vector3(0.95, 0.18, 0.05), Vector3(0.965, 0.46, 0.06), Vector3(0.89, 0.61, 0.05)],
		mist = Color(0.62, 0.56, 0.78, 0.18), motes = Color(0.8, 0.68, 1.0), drift = Vector2(0.0, -1.0),
	},
	&"abyss_of_echoes": {
		way = Vector2(0.775, 0.2), reach = 0.15, light = Color(1.0, 0.82, 0.45),
		fires = [],
		mist = Color(0.42, 0.36, 0.5, 0.16), motes = Color(1.0, 0.84, 0.48), drift = Vector2(0.1, -1.0),
	},
}
const FIRES := 6
const VISTA_SHADER := preload("res://ui/vista/vista.gdshader")
const VIEW_SHADER := preload("res://ui/vista/vista_view.gdshader")
const VIEW_FRAME: Texture2D = preload("res://art/hub/sortie/view_frame.png")
const VIEW_HOLE: Texture2D = preload("res://art/hub/sortie/view_hole.png")
const VIEW_SEAL: Texture2D = preload("res://art/hub/sortie/view_seal.png")
const STEP_SLATE: Texture2D = preload("res://art/ui/route/route_plate.png")
const MEDAL: Texture2D = preload("res://art/hub/lobby/icon_departure.png")
const UNKNOWN_NAME := "？？？"
# A chapter's view: the stone window's size, how much of the painting's
# height is behind it, how much larger the one turned to stands, how bright
# the others and the sealed ones are, and how fast a view answers.
const VIEW := Vector2(200.0, 101.0)
const VIEW_GAP := 18.0
const VIEW_TOP := 2.0
const VIEW_CROP := 0.56
const VIEW_CHOSEN := 1.13
const VIEW_REST := 0.5
const VIEW_SEALED := 0.4
const VIEW_EASE := 14.0
const SEAL_SHARE := 0.66
# Where the words begin at the left, and the column at the right.
const EDGE := 56.0
const COLUMN := 1044.0
const COLUMN_WIDTH := 436.0
# The button's room: a crest button is 84 tall, its plate in the middle.
const BUTTON := Rect2(COLUMN, 496.0, COLUMN_WIDTH, 84.0)
const STEP_PLATE := Rect2(COLUMN - 20.0, 372.0, COLUMN_WIDTH + 40.0, 112.0)
const TITLE_ROOM := 900.0
const TILE := 46.0
const SEAL := Vector2(760.0, 236.0)
const TURN_TIME := 0.32
const DEPART_TIME := 0.9
const REFUSE_TIME := 0.3
# The painting runs this far past the screen's edges, to cover it as the
# page slides in.
const VISTA_MARGIN := 40.0

var meta: MetaProgress
var selected := 0
var step := 0
# What the page tells of the chosen chapter: {number, name, state, open,
# cleared, description, route, record, boss, opener, steps, step_note,
# step_echo, step_hint, constraints}.
var told := {}
# The foes that come in it, [picture, name, met] each, and what she
# carries, [emblem key, name] each.
var foes: Array = []
var gear: Array = []
var action_button: Button
var _vista: ColorRect
var _look: ShaderMaterial
var _motes: CPUParticles2D
# The chapters' views, their seals, and how far each is the one turned to.
var _views: Array[TextureRect] = []
var _seals: Array[TextureRect] = []
var _view_share: Array[float] = []
var _step_plate: StyleBoxTexture
# The chapter the cursor came from, and the one set out for (-1: none).
var _from := 0
var _departed := -1
var _clock := 0.0
var _kicks := {}
# [rect, id or null, tooltip] of every place the pointer can act on or ask about.
var _zones: Array = []
var _hover: Variant = null
var _origin := Vector2.ZERO
var _zoom := 1.0
var _quiet := true


func _ready() -> void:
	theme_type_variation = &"Vista"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_look = ShaderMaterial.new()
	_look.shader = VISTA_SHADER
	_look.set_shader_parameter(&"shade", get_theme_color(&"shade"))
	_vista = ColorRect.new()
	_vista.name = "Vista"
	_vista.color = get_theme_color(&"night")
	_vista.material = _look
	_vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vista.show_behind_parent = true
	add_child(_vista)
	_build_motes()
	_build_views()
	_step_plate = StyleBoxTexture.new()
	_step_plate.texture = STEP_SLATE
	_step_plate.set_texture_margin_all(30.0)
	_step_plate.texture_margin_left = 44.0
	_step_plate.texture_margin_right = 44.0
	_step_plate.modulate_color = get_theme_color(&"slate")
	# Setting out is this screen's moment: the crest with the departure's
	# medallion. The focus stays on the page, so Enter there and the button are one.
	var crest := CrestButton.new()
	crest.medal = MEDAL
	action_button = crest
	action_button.name = "SetOut"
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(set_out)
	add_child(action_button)
	UIMotion.bind_buttons(self)
	resized.connect(_fit)
	theme_changed.connect(_fit)
	visibility_changed.connect(_fit)
	get_viewport().size_changed.connect(_fit.call_deferred)
	_fit()


# Places the design space in the rect, and the painting and the button with it.
func _fit() -> void:
	if _vista == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	# The painting covers the screen, wherever in it the page stands.
	var screen := Rect2(Vector2.ZERO, size)
	if is_inside_tree():
		screen = get_global_transform().affine_inverse() * get_viewport_rect()
	_vista.position = screen.position - Vector2.ONE * VISTA_MARGIN
	_vista.size = screen.size + Vector2.ONE * VISTA_MARGIN * 2.0
	action_button.position = _origin + BUTTON.position * _zoom
	action_button.size = BUTTON.size * _zoom
	_motes.position = _vista.size * 0.5
	_motes.emission_rect_extents = _vista.size * 0.5
	_place_views()
	queue_redraw()


# Motes in the place's air: dust, leaves, sparks, by its chapter.
func _build_motes() -> void:
	_motes = CPUParticles2D.new()
	_motes.amount = 34
	_motes.lifetime = 8.0
	_motes.preprocess = 8.0
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.spread = 34.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 8.0
	_motes.initial_velocity_max = 26.0
	_motes.scale_amount_min = 1.4
	_motes.scale_amount_max = 3.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 0.5))
	fade.add_point(0.75, Color(1, 1, 1, 0.5))
	_motes.color_ramp = fade
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_motes.material = additive
	_vista.add_child(_motes)


# A stone window for each chapter, its painting behind it and its seal over it.
func _build_views() -> void:
	for chapter in Chapters.ALL:
		var look := ShaderMaterial.new()
		look.shader = VIEW_SHADER
		look.set_shader_parameter(&"place", chapter.illustration)
		look.set_shader_parameter(&"hole", VIEW_HOLE)
		look.set_shader_parameter(&"glow_colour", get_theme_color(&"gold"))
		if chapter.illustration != null:
			var full := chapter.illustration.get_size()
			var part := Vector2(full.y * VIEW_CROP * VIEW.aspect(), full.y * VIEW_CROP)
			var from := (full - part) * Vector2(VIEW_FOCUS.get(chapter.id, 0.5), 0.5)
			look.set_shader_parameter(&"window", Vector4(from.x / full.x, from.y / full.y, part.x / full.x, part.y / full.y))
		var view := TextureRect.new()
		view.name = "View%d" % (_views.size() + 1)
		view.texture = VIEW_FRAME
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_SCALE
		view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		view.material = look
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(view)
		var seal := TextureRect.new()
		seal.name = "Seal"
		seal.texture = VIEW_SEAL
		seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(seal)
		_views.append(view)
		_seals.append(seal)
		_view_share.append(0.0)


# Where a chapter's view stands in the design space.
func _view_rect(index: int) -> Rect2:
	var count := Chapters.ALL.size()
	var left := (DESIGN.x - count * VIEW.x - (count - 1) * VIEW_GAP) * 0.5
	return Rect2(Vector2(left + index * (VIEW.x + VIEW_GAP), VIEW_TOP), VIEW)


# The views in their places: the one turned to larger and lit, the sealed
# ones dim under their chains.
func _place_views() -> void:
	for index in _views.size():
		var view := _views[index]
		var rect := _view_rect(index)
		var share := _view_share[index]
		var open := meta != null and meta.chapter_open(Chapters.ALL[index])
		view.position = _origin + rect.position * _zoom
		view.size = rect.size * _zoom
		view.pivot_offset = view.size * 0.5
		view.scale = Vector2.ONE * lerpf(1.0, VIEW_CHOSEN, share)
		var bright := lerpf(VIEW_REST, 1.0, maxf(share, 0.55 if _hovered(&"chapter", index) else 0.0))
		var look := view.material as ShaderMaterial
		look.set_shader_parameter(&"bright", bright * (1.0 if open else VIEW_SEALED))
		look.set_shader_parameter(&"glow", share)
		_seals[index].visible = not open
		_seals[index].size = view.size * SEAL_SHARE
		_seals[index].position = (view.size - _seals[index].size) * 0.5 + Vector2(0.0, view.size.y * 0.04)


# --- What it tells ---

func refresh(current: MetaProgress, chapter: ChapterData, at_step: int = 0) -> void:
	meta = current
	step = clampi(at_step, 0, meta.steps_open())
	selected = maxi(0, Chapters.ALL.find(chapter))
	_from = selected
	_departed = -1
	_tell()


func chosen() -> ChapterData:
	return Chapters.ALL[selected]


# How far a chapter has been taken, as its view says it: 封印中, 未踏 or its record.
func state_of(index: int) -> String:
	var chapter := Chapters.ALL[index]
	if meta == null or not meta.chapter_open(chapter):
		return tr("封印中")
	var record := Chapters.record(meta, chapter)
	return tr("未踏") if record == tr("なし") else record


# What the chosen chapter is, how far it has been taken, what waits in it,
# the step, and the button to set out (or why it cannot be).
func _tell() -> void:
	if meta == null or action_button == null:
		return
	var chapter := chosen()
	var open := meta.chapter_open(chapter)
	var key := Chapters.find(chapter.unlocked_by)
	var opener := tr("%sを踏破すると開く") % (Chapters.short_name(key) if key != null else tr("前の章"))
	var boss := chapter.boss.boss if chapter.boss != null else null
	var most := meta.steps_open()
	var hint := ""
	if most > 0 and step >= most and most < DifficultySteps.MAX:
		hint = tr("段階%dで%sを踏破すると開く") % [most, Chapters.short_name(Chapters.ALL.back())]
	told = {
		number = Chapters.short_name(chapter), name = Chapters.title(chapter), state = state_of(selected),
		open = open, cleared = meta.clears_of(chapter.id) > 0,
		description = tr(chapter.description) if open else tr("封印されている。%s。") % opener,
		route = tr("%d層とボス") % chapter.layers, record = Chapters.record(meta, chapter),
		boss = tr(boss.display_name) if boss != null and meta.has_met(boss.id) else tr(UNKNOWN_NAME),
		opener = opener, steps = most,
		step_note = tr("制約なし") if step == 0 else tr(DifficultySteps.ALL[step - 1].summary),
		step_echo = "" if step == 0 else DifficultySteps.echo_text(step),
		step_hint = hint, constraints = "" if step == 0 else DifficultySteps.constraints(step),
	}
	foes = []
	for foe in Chapters.foes(chapter):
		var met := meta.has_met(foe.id)
		foes.append([HubCodex.tile_picture(foe.visual_id, met, foe.tint), tr(foe.display_name) if met else tr(UNKNOWN_NAME), met])
	gear = []
	var weapon := MetaProgress.find_weapon(meta.weapon)
	if weapon != null:
		gear.append([weapon.emblem, tr(weapon.display_name)])
	for id in meta.loadout:
		var skill := MetaProgress.find_skill(id)
		if skill != null:
			gear.append([skill.emblem, tr(skill.display_name)])
	var move := MetaProgress.find_special(meta.special)
	if move != null:
		gear.append([move.emblem, tr(move.display_name)])
	action_button.disabled = not open
	action_button.text = tr("%sへ出撃する") % told.number if open else tr("%sは封印中") % told.number
	if open and step > 0:
		action_button.text += tr("（段階%d）") % step
	action_button.tooltip_text = "" if open else opener
	_tell_place()
	queue_redraw()


# What lives in the chosen chapter's painting, told to the vista.
func _tell_place() -> void:
	var chapter := chosen()
	var place: Dictionary = PLACES.get(chapter.id, {})
	var fires := PackedVector3Array()
	for fire: Vector3 in place.get(&"fires", []):
		fires.append(fire)
	fires.resize(FIRES)
	_look.set_shader_parameter(&"fires", fires)
	_look.set_shader_parameter(&"way", place.get(&"way", Vector2(0.5, 0.5)))
	_look.set_shader_parameter(&"way_reach", place.get(&"reach", 0.16))
	_look.set_shader_parameter(&"way_colour", place.get(&"light", Color.WHITE))
	_look.set_shader_parameter(&"mist_colour", place.get(&"mist", Color(1, 1, 1, 0)))
	_look.set_shader_parameter(&"still", 0.0 if meta.chapter_open(chapter) else 1.0)
	_motes.color = place.get(&"motes", Color.WHITE)
	_motes.direction = place.get(&"drift", Vector2.UP)
	_motes.emitting = meta.chapter_open(chapter) and is_visible_in_tree()


# What setting out is shown leaving from: the painting as it stands on the
# screen now (the part of it seen), where its way in is and that light's
# colour, all in the painting's UV.
func outlook() -> Dictionary:
	var chapter := chosen()
	var place: Dictionary = PLACES.get(chapter.id, {})
	var seen := _window(selected)
	# The vista runs past the screen's edges; the screen sees its middle.
	var whole := _vista.size
	var edge := Vector2.ONE * VISTA_MARGIN / whole
	var screen := Vector4(seen.x + seen.z * edge.x, seen.y + seen.w * edge.y, seen.z * (1.0 - edge.x * 2.0), seen.w * (1.0 - edge.y * 2.0))
	return {&"chapter": chapter, &"window": screen, &"way": place.get(&"way", Vector2(0.5, 0.5)), &"light": place.get(&"light", Color.WHITE)}


# Turns to a chapter.
func choose(index: int) -> void:
	var to := clampi(index, 0, Chapters.ALL.size() - 1)
	if to == selected:
		return
	_from = selected
	selected = to
	_tell()
	_kick(&"move")
	_sound(&"ui_move")
	if meta != null and meta.chapter_open(chosen()):
		chapter_chosen.emit(chosen())


# Enter (A) and the button: sets out for the chosen chapter, unless sealed.
func set_out() -> void:
	if meta == null or not meta.chapter_open(chosen()):
		_kick(&"refuse")
		GameAudio.play(self, &"ui_deny", -18.0)
		return
	_departed = selected
	_kick(&"depart")
	departure_requested.emit(chosen())


# A difficulty step chosen (Q / E, LB / RB or the arrows), kept within those open.
func choose_step(level: int) -> void:
	if meta == null:
		return
	var chosen_step := clampi(level, 0, meta.steps_open())
	if chosen_step == step:
		return
	step = chosen_step
	GameAudio.play(self, &"ui_move", -18.0)
	step_chosen.emit(step)
	_tell()
	_kick(&"step")


func focus_selected() -> void:
	grab_focus()


# Opening the page: the name rises into place.
func play_entrance() -> void:
	_from = selected
	_kick(&"move")


# How far through the moment of setting out the page is (0 to 1; 1 once over).
func moment() -> float:
	if _departed < 0:
		return 1.0
	return clampf(_since(&"depart") / DEPART_TIME, 0.0, 1.0)


func _sound(cue: StringName) -> void:
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, cue, -22.0)


# --- Clock ---

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_quiet = false
	_clock += delta
	for index in _view_share.size():
		_view_share[index] = lerpf(_view_share[index], 1.0 if index == selected else 0.0, 1.0 - exp(-delta * VIEW_EASE))
	_place_views()
	_show_vista()
	queue_redraw()


func _kick(what: StringName) -> void:
	_kicks[what] = _clock


func _since(what: StringName) -> float:
	return _clock - float(_kicks.get(what, -1000.0))


func _eased(what: StringName, time: float) -> float:
	var share := clampf(_since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


# --- Input ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _zone_at(event.position)
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				grab_focus()
				var zone: Variant = _zone_at(event.position)
				if zone != null and (zone as Array)[1] != null:
					_press((zone as Array)[1])
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				choose(selected - 1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				choose(selected + 1)
				accept_event()
		return
	var handled := true
	if event.is_action_pressed(&"ui_left", true):
		choose(selected - 1)
	elif event.is_action_pressed(&"ui_right", true):
		choose(selected + 1)
	elif event.is_action(&"ui_accept"):
		# Enter held on the lobby opened this page: its repeats must not set out.
		if event.is_pressed() and not event.is_echo():
			set_out()
	elif _pressed(event, KEY_Q, JOY_BUTTON_LEFT_SHOULDER):
		choose_step(step - 1)
	elif _pressed(event, KEY_E, JOY_BUTTON_RIGHT_SHOULDER):
		choose_step(step + 1)
	else:
		handled = false
	if handled:
		accept_event()


func _pressed(event: InputEvent, key: Key, button: int) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == key
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


func _press(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"chapter":
			choose(what[1])
		&"step":
			choose_step(what[1])


func _zone(rect: Rect2, id: Variant, tip := "") -> void:
	_zones.append([rect, id, tip])


func _zone_at(point: Vector2) -> Variant:
	var at := (point - _origin) / _zoom
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(at):
			return _zones[index]
	return null


func _get_tooltip(at_position: Vector2) -> String:
	var zone: Variant = _zone_at(at_position)
	return (zone as Array)[2] if zone != null else ""


func _hovered(kind: StringName, what: int) -> bool:
	if not _hover is Array or not (_hover as Array)[1] is Array:
		return false
	var id: Array = (_hover as Array)[1]
	return id[0] == kind and id[1] == what


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = null


# --- The painting ---

func _colour(item: StringName, share := 1.0) -> Color:
	var colour := get_theme_color(item)
	return Color(colour, colour.a * share)


# The part of a chapter's painting the vista sees (x, y, width, height of
# its UV): the painting covers the vista and drifts slowly within it.
func _window(index: int) -> Vector4:
	var art := Chapters.ALL[index].illustration
	if art == null or _vista.size.x <= 0.0:
		return Vector4(0.0, 0.0, 1.0, 1.0)
	var room := _vista.size
	var full := art.get_size()
	var part := room / (maxf(room.x / full.x, room.y / full.y) * 1.04)
	var drift := Vector2(0.5 + 0.06 * sin(_clock * 0.11 + index), 0.5 + 0.05 * cos(_clock * 0.09))
	var from := (full - part) * drift
	return Vector4(from.x / full.x, from.y / full.y, part.x / full.x, part.y / full.y)


# The vista as it stands this frame: the place turned to, the one turned
# from under it while the head still turns, each in its own light.
func _show_vista() -> void:
	if meta == null:
		return
	var to := Chapters.ALL[selected]
	var from := Chapters.ALL[_from]
	_look.set_shader_parameter(&"place", to.illustration)
	_look.set_shader_parameter(&"place_from", from.illustration)
	_look.set_shader_parameter(&"window", _window(selected))
	_look.set_shader_parameter(&"window_from", _window(_from))
	_look.set_shader_parameter(&"tint", _colour(&"art_open" if meta.chapter_open(to) else &"art_locked"))
	_look.set_shader_parameter(&"tint_from", _colour(&"art_open" if meta.chapter_open(from) else &"art_locked"))
	_look.set_shader_parameter(&"turn", _eased(&"move", TURN_TIME) if _from != selected else 1.0)
	_look.set_shader_parameter(&"side", 1.0 if selected >= _from else -1.0)
	_look.set_shader_parameter(&"clock", _clock)
	if to.illustration != null:
		_look.set_shader_parameter(&"aspect", to.illustration.get_size().aspect())


# --- Drawing ---

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


# A picture kept whole and centred in a rect.
func _fit_picture(rect: Rect2, art: Texture2D, tint := Color.WHITE) -> void:
	if art == null:
		return
	var full := art.get_size()
	var held := full * minf(rect.size.x / full.x, rect.size.y / full.y)
	draw_texture_rect(art, Rect2(rect.get_center() - held * 0.5, held), false, tint)


func _draw() -> void:
	_zones.clear()
	if meta == null or told.is_empty():
		return
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	var share := _eased(&"move", TURN_TIME)
	_draw_views()
	_draw_turns()
	_draw_name(share)
	_draw_foot(share)
	_draw_step()
	draw_set_transform(Vector2.ZERO)


# What is written under the chapters' views along the top (the views
# themselves are the stone windows, _place_views()): each one's number, a
# star under the one turned to, and a star beside the number of one cleared.
func _draw_views() -> void:
	for index in Chapters.ALL.size():
		var chapter := Chapters.ALL[index]
		var rect := _view_rect(index)
		var open := meta.chapter_open(chapter)
		var here := index == selected
		if here:
			HubUI.mark(self, Vector2(rect.get_center().x, rect.end.y + 13.0), 5.0, _colour(&"gold"))
		# Its number, on a dark plate so it reads on any painting.
		var number := Chapters.short_name(chapter)
		var wide := _width(number, &"font", &"label_size") + 20.0
		var tag := StyleBoxFlat.new()
		tag.bg_color = _colour(&"plate")
		tag.set_corner_radius_all(12)
		draw_style_box(tag, Rect2(rect.get_center().x - wide * 0.5, rect.end.y + 22.0, wide, 24.0))
		_words(Vector2(rect.position.x, rect.end.y + 40.0), number, &"font", &"label_size", _colour(&"gold") if here else _colour(&"pale", 1.0 if open else 0.6), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)
		if open and meta.clears_of(chapter.id) > 0:
			HubUI.mark(self, Vector2(rect.get_center().x + wide * 0.5 + 10.0, rect.end.y + 34.0), 5.0, _colour(&"gold"))
		_zone(rect.grow_individual(0.0, 0.0, 0.0, 40.0), [&"chapter", index], "%s　%s" % [Chapters.title(chapter), state_of(index)])


# The arrows at the page's sides.
func _draw_turns() -> void:
	for side: int in [-1, 1]:
		var to := selected + side
		var there := to >= 0 and to < Chapters.ALL.size()
		var rect := Rect2(Vector2(0.0 if side < 0 else DESIGN.x - 44.0, 196.0), Vector2(44.0, 80.0))
		var lit: bool = there and _hover is Array and (_hover as Array)[0] == rect
		_words(rect.position + Vector2(4.0, 54.0), "◀" if side < 0 else "▶", &"font", &"turn_size", _colour(&"pale", (0.95 if lit else 0.6) if there else 0.15))
		if there:
			_zone(rect, [&"chapter", to])


# The chosen chapter's number, name, how far it has been taken and what it is.
func _draw_name(share: float) -> void:
	var open: bool = told.open
	var rise := 14.0 * (1.0 - share)
	if not open:
		_fit_picture(Rect2(SEAL - Vector2.ONE * 78.0, Vector2.ONE * 156.0), EmblemIcons.texture("seal_chapter"), Color(1.0, 1.0, 1.0, share))
	_words(Vector2(EDGE + 2.0, 372.0 + rise), told.number, &"bold_font", &"number_size", _colour(&"gold", share))
	# A long name (in a script written with spaces) is set smaller to fit.
	var title: String = told.name
	var size := _size(&"title_size")
	var wide := _face(&"title_font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if wide > TITLE_ROOM:
		size = maxi(_size(&"value_size"), int(size * TITLE_ROOM / wide))
	draw_string(_face(&"title_font"), Vector2(EDGE - 4.0, 452.0 + rise), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _colour(&"pale" if open else &"dim", share))
	var state_colour := _colour(&"warn" if not open else (&"gold" if told.cleared else &"pale"), share)
	HubUI.mark(self, Vector2(EDGE + 8.0, 486.0 + rise), 6.0, state_colour)
	_words(Vector2(EDGE + 26.0, 494.0 + rise), told.state, &"title_font", &"state_size", state_colour)
	draw_multiline_string(_face(&"font"), Vector2(EDGE, 534.0 + rise), told.description, HORIZONTAL_ALIGNMENT_LEFT, TITLE_ROOM, _size(&"body_size"), 2, _colour(&"pale", 0.92 * share), _breaks())


# The foot: the way, the record and the boss, the foes, and what she carries.
func _draw_foot(share: float) -> void:
	var y := 620.0
	var x := EDGE
	for fact: Array in [[tr("道のり"), told.route], [tr("記録"), told.record], [tr("ボス"), told.boss]]:
		_words(Vector2(x, y), fact[0], &"font", &"label_size", _colour(&"dim"))
		_words(Vector2(x, y + 36.0), fact[1], &"title_font", &"value_size", _colour(&"pale", 0.4 + 0.6 * share))
		x += maxf(150.0, _width(fact[1], &"title_font", &"value_size") + 44.0)
	x = maxf(x + 10.0, 540.0)
	_words(Vector2(x, y), tr("現れる敵"), &"font", &"label_size", _colour(&"dim"))
	# One row: where long words before them leave less room, the foes are
	# drawn smaller rather than run onto a second row over the hub's keys.
	var tile := clampf((COLUMN - 16.0 - x + 8.0) / maxf(1.0, foes.size()) - 8.0, 26.0, TILE)
	for index in foes.size():
		var rect := Rect2(Vector2(x + index * (tile + 8.0), y + 10.0 + (TILE - tile) * 0.5), Vector2.ONE * tile)
		draw_circle(rect.get_center(), tile * 0.5, _colour(&"under"))
		_fit_picture(rect.grow(-3.0), foes[index][0])
		_zone(rect, null, foes[index][1])
	_words(Vector2(COLUMN, y), tr("装備", "gear"), &"font", &"label_size", _colour(&"dim"))
	for index in gear.size():
		var rect := Rect2(Vector2(COLUMN + index * (TILE + 8.0), y + 10.0), Vector2.ONE * TILE)
		_fit_picture(rect, EmblemIcons.texture(gear[index][0]))
		_zone(rect, null, gear[index][1])


# The difficulty step, over the button: its arrows round the number, a mark
# for every step (those open outlined, those taken filled), what it adds and
# brings back, and why the next is not open. Nothing before the steps open.
func _draw_step() -> void:
	var most: int = told.steps
	if most == 0:
		return
	draw_style_box(_step_plate, STEP_PLATE.grow_individual(8.0, 4.0, 8.0, 4.0))
	var at := Vector2(COLUMN, STEP_PLATE.position.y + 10.0)
	var pop := 1.0 + 0.25 * (1.0 - _eased(&"step", UIMotion.GOLD_TIME))
	_words(at + Vector2(0.0, 24.0), tr("段階"), &"font", &"label_size", _colour(&"dim"))
	var down := Rect2(at + Vector2(60.0, 0.0), Vector2(34.0, 34.0))
	var up := Rect2(at + Vector2(150.0, 0.0), Vector2(34.0, 34.0))
	_words(down.position + Vector2(8.0, 24.0), "◀", &"font", &"body_size", _colour(&"pale") if step > 0 else _colour(&"dim", 0.4))
	_words(up.position + Vector2(10.0, 24.0), "▶", &"font", &"body_size", _colour(&"pale") if step < most else _colour(&"dim", 0.4))
	draw_string(_face(&"title_font"), at + Vector2(94.0, 28.0), str(step), HORIZONTAL_ALIGNMENT_CENTER, 56.0, int(_size(&"step_size") * pop), _colour(&"gold"))
	_zone(down, [&"step", step - 1], tr("段階を下げる（Q・LB）"))
	_zone(up, [&"step", step + 1], tr("段階を上げる（E・RB）") if step < most else (told.step_hint if not (told.step_hint as String).is_empty() else tr("最後の段階")))
	for level in DifficultySteps.MAX + 1:
		var spot := at + Vector2(214.0 + level * 26.0, 17.0)
		if level <= step:
			HubUI.mark(self, spot, 7.0, _colour(&"gold"))
		elif level <= most:
			HubUI.mark(self, spot, 7.0, _colour(&"pale"))
			HubUI.mark(self, spot, 4.5, _colour(&"night"))
		else:
			HubUI.mark(self, spot, 4.0, _colour(&"dim", 0.45))
		if level <= most:
			_zone(Rect2(spot - Vector2(13.0, 13.0), Vector2(26.0, 26.0)), [&"step", level])
	var y := at.y + 60.0
	var echo: String = told.step_echo
	var room := COLUMN_WIDTH - (_width(echo, &"bold_font", &"note_size") + 16.0 if not echo.is_empty() else 0.0)
	draw_string(_face(&"font"), Vector2(at.x, y), told.step_note, HORIZONTAL_ALIGNMENT_LEFT, room, _size(&"note_size"), _colour(&"pale"), TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL)
	if not echo.is_empty():
		_words(Vector2(at.x, y), echo, &"bold_font", &"note_size", _colour(&"gold"), HORIZONTAL_ALIGNMENT_RIGHT, COLUMN_WIDTH)
	_zone(Rect2(at.x, y - 20.0, COLUMN_WIDTH, 28.0), null, told.constraints)
	var hint: String = told.step_hint
	if not hint.is_empty():
		_words(Vector2(at.x, y + 26.0), hint, &"font", &"label_size", _colour(&"dim"))
