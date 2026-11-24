class_name HelpView
extends Control

# The help, under the upgrades' night sky: the game's rules that the screens
# keep out of their way, by topic (HubSettings.HELP). The topics stand
# across the top as stars on one line, each with its name, and the whole
# width under them is the open topic's page: its name large, and its points
# a line each behind a star, in two columns, so that the longest topic fits
# without scrolling. The controls set their table of keys (the keys on
# caps, HubSettings.HELP_KEYS) in the left column and their points in the
# right.
#
# Left and right (or up and down, or Q / E, LB / RB) and the wheel go from
# topic to topic. The pointer opens a topic by resting on its star or
# clicking it. Closing is whoever shows the help's: its Esc (B), or a click
# on the close among the keys at the foot (close_requested).
#
# The view is one focusable control that fills the screen and draws itself
# in a design space of 1600x900 scaled to its rect, in the colours and faces
# of the theme's StarChart type, which it shares with the upgrades and the
# status. The sky is the upgrades' own shader. The keys at the foot are a
# KeyGuide.

# The close among the keys was clicked.
signal close_requested
# The practice ground was asked for from the demonstrations.
signal practice_requested

const SKY := preload("res://ui/star_chart/star_sky.gdshader")
const DESIGN := Vector2(1600.0, 900.0)
# The line the topics' stars stand on, and its two ends.
const ROW_Y := 150.0
const ROW_LEFT := 150.0
const ROW_RIGHT := 1450.0
const PAGE := Rect2(110.0, 250.0, 1380.0, 560.0)
const PAGE_INSET := 56.0
const COLUMN_GAP := 56.0
# Where the points begin under the topic's name, and the room after each.
const POINTS_TOP := 144.0
const POINT_GAP := 18.0
const POINT_INDENT := 26.0
const KEY_ROW := 40.0
# The demonstrations: the window, the list beside it, and a row of the list.
const DEMO_WINDOW := Rect2(166.0, 386.0, 700.0, 394.0)
const DEMO_LIST := Rect2(920.0, 386.0, 514.0, 300.0)
const DEMO_ROW := 42.0
const DEMO_VIEW := 560.0
# The row of the table of keys (HubSettings.HELP_KEYS) each move is in.
const DEMO_KEYS := {&"move": 0, &"strike": 1, &"charge": 1, &"dash": 3, &"skill": 4, &"special": 5}
# The fight's own action slots (ActionSlot, as the HUD shows them) stood in
# the window's lower right for the moves they tell of: the blow's charge
# filling, the dash coming back, a skill's wait counted down, the special
# move's gauge. [the HUD's slot ids] for each move.
const DEMO_SLOTS := {&"strike": [&"strike"], &"charge": [&"strike"], &"dash": [&"dash"], &"skill": [&"skill", &"skill_2"], &"special": [&"special"]}
const SLOT_SCALE := 0.8
const SLOT_STEP := 84.0
const SLOT_INSET := Vector2(18.0, 10.0)
const KEY_HEAD := 38.0
const MOVE_TIME := UIMotion.GOLD_TIME
# The keys at the foot stand where the hub's do.
const GUIDE_EDGE := Vector2(40.0, 16.0)

# The topic open (its place in HubSettings.HELP).
var topic := 0
# The demonstrations' topic: which of the fight's moves is shown, the window
# it is shown in (a FightStage: the fight itself, played by the scene), and
# whether the practice ground can be gone to from here (not in a run).
var demo := 0
var stage: FightStage
var allows_practice := true
# The HUD's slots shown over the window, by the HUD's ids.
var slots: Dictionary[StringName, ActionSlot] = {}
var close_hint: Button
var _sky: ColorRect
var _guide: KeyGuide
var _from := 0
var _clock := 0.0
var _kicks := {}
var _zones: Array = []
var _hover: Variant = null
# The topic the pointer rests on and since when.
var _rest := -1
var _rest_since := 0.0
var _origin := Vector2.ZERO
var _zoom := 1.0
var _quiet := true


func _ready() -> void:
	theme_type_variation = &"StarChart"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sky = ColorRect.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.show_behind_parent = true
	var night := ShaderMaterial.new()
	night.shader = SKY
	_sky.material = night
	add_child(_sky)
	_guide = KeyGuide.new()
	add_child(_guide)
	_guide.anchor_top = 1.0
	_guide.anchor_bottom = 1.0
	_guide.offset_left = GUIDE_EDGE.x
	_guide.offset_bottom = -GUIDE_EDGE.y
	_guide.offset_top = -GUIDE_EDGE.y - 44.0
	close_hint = _guide.add_hint("Esc", "B", tr("閉じる"), func(): close_requested.emit())
	_guide.add_hint("← / →", "◀ / ▶", tr("話題"))
	stage = FightStage.new()
	stage.name = "Demo"
	stage.hide()
	add_child(stage)
	# The HUD's own slots, over the window, each with its key as the HUD
	# names it.
	for entry: Array in ActionHud.SLOTS:
		var slot := ActionSlot.new()
		slot.name = "Slot_%s" % entry[0]
		slot.icon = EmblemIcons.texture(entry[1])
		slot.key_label.text = tr(entry[2])
		slot.size = slot.custom_minimum_size
		slot.hide()
		add_child(slot)
		slots[entry[0]] = slot
	visibility_changed.connect(_show_demo)
	resized.connect(_fit)
	theme_changed.connect(_fit)
	_fit()


# Places the design space in the rect, and tells the sky where it is.
func _fit() -> void:
	if _sky == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	var night := _sky.material as ShaderMaterial
	night.set_shader_parameter(&"extent", size)
	night.set_shader_parameter(&"origin", _origin)
	night.set_shader_parameter(&"zoom", _zoom)
	# The sky's warm light stands over the row of topics.
	night.set_shader_parameter(&"pole", Vector2(DESIGN.x * 0.5, ROW_Y))
	night.set_shader_parameter(&"centre", DESIGN * 0.5)
	night.set_shader_parameter(&"reach", size * 0.5 / _zoom)
	for item: StringName in [&"sky_deep", &"sky_light", &"sky_haze", &"lamp", &"speck"]:
		night.set_shader_parameter(item, get_theme_color(item))
	if stage != null:
		stage.position = _origin + DEMO_WINDOW.position * _zoom
		stage.size = DEMO_WINDOW.size * _zoom
	_place_slots()
	queue_redraw()


# The slots of the move shown, in the window's lower right as in the fight.
func _place_slots() -> void:
	var shown: Array = DEMO_SLOTS.get(StageScenes.CONTROLS[demo][0], [])
	var showing := stage != null and stage.visible
	var index := 0
	for id: StringName in slots:
		var slot := slots[id]
		slot.visible = showing and shown.has(id)
		if not slot.visible:
			continue
		var place := DEMO_WINDOW.end - SLOT_INSET - Vector2((shown.size() - index) * SLOT_STEP, (ActionSlot.SIZE + 26.0) * SLOT_SCALE)
		slot.scale = Vector2.ONE * SLOT_SCALE * _zoom
		slot.position = _origin + place * _zoom
		index += 1


# The slots follow the stage's own hero, as the HUD follows the fight's.
func _show_slots() -> void:
	if stage == null or stage.area == null or stage.area.hero == null:
		return
	var hero := stage.area.hero
	var motor := hero.motor
	if slots[&"strike"].visible:
		slots[&"strike"].show_state(1.0, motor.charge_progress() if motor.charging() else 0.0)
	if slots[&"dash"].visible:
		slots[&"dash"].show_state(1.0 if motor.dash_charges > 0 else motor.dash_recharge(), 0.0, motor.dash_charges, motor.tuning.dash_charges if motor.tuning.dash_charges > 1 else 0)
	for index in ActionHud.SKILL_SLOTS.size():
		var skill := slots[ActionHud.SKILL_SLOTS[index]]
		if not skill.visible or motor.skill_attacks[index] == null:
			continue
		var emblem := EmblemIcons.texture(motor.skill_emblems[index]) if not motor.skill_emblems[index].is_empty() else null
		if emblem != null and skill.icon != emblem:
			skill.icon = emblem
		var cooldown := motor.skill_cooldowns[index]
		var left := motor.skill_cooldowns_left[index]
		skill.show_state(1.0 if cooldown <= 0.0 else 1.0 - left / cooldown)
		skill.note_label.text = "%d" % ceili(left) if left > 0.0 else ""
	if slots[&"special"].visible and hero.special != null:
		var special := slots[&"special"]
		var mark := EmblemIcons.texture(hero.special.emblem)
		if mark != null and special.icon != mark:
			special.icon = mark
		special.show_state(hero.special_share(), 0.0 if hero.special_ready() else hero.special_share())


# --- The help ---

static func count() -> int:
	return HubSettings.HELP.size()


func title_of(index: int) -> String:
	return tr(HubSettings.HELP[index][0])


# A topic's points, a line of its own each.
func points_of(index: int) -> Array[String]:
	var listed: Array[String] = []
	for point: String in HubSettings.HELP[index][1]:
		listed.append(tr(point))
	return listed


# Whether a topic sets the table of keys over its points.
static func shows_keys(index: int) -> bool:
	return index == HubSettings.TOPIC_CONTROLS


# Whether a topic is the demonstrations.
static func shows_demos(index: int) -> bool:
	return index == HubSettings.TOPIC_DEMOS


# Opens the help at a topic, with the focus on it.
func open(index: int) -> void:
	topic = clampi(index, 0, count() - 1)
	_from = topic
	_rest = -1
	_quiet = true
	_kick(&"open")
	grab_focus()
	_show_demo()
	queue_redraw()


# Shows another of the fight's moves (or the same one again, from its start).
func choose_demo(to: int) -> void:
	to = posmod(to, StageScenes.CONTROLS.size())
	if to == demo and stage.playing():
		stage.replay()
		return
	demo = to
	_kick(&"demo")
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, &"ui_move", -22.0)
	_show_demo()
	queue_redraw()


# The window plays while the demonstrations are open, and only then.
func _show_demo() -> void:
	if stage == null:
		return
	var showing := is_visible_in_tree() and HelpView.shows_demos(topic)
	stage.visible = showing
	if showing:
		stage.show_scene(StageScenes.scene(StageScenes.CONTROLS[demo][0]), 0, DEMO_VIEW)
	else:
		stage.halt()
	_place_slots()


# Turns to a topic.
func choose(index: int) -> void:
	var to := clampi(index, 0, count() - 1)
	if to == topic:
		return
	_from = topic
	topic = to
	_kick(&"move")
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, &"ui_move", -22.0)
	_show_demo()
	queue_redraw()


# --- Clock ---

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_quiet = false
	_clock += delta
	# As in the lobby, resting the pointer on a topic opens it.
	if _rest >= 0 and _rest != topic and _clock - _rest_since >= HubLobby.HOVER_INTENT:
		choose(_rest)
	_show_slots()
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
		var id: Variant = _zone_at(event.position)
		_hover = id
		var rested: int = (id as Array)[1] if id != null and (id as Array)[0] == &"topic" else -1
		if rested != _rest:
			_rest = rested
			_rest_since = _clock
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				grab_focus()
				var id: Variant = _zone_at(event.position)
				if id != null:
					_press(id)
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				choose(topic - 1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				choose(topic + 1)
				accept_event()
		return
	var handled := true
	var demos := HelpView.shows_demos(topic)
	if demos and event.is_action_pressed(&"ui_up", true):
		choose_demo(demo - 1)
	elif demos and event.is_action_pressed(&"ui_down", true):
		choose_demo(demo + 1)
	elif demos and _pressed(event, KEY_T, JOY_BUTTON_Y):
		if allows_practice:
			practice_requested.emit()
	elif event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"ui_up", true) or _pressed(event, KEY_Q, JOY_BUTTON_LEFT_SHOULDER):
		choose(topic - 1)
	elif event.is_action_pressed(&"ui_right", true) or event.is_action_pressed(&"ui_down", true) or _pressed(event, KEY_E, JOY_BUTTON_RIGHT_SHOULDER):
		choose(topic + 1)
	elif event.is_action_pressed(&"ui_accept"):
		# On the demonstrations Enter plays the one shown again; elsewhere
		# there is nothing to enter, and the press is taken so it reaches
		# nothing under.
		if demos:
			choose_demo(demo)
	else:
		handled = false
	if handled:
		accept_event()


func _pressed(event: InputEvent, key: Key, button: int) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == key
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


# A place the pointer clicked: [&"topic", index].
func _press(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"topic":
			choose(what[1])
		&"demo":
			choose_demo(what[1])
		&"practice":
			if allows_practice:
				practice_requested.emit()


func _zone(rect: Rect2, id: Variant) -> void:
	_zones.append([rect, id])


func _zone_at(point: Vector2) -> Variant:
	var at := (point - _origin) / _zoom
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(at):
			return _zones[index][1]
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = null
		_rest = -1


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


static func column_width() -> float:
	return (PAGE.size.x - PAGE_INSET * 2.0 - COLUMN_GAP) * 0.5


# How tall a point stands, with the room after it.
func _point_height(words: String) -> float:
	return _face(&"font").get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, column_width() - POINT_INDENT, _size(&"part_size"), -1, _breaks()).y + POINT_GAP


# Which column each of a topic's points goes in (0 the left, 1 the right):
# the controls' all go right, beside the table; another topic's fill the
# left to about half of them all, then the right.
func columns_of(index: int) -> Array[int]:
	var listed := points_of(index)
	var placed: Array[int] = []
	if shows_keys(index):
		placed.resize(listed.size())
		placed.fill(1)
		return placed
	var total := 0.0
	for words in listed:
		total += _point_height(words)
	var spent := 0.0
	var column := 0
	for words in listed:
		var height := _point_height(words)
		if column == 0 and spent > 0.0 and spent + height * 0.5 > total * 0.5:
			column = 1
		placed.append(column)
		spent += height
	return placed


# How tall a topic's two columns stand under its name.
func heights_of(index: int) -> Vector2:
	var listed := points_of(index)
	var placed := columns_of(index)
	var tall := Vector2.ZERO
	if shows_keys(index):
		tall.x = KEY_HEAD + HubSettings.HELP_KEYS.size() * KEY_ROW
	for place in listed.size():
		tall[placed[place]] += _point_height(listed[place])
	return tall


# The room the points have under a topic's name.
static func points_room() -> float:
	return PAGE.size.y - POINTS_TOP - 24.0


# --- Drawing ---

func _spot(index: int) -> Vector2:
	return Vector2(lerpf(ROW_LEFT, ROW_RIGHT, float(index) / maxf(1.0, count() - 1.0)), ROW_Y)


# A soft round light.
func _glow(centre: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([colour])
	for index in 33:
		points.append(centre + Vector2.from_angle(TAU * index / 32.0) * radius)
		colours.append(Color(colour, 0.0))
	for index in 32:
		draw_polygon(PackedVector2Array([points[0], points[index + 1], points[index + 2]]), PackedColorArray([colours[0], colours[index + 1], colours[index + 2]]))


func _draw() -> void:
	_zones.clear()
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	var come := _eased(&"open", UIMotion.WINDOW_TIME)
	var moved := _eased(&"move", MOVE_TIME)
	_words(Vector2(52.0, 62.0), tr("ヘルプ"), &"title_font", &"name_size", _colour(&"pale", come))
	_draw_row(moved, come)
	_draw_page(moved, come)
	draw_set_transform(Vector2.ZERO)


# The topics, as stars on one line.
func _draw_row(moved: float, come: float) -> void:
	HubUI.hairline(self, _spot(0) - Vector2(60.0, 0.0), _spot(count() - 1) + Vector2(60.0, 0.0), _colour(&"brass", 0.6 * come))
	_glow(_spot(_from).lerp(_spot(topic), moved), 70.0, _colour(&"gold", 0.25 * come))
	for index in count():
		var spot := _spot(index)
		var here := index == topic
		var over: bool = _hover is Array and (_hover as Array)[1] == index
		draw_circle(spot, 16.0, _colour(&"void"))
		HubUI.star(self, spot, 16.0 if here else 10.0, _colour(&"gold" if here else (&"pale" if over else &"brass"), come))
		if here:
			draw_arc(spot, 24.0, 0.0, TAU, 32, _colour(&"gold", come if has_focus() else 0.5 * come), 1.5, true)
		_words(Vector2(spot.x - 130.0, spot.y + 52.0), title_of(index), &"title_font", &"figure_size" if here else &"part_size", _colour(&"gold" if here else (&"pale" if over else &"dim"), come), HORIZONTAL_ALIGNMENT_CENTER, 260.0)
		_zone(Rect2(spot.x - 120.0, spot.y - 30.0, 240.0, 96.0), [&"topic", index])


# The open topic's page.
func _draw_page(moved: float, come: float) -> void:
	var fade := (0.25 + 0.75 * moved) * come
	var slide := 24.0 * (1.0 - moved) * signf(topic - _from)
	var face := StyleBoxFlat.new()
	face.bg_color = _colour(&"panel", 0.86 * come)
	face.border_color = _colour(&"brass", 0.5 * come)
	face.set_border_width_all(1)
	face.set_corner_radius_all(4)
	draw_style_box(face, PAGE)
	for corner: Vector2 in [PAGE.position, Vector2(PAGE.end.x, PAGE.position.y), PAGE.end, Vector2(PAGE.position.x, PAGE.end.y)]:
		HubUI.mark(self, corner, 6.0, _colour(&"brass", come))
	var x := PAGE.position.x + PAGE_INSET + slide
	var half := column_width()
	_words(Vector2(x, PAGE.position.y + 70.0), title_of(topic), &"title_font", &"name_size", _colour(&"pale", fade))
	HubUI.trail(self, Vector2(x, PAGE.position.y + 92.0), Vector2(x + 520.0, PAGE.position.y + 92.0), _colour(&"brass", 0.8 * fade))
	if HelpView.shows_demos(topic):
		_draw_demos(slide, fade)
		return
	var top := PAGE.position.y + POINTS_TOP
	var at := Vector2(top, top)
	if shows_keys(topic):
		_draw_keys(Vector2(x, top - 8.0), half, fade)
	var listed := points_of(topic)
	var placed := columns_of(topic)
	for place in listed.size():
		var column := placed[place]
		var spot := Vector2(x + column * (half + COLUMN_GAP), at[column])
		HubUI.mark(self, spot + Vector2(6.0, -6.0), 4.0, _colour(&"gold", fade))
		draw_multiline_string(_face(&"font"), spot + Vector2(POINT_INDENT, 0.0), listed[place], HORIZONTAL_ALIGNMENT_LEFT, half - POINT_INDENT, _size(&"part_size"), -1, _colour(&"pale", fade), _breaks())
		at[column] += _point_height(listed[place])


# The demonstrations: the window's frame, the fight's moves down a list (the
# one shown told in a line), and the way to the practice ground.
func _draw_demos(slide: float, fade: float) -> void:
	var frame := DEMO_WINDOW.grow(8.0)
	frame.position.x += slide
	draw_rect(frame, _colour(&"brass", 0.7 * fade), false, 1.5)
	for corner: Vector2 in [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]:
		HubUI.mark(self, corner, 6.0, _colour(&"gold", fade))
	var shown: Array = StageScenes.CONTROLS[demo]
	var x := DEMO_LIST.position.x + slide
	var y := DEMO_LIST.position.y
	_words(Vector2(x, y - 6.0), tr("実際の戦闘で見る"), &"font", &"star_size", _colour(&"dim", fade))
	y += 14.0
	var picked := _eased(&"demo", UIMotion.SELECT_TIME)
	for index in StageScenes.CONTROLS.size():
		var entry: Array = StageScenes.CONTROLS[index]
		var here := index == demo
		var over: bool = _hover is Array and (_hover as Array)[0] == &"demo" and (_hover as Array)[1] == index
		var rect := Rect2(x - 12.0, y, DEMO_LIST.size.x + 12.0, DEMO_ROW - 4.0)
		if here:
			draw_rect(rect, _colour(&"gold", 0.1 * fade))
			draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y * picked)), _colour(&"gold", fade))
		HubUI.star(self, Vector2(x + 10.0, y + DEMO_ROW * 0.5 - 2.0), 8.0 if here else 5.0, _colour(&"gold" if here else &"brass", fade))
		_words(Vector2(x + 34.0, y + DEMO_ROW * 0.5 + 5.0), tr(entry[1]), &"title_font", &"figure_size" if here else &"part_size", _colour(&"gold" if here else (&"pale" if over else &"dim"), fade))
		# The chosen move's keys, on their caps at the end of its row (the
		# table of the controls has them all).
		var keys_row: int = DEMO_KEYS.get(entry[0], -1)
		if here and keys_row >= 0:
			var keys: Array = HubSettings.HELP_KEYS[keys_row]
			var caps: Array = []
			for key: String in keys[1]:
				caps.append([tr(key), 1.0])
			for key: String in keys[2]:
				caps.append([tr(key), 0.75])
			var room := 0.0
			for cap: Array in caps:
				room += _cap_width(cap[0]) + 6.0
			var cap_x := x + DEMO_LIST.size.x - room - 4.0
			for cap: Array in caps:
				cap_x += _draw_cap(Vector2(cap_x, y + DEMO_ROW * 0.5 + 4.0), cap[0], fade * float(cap[1])) + 6.0
		_zone(rect, [&"demo", index])
		y += DEMO_ROW
	# What the one shown is, in a line under the list.
	y += 14.0
	HubUI.trail(self, Vector2(x, y - 6.0), Vector2(x + DEMO_LIST.size.x, y - 6.0), _colour(&"brass", 0.6 * fade))
	draw_multiline_string(_face(&"font"), Vector2(x, y + 28.0), tr(shown[2]), HORIZONTAL_ALIGNMENT_LEFT, DEMO_LIST.size.x, _size(&"part_size"), 3, _colour(&"pale", fade), _breaks())
	# The keys of this page, and the practice ground.
	var foot := PAGE.end.y - 26.0
	_words(Vector2(DEMO_WINDOW.position.x + slide, DEMO_WINDOW.position.y - 22.0), tr("↑ / ↓　動きを選ぶ　　Enter　もう一度"), &"font", &"star_size", _colour(&"dim", fade))
	if allows_practice:
		var words := tr("T　練習場で自分で試す")
		var wide := _width(words, &"title_font", &"part_size") + 44.0
		var plate := Rect2(x + DEMO_LIST.size.x - wide, foot - 34.0, wide, 44.0)
		var over_it: bool = _hover is Array and (_hover as Array)[0] == &"practice"
		var face := StyleBoxFlat.new()
		face.bg_color = _colour(&"gold", (0.22 if over_it else 0.12) * fade)
		face.border_color = _colour(&"gold", (1.0 if over_it else 0.7) * fade)
		face.set_border_width_all(1)
		face.set_corner_radius_all(4)
		draw_style_box(face, plate)
		_words(Vector2(plate.position.x + 22.0, plate.position.y + 29.0), words, &"title_font", &"part_size", _colour(&"gold", fade))
		_zone(plate, [&"practice", 0])
	else:
		_words(Vector2(x, foot - 4.0), tr("練習場は、拠点のヘルプから行けます。"), &"font", &"star_size", _colour(&"dim", fade))


# The controls' table: a row an action, its keys and its pad buttons on caps.
func _draw_keys(at: Vector2, width: float, fade: float) -> void:
	var second := at.x + width * 0.30
	var third := at.x + width * 0.66
	_words(Vector2(second, at.y), tr("キーボード"), &"font", &"star_size", _colour(&"dim", fade))
	_words(Vector2(third, at.y), tr("ゲームパッド"), &"font", &"star_size", _colour(&"dim", fade))
	var y := at.y + KEY_HEAD
	for entry: Array in HubSettings.HELP_KEYS:
		_words(Vector2(at.x, y), tr(entry[0]), &"font", &"body_size", _colour(&"pale", fade))
		for pair: Array in [[second, entry[1]], [third, entry[2]]]:
			var x: float = pair[0]
			for key: String in pair[1]:
				x += _draw_cap(Vector2(x, y), tr(key), fade) + 8.0
		draw_line(Vector2(at.x, y + 14.0), Vector2(at.x + width, y + 14.0), _colour(&"brass", 0.15 * fade), 1.0)
		y += KEY_ROW


# A key on its cap; returns the cap's width.
func _cap_width(words: String) -> float:
	return maxf(34.0, _face(&"bold_font").get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(&"label_size")).x + 18.0)


func _draw_cap(at: Vector2, words: String, fade: float) -> float:
	var size := _size(&"label_size")
	var wide := _cap_width(words)
	var cap := StyleBoxFlat.new()
	cap.bg_color = _colour(&"void", fade)
	cap.border_color = _colour(&"brass", 0.8 * fade)
	cap.set_border_width_all(1)
	cap.set_corner_radius_all(4)
	draw_style_box(cap, Rect2(at.x, at.y - size - 6.0, wide, size + 14.0))
	draw_string(_face(&"bold_font"), at, words, HORIZONTAL_ALIGNMENT_CENTER, wide, size, _colour(&"pale", fade))
	return wide
