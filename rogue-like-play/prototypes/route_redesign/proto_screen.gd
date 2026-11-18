class_name ProtoScreen
extends Control

# What the three route prototypes share: the run they show (ProtoRoute, the
# game's own route and rules), one way of taking input (keys and pad through
# the ui_* actions and 1-3, the pointer through zones named while drawing),
# the steps of a pick (the cursor on an open area, the question, the going),
# a clock for their motion, and a few drawing helpers. A prototype draws
# itself whole in _paint() every frame and answers _key(), _click() and
# _point(); it styles nothing through the game's theme and saves nothing.
# All draw in the game's 1600x900 view.

const MINCHO_B := preload("res://ui/fonts/ShipporiMincho-Bold.ttf")
const MINCHO_M := preload("res://ui/fonts/ShipporiMincho-Medium.ttf")
const GOTHIC := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Regular.ttf")
const GOTHIC_B := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Bold.ttf")
const MIO_RIG := preload("res://art/characters/mio_rig/mio_rig.tscn")
const VIEW := Vector2(1600.0, 900.0)
const MOVE_TIME := 0.22
const OPEN_TIME := 0.6
const BREAKS := TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_MANDATORY
const NUMERALS := ["1", "2", "3"]

var model: ProtoRoute
# Seconds since the screen was shown.
var clock := 0.0
var hover: Variant = null
# An area looked at that is not the cursor's (pointed at, or scouted ahead).
var peek: RouteMap.Waypoint
# She is on her way to the pick (nothing is taken meanwhile).
var going := false
# How often a pick was gone ahead with, and the menu asked for.
var departures := 0
var menu_asked := 0
var _zones: Array = []
var _kicks: Dictionary = {}
var _veil: ColorRect
static var _figures: Dictionary = {}


func _init(of: ProtoRoute) -> void:
	model = of
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	_build()
	# The dark the screen leaves through, over everything it holds.
	_veil = ColorRect.new()
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	opened()


# --- For the prototype to answer ---

# Its own nodes (her figure, a backdrop), made once.
func _build() -> void:
	pass


func _paint() -> void:
	pass


# One of &"up", &"down", &"left", &"right", &"accept", &"cancel".
func _key(action: StringName) -> void:
	match action:
		&"accept":
			accept()
		&"cancel":
			cancel()


func _click(_id: Variant) -> void:
	pass


# The pointer came over a zone (or left them all: null).
func _point(_id: Variant) -> void:
	pass


# The route was laid anew (shown, posed, or a layer further on).
func _laid() -> void:
	pass


# Seconds from the going's start to the next layer.
func go_time() -> float:
	return 0.9


# --- The steps of a pick ---

func choose(index: int) -> void:
	if going or index < 0 or index >= model.open.size():
		return
	if model.armed:
		model.armed = false
	if index != model.cursor:
		model.cursor = index
		kick(&"move")
	peek = null


# Asks whether to go to the area under the cursor.
func arm() -> void:
	if going or model.selected() == null or model.armed:
		return
	model.armed = true
	peek = null
	kick(&"arm")


func accept() -> void:
	if going:
		return
	if model.armed:
		go()
	else:
		arm()


# Esc: takes the question back; with none asked, the run's menu.
func cancel() -> void:
	if going:
		return
	if model.armed:
		model.armed = false
		kick(&"disarm")
	else:
		menu_asked += 1


func go() -> void:
	if going or not model.armed:
		return
	going = true
	departures += 1
	kick(&"go")


func opened() -> void:
	going = false
	peek = null
	_kicks.clear()
	kick(&"open")
	if _veil != null:
		_veil.color.a = 0.0
	_laid()


# Puts the screen in a named state for a screenshot: &"initial" (two areas
# in, the cursor on the first way), &"select" (on the second), &"detail"
# (the prototype's fuller look, _pose_detail), &"armed" (the question
# asked), &"start" (the run's first choice) and &"boss" (the boss next).
func pose(state: StringName) -> void:
	model.reset({&"start": &"start", &"boss": &"boss"}.get(state, &"mid"))
	model.cursor = 1 if state in [&"select", &"detail", &"armed"] else 0
	opened()
	_kicks[&"open"] = clock - 10.0
	match state:
		&"detail":
			_pose_detail()
		&"armed":
			model.armed = true
			_kicks[&"arm"] = clock - 10.0


func _pose_detail() -> void:
	pass


# --- Clock and one-shot motion ---

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	clock += delta
	if going:
		var share := clampf(since(&"go") / go_time(), 0.0, 1.0)
		_veil.color.a = smoothstep(0.62, 1.0, share)
		if share >= 1.0:
			model.advance()
			opened()
	elif _veil.color.a > 0.0:
		_veil.color.a = maxf(0.0, _veil.color.a - delta * 4.0)
	queue_redraw()


func kick(what: StringName) -> void:
	_kicks[what] = clock


# Seconds since kick(what), or a long time when it never was.
func since(what: StringName) -> float:
	return clock - float(_kicks.get(what, -1000.0))


# 0 to 1 over `time` seconds after kick(what), eased out.
func eased(what: StringName, time: float) -> float:
	var share := clampf(since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


# 0 to 1 while the question is asked, easing both ways.
func arming() -> float:
	return eased(&"arm", 0.28) if model.armed else 1.0 - eased(&"disarm", 0.18) if since(&"disarm") < 0.18 else 0.0


func breath(speed := 3.0) -> float:
	return 0.5 + 0.5 * sin(clock * speed)


# --- Input ---

func _draw() -> void:
	_zones.clear()
	_paint()


func zone(rect: Rect2, id: Variant) -> void:
	_zones.append([rect, id])


func _zone_at(point: Vector2) -> Variant:
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(point):
			return _zones[index][1]
	return null


func _gui_input(event: InputEvent) -> void:
	if going:
		return
	if event is InputEventMouseMotion:
		var id: Variant = _zone_at(event.position)
		if id != hover:
			hover = id
			_point(id)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id: Variant = _zone_at(event.position)
		if id != null:
			_click(id)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or going:
		return
	for pair: Array in [[&"ui_up", &"up"], [&"ui_down", &"down"], [&"ui_left", &"left"], [&"ui_right", &"right"], [&"ui_accept", &"accept"], [&"ui_cancel", &"cancel"]]:
		if event.is_action_pressed(pair[0], true):
			_key(pair[1])
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
		if index >= 0 and index < model.open.size():
			number(index)
			get_viewport().set_input_as_handled()


# 1-3: that way at once, with the question.
func number(index: int) -> void:
	choose(index)
	arm()


# The zones every prototype names: [&"open", index] (the cursor goes there;
# on the one it is on already, the question, and asked, the going),
# [&"go"] and [&"back"].
func common_click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"open":
			if what[1] == model.cursor:
				accept()
			else:
				choose(what[1])
		&"go":
			accept()
		&"back":
			cancel()


func hovered(id: Array) -> bool:
	return hover is Array and hover == id


# --- What the prototypes tell alike ---

# What stands for an area: its leading foe (as the shipped stage picks it),
# an event's object, nothing for the boss still in the dark. The picture is
# kept here: a texture drawn and then let go is freed before the frame is
# rendered, and draws as a blank rect.
func figure_of(point: RouteMap.Waypoint, large := false) -> Texture2D:
	if model.veiled(point):
		return null
	var key := [point.area, large]
	if not _figures.has(key):
		_figures[key] = _find_figure(point.area, large)
	return _figures[key]


static func _find_figure(area: AreaData, large: bool) -> Texture2D:
	if area.is_event():
		return RouteNode.prop_for(area.event)
	var foe := RouteNode.leader(area)
	if foe == null:
		return null
	if large:
		var painted := EnemySprites.codex_portrait(foe.visual_id)
		if painted != null:
			return painted
	return HubCodex.tile_picture(foe.visual_id, true, foe.tint)


func foe_tile(foe: FoeData, met: bool) -> Texture2D:
	return HubCodex.tile_picture(foe.visual_id, met, foe.tint)


# Her boons: [emblem, rank, ranked] each.
func boons() -> Array:
	var held := []
	for boon in model.run.build.owned():
		held.append([boon.emblem, model.run.build.rank(boon.id), boon.max_level > 1])
	return held


func layer_words() -> String:
	if model.selected() != null and model.selected().area.boss != null:
		return "最奥"
	return "第%d層" % (model.run.layer + 1)


func span_words() -> String:
	return "全%d層とボス" % (model.route.size() - 1)


# A reward's sign: a boon's star, a heal's heart, the echo's ring; an event
# (reward -1) a lozenge.
func sign_of(centre: Vector2, radius: float, reward: int, colour: Color) -> void:
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
			ring(centre, radius * 0.92, colour, maxf(1.5, radius * 0.22))
			draw_circle(centre, radius * 0.36, colour)
		_:
			ring_of(centre, radius, colour, 4, maxf(1.5, radius * 0.2), PI * 0.5)
			draw_circle(centre, radius * 0.22, colour)


# --- Drawing helpers ---

func text(at: Vector2, words: String, font: Font, size: int, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, at, words, align, width, size, colour)


func width_of(words: String, font: Font, size: int) -> float:
	return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# Words with wider letter spacing.
func spaced(at: Vector2, words: String, font: Font, size: int, colour: Color, gap: float, centred := false) -> float:
	var total := 0.0
	var widths: Array[float] = []
	for index in words.length():
		var w := font.get_string_size(words[index], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(w)
		total += w + (gap if index < words.length() - 1 else 0.0)
	var x := at.x - (total * 0.5 if centred else 0.0)
	for index in words.length():
		draw_string(font, Vector2(x, at.y), words[index], HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		x += widths[index] + gap
	return total


# Wrapped words; returns the height they took, with `line_gap` after.
func paragraph(at: Vector2, words: String, font: Font, size: int, colour: Color, width: float, line_gap := 8.0, max_lines := -1, align := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	if words.is_empty():
		return 0.0
	draw_multiline_string(font, at, words, align, width, size, max_lines, colour, BREAKS)
	var held := font.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, BREAKS)
	return held.y + line_gap


# A painting filling a rect, cropped round `focus`, `zoom` closer.
func picture(rect: Rect2, art: Texture2D, tint := Color.WHITE, focus := Vector2(0.5, 0.5), zoom := 1.0) -> void:
	if art == null:
		return
	var full := art.get_size()
	var part := rect.size / (maxf(rect.size.x / full.x, rect.size.y / full.y) * zoom)
	draw_texture_rect_region(art, rect, Rect2((full - part) * focus, part), tint)


# A picture kept whole in a rect, centred, or standing on its bottom edge.
func fit(rect: Rect2, art: Texture2D, tint := Color.WHITE, standing := false) -> Rect2:
	if art == null:
		return Rect2()
	var full := art.get_size()
	var held := full * minf(rect.size.x / full.x, rect.size.y / full.y)
	var at := rect.get_center() - held * 0.5
	if standing:
		at.y = rect.end.y - held.y
	draw_texture_rect(art, Rect2(at, held), false, tint)
	return Rect2(at, held)


func emblem(centre: Vector2, radius: float, key: String, tint := Color.WHITE) -> void:
	fit(Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), EmblemIcons.texture(key), tint)


func ring(centre: Vector2, radius: float, colour: Color, width := 1.5, start := 0.0, end := TAU) -> void:
	draw_arc(centre, radius, start, end, maxi(24, int(radius * 0.9)), colour, width, true)


# A ring of straight sides (4: a lozenge).
func ring_of(centre: Vector2, radius: float, colour: Color, sides: int, width := 1.5, turn := 0.0) -> void:
	var points := PackedVector2Array()
	for step in sides + 1:
		points.append(centre + Vector2.from_angle(turn + TAU * step / sides) * radius)
	draw_polyline(points, colour, width, true)


func plate(rect: Rect2, fill: Color, edge := Color.TRANSPARENT, corner := 0.0, edge_width := 1.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(corner))
	box.anti_aliasing = corner > 0.0
	if edge.a > 0.0:
		box.border_color = edge
		box.set_border_width_all(int(edge_width))
	draw_style_box(box, rect)


# A rect whose colour runs from `top` to `bottom`.
func shade(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


# A rect whose colour runs from `left` to `right`.
func shade_across(rect: Rect2, left: Color, right: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([left, right, right, left]))


# A soft round light, `squash` flattening it into an oval.
func glow(centre: Vector2, radius: float, colour: Color, squash := 1.0) -> void:
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([colour])
	for index in 49:
		points.append(centre + Vector2.from_angle(TAU * index / 48.0) * radius * Vector2(1.0, squash))
		colours.append(Color(colour, 0.0))
	for index in 48:
		draw_polygon(PackedVector2Array([points[0], points[index + 1], points[index + 2]]), PackedColorArray([colours[0], colours[index + 1], colours[index + 2]]))


func diamond(centre: Vector2, radius: float, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([centre + Vector2(0.0, -radius), centre + Vector2(radius, 0.0), centre + Vector2(0.0, radius), centre + Vector2(-radius, 0.0)]), colour)


# A line of dashes along a path, `offset` px along the pattern, up to
# `upto` of its length.
func dashes(points: PackedVector2Array, colour: Color, width: float, dash: float, gap: float, offset := 0.0, upto := 1.0) -> void:
	var total := 0.0
	for index in points.size() - 1:
		total += points[index].distance_to(points[index + 1])
	var limit := total * upto
	var period := dash + gap
	var travelled := 0.0
	for index in points.size() - 1:
		var from := points[index]
		var to := points[index + 1]
		var length := from.distance_to(to)
		if length <= 0.0:
			continue
		var start := travelled
		var end := minf(travelled + length, limit)
		var at := start
		while at < end:
			var phase := fposmod(at + offset, period)
			if phase < dash:
				var until := minf(at + dash - phase, end)
				draw_line(from.lerp(to, (at - start) / length), from.lerp(to, (until - start) / length), colour, width, true)
				at = maxf(until, at + 0.05)
			else:
				at += maxf(period - phase, 0.05)
		travelled += length
		if travelled >= limit:
			return


# The point `share` of the way along a path, by length.
func along(points: PackedVector2Array, share: float) -> Vector2:
	var total := 0.0
	for index in points.size() - 1:
		total += points[index].distance_to(points[index + 1])
	var want := total * clampf(share, 0.0, 1.0)
	for index in points.size() - 1:
		var length := points[index].distance_to(points[index + 1])
		if want <= length and length > 0.0:
			return points[index].lerp(points[index + 1], want / length)
		want -= length
	return points[points.size() - 1]
