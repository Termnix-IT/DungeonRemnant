class_name HubSortie
extends Control

# Where to set out, as a vista: the chosen chapter's painting is the whole
# screen, as if she stood at its gate, and turning to another chapter fades
# one place into the next. The chapter's number and name stand large at the
# lower left over a dark fall, with how far it has been taken (未踏,
# 第2層まで, 踏破 2回, or 封印中) and what it is. A row of small views along the
# top tells where among the chapters she is, each marked once cleared and
# sealed until it opens. Along the foot run the way, the record and the boss
# (unnamed until met, as in the encyclopedia), the foes that come in it
# (pictured when met and dark shapes when not) and what she carries. At the
# right stand the difficulty step, once the ending has opened the steps
# (the step, what it adds and the echo it brings back), and the one action,
# a crest button (CrestButton) that sets out. A sealed chapter is dark under
# its seal; it can be chosen to read what opens it, not set out for.
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
const UNKNOWN_NAME := "？？？"
const VIEW := Vector2(168.0, 84.0)
const VIEW_GAP := 14.0
const VIEW_TOP := 8.0
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
var _vista: Control
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
	_vista = Control.new()
	_vista.name = "Vista"
	_vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vista.show_behind_parent = true
	_vista.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vista.draw.connect(_draw_vista)
	add_child(_vista)
	# Setting out is this screen's moment: the crest with the lobby's mark
	# for it. The focus stays on the page, so Enter there and the button are one.
	action_button = CrestButton.new()
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
	queue_redraw()


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
	queue_redraw()


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
	queue_redraw()
	_vista.queue_redraw()


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


# A chapter's painting over the whole of the child, slowly drifting.
func _paint_place(index: int, share: float, closer: float) -> void:
	var chapter := Chapters.ALL[index]
	var art := chapter.illustration
	if art == null:
		return
	var open := meta != null and meta.chapter_open(chapter)
	var tint := _colour(&"art_open" if open else &"art_locked")
	var room := Rect2(Vector2.ZERO, _vista.size)
	var full := art.get_size()
	var part := room.size / (maxf(room.size.x / full.x, room.size.y / full.y) * (1.04 + closer))
	var drift := Vector2(0.5 + 0.06 * sin(_clock * 0.11 + index), 0.5 + 0.05 * cos(_clock * 0.09))
	_vista.draw_texture_rect_region(art, room, Rect2((full - part) * drift, part), Color(tint, share))


func _shade(rect: Rect2, first: Color, last: Color, across := false) -> void:
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	_vista.draw_polygon(corners, PackedColorArray([first, last, last, first] if across else [first, first, last, last]))


# The painting, the place it is turning from under it, and the dark falls
# the words stand on: from the foot up, from the left in and from the top down.
func _draw_vista() -> void:
	if meta == null:
		return
	var room := Rect2(Vector2.ZERO, _vista.size)
	var share := _eased(&"move", TURN_TIME)
	var leaving := 1.0 - moment()
	_vista.draw_rect(room, _colour(&"night"))
	if _from != selected and share < 1.0:
		_paint_place(_from, 1.0, 0.0)
	_paint_place(selected, share if _from != selected else 1.0, 0.10 * moment() if _departed == selected else 0.0)
	var dark := _colour(&"shade")
	var clear := Color(dark, 0.0)
	_shade(Rect2(0.0, room.size.y * 0.40, room.size.x, room.size.y * 0.60), clear, Color(dark, 0.95))
	_shade(Rect2(0.0, 0.0, room.size.x * 0.52, room.size.y), Color(dark, 0.55), clear, true)
	_shade(Rect2(0.0, 0.0, room.size.x, room.size.y * 0.20), Color(dark, 0.72), clear)
	if leaving > 0.0:
		_vista.draw_rect(room, _colour(&"flash", 0.6 * leaving * leaving))


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


# A painting filling a rect, cropped round where its way in is.
func _view_picture(rect: Rect2, chapter: ChapterData, tint: Color) -> void:
	var art := chapter.illustration
	if art == null:
		return
	var full := art.get_size()
	var part := rect.size / maxf(rect.size.x / full.x, rect.size.y / full.y)
	draw_texture_rect_region(art, rect, Rect2((full - part) * Vector2(VIEW_FOCUS.get(chapter.id, 0.5), 0.55), part), tint)


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


# The chapters as small views along the top.
func _draw_views() -> void:
	var count := Chapters.ALL.size()
	var left := (DESIGN.x - count * VIEW.x - (count - 1) * VIEW_GAP) * 0.5
	for index in count:
		var chapter := Chapters.ALL[index]
		var rect := Rect2(Vector2(left + index * (VIEW.x + VIEW_GAP), VIEW_TOP), VIEW)
		var open := meta.chapter_open(chapter)
		var here := index == selected
		var bright := (1.0 if here else (0.78 if _hovered(&"chapter", index) else 0.5)) * (1.0 if open else 0.35)
		_view_picture(rect, chapter, Color(bright, bright, bright))
		draw_rect(rect, _colour(&"gold") if here else _colour(&"rule"), false, 2.0 if here else 1.0)
		if here:
			draw_rect(rect.grow(4.0), _colour(&"gold", 0.35), false, 1.0)
			HubUI.mark(self, Vector2(rect.get_center().x, rect.end.y + 12.0), 5.0, _colour(&"gold"))
		if not open:
			_fit_picture(Rect2(rect.get_center() - Vector2.ONE * 20.0, Vector2.ONE * 40.0), EmblemIcons.texture("seal_chapter"))
		elif meta.clears_of(chapter.id) > 0:
			HubUI.mark(self, rect.position + Vector2(14.0, 14.0), 6.0, _colour(&"gold"))
		# Its number, on a dark plate so it reads on any painting.
		var number := Chapters.short_name(chapter)
		var wide := _width(number, &"font", &"label_size") + 20.0
		var tag := StyleBoxFlat.new()
		tag.bg_color = _colour(&"plate")
		tag.set_corner_radius_all(11)
		draw_style_box(tag, Rect2(rect.get_center().x - wide * 0.5, rect.end.y + 20.0, wide, 22.0))
		_words(Vector2(rect.position.x, rect.end.y + 36.0), number, &"font", &"label_size", _colour(&"gold") if here else _colour(&"pale"), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)
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
	HubUI.hairline(self, Vector2(EDGE, y - 24.0), Vector2(COLUMN + COLUMN_WIDTH, y - 24.0), _colour(&"rule", 1.6))
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
	var box := StyleBoxFlat.new()
	box.bg_color = _colour(&"plate")
	box.border_color = _colour(&"rule", 0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	draw_style_box(box, STEP_PLATE)
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
