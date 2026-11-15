class_name ProtoScreen
extends Control

# What the three departure prototypes share: the departure they show
# (ProtoExpedition), one way of taking input (keys and pad through the ui_*
# actions, the pointer through zones named while drawing), a clock for their
# motion, and a few drawing helpers. A prototype draws itself whole in
# _paint() every frame and answers _key(), _click() and _wheel(); it styles
# nothing through the game's theme, so each stands on its own look. All draw
# in a 1600x900 view.

const MINCHO_B := preload("res://ui/fonts/ShipporiMincho-Bold.ttf")
const MINCHO_M := preload("res://ui/fonts/ShipporiMincho-Medium.ttf")
const GOTHIC := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Regular.ttf")
const GOTHIC_B := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Bold.ttf")
const VIEW := Vector2(1600.0, 900.0)
const MOVE_TIME := 0.32
const DEPART_TIME := 0.9
const REFUSE_TIME := 0.3

var model: ProtoExpedition
# The chapter under the cursor (its place in Chapters.ALL), and the one the
# cursor came from.
var chosen := 0
var from := 0
# Seconds since the screen was shown.
var clock := 0.0
var hover: Variant = null
var _zones: Array = []
var _kicks: Dictionary = {}


func _init(of: ProtoExpedition) -> void:
	model = of
	chosen = model.frontier()
	from = chosen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


# --- For the prototype to answer ---

func _paint() -> void:
	pass


# One of &"up", &"down", &"left", &"right", &"accept", &"cancel",
# &"prev" (Q), &"next" (E).
func _key(action: StringName) -> void:
	common_key(action)


func _click(id: Variant) -> void:
	common_click(id)


func _wheel(_step: int) -> void:
	pass


# Moves the cursor to a chapter.
func choose(index: int) -> void:
	var to := clampi(index, 0, model.count() - 1)
	if to == chosen:
		return
	from = chosen
	chosen = to
	kick(&"move")


# Enter sets out, Q and E change the step.
func common_key(action: StringName) -> void:
	match action:
		&"accept":
			set_out()
		&"prev":
			change_step(model.step - 1)
		&"next":
			change_step(model.step + 1)


# The zones every prototype names: [&"chapter", index], [&"step", level]
# and [&"go"].
func common_click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"chapter":
			choose(what[1])
		&"step":
			change_step(what[1])
		&"go":
			set_out()


func change_step(level: int) -> void:
	if model.choose_step(level):
		kick(&"step")


# Sets out for the chosen chapter, or refuses.
func set_out() -> bool:
	if model.set_out(chosen):
		kick(&"depart")
		return true
	kick(&"refuse")
	return false


# Puts the screen in a named state for a screenshot: &"initial" (as it
# opens, on the frontier), &"other" (a chapter cleared), &"sealed", &"steps"
# (past the ending, a step chosen), &"limit" (the highest step open),
# &"depart" (the moment of setting out).
func pose(state: StringName) -> void:
	model.reset(state in [&"steps", &"limit"])
	_kicks.clear()
	chosen = model.frontier()
	from = chosen
	match state:
		&"other":
			chosen = 0
		&"sealed":
			chosen = 2
		&"steps":
			chosen = model.count() - 1
			model.step = 2
		&"limit":
			chosen = model.count() - 1
			model.step = model.steps_open()
		&"depart":
			set_out()
			# The capture comes 0.7 s later: the moment a third of the way in.
			_kicks[&"depart"] = clock + 0.4
	from = chosen


# --- Clock and one-shot motion ---

func _process(delta: float) -> void:
	if is_visible_in_tree():
		clock += delta
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


# How far the cursor has come to the chosen chapter (0 to 1).
func moved() -> float:
	return eased(&"move", MOVE_TIME)


# How far through the moment of setting out (0 to 1), or 1 once over.
func departing() -> float:
	return clampf(since(&"depart") / DEPART_TIME, 0.0, 1.0)


# A short sideways shake after a refusal.
func refusal() -> float:
	var share := clampf(since(&"refuse") / REFUSE_TIME, 0.0, 1.0)
	return sin(share * TAU * 2.0) * 5.0 * (1.0 - share)


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
	if event is InputEventMouseMotion:
		hover = _zone_at(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var id: Variant = _zone_at(event.position)
			if id != null:
				_click(id)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel(1)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	for pair: Array in [[&"ui_up", &"up"], [&"ui_down", &"down"], [&"ui_left", &"left"], [&"ui_right", &"right"], [&"ui_accept", &"accept"], [&"ui_cancel", &"cancel"]]:
		if event.is_action_pressed(pair[0], true):
			_key(pair[1])
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var named: Variant = {KEY_Q: &"prev", KEY_E: &"next"}.get(event.keycode)
		if named != null:
			_key(named)
			get_viewport().set_input_as_handled()


# Whether the pointer rests on a zone named [kind, what] (null matches any).
func hovered(kind: StringName, what: Variant = null) -> bool:
	if not hover is Array or (hover as Array)[0] != kind:
		return false
	return what == null or (hover as Array)[1] == what


# --- Drawing helpers ---

func text(at: Vector2, words: String, font: Font, size: int, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, at, words, align, width, size, colour)


func width_of(words: String, font: Font, size: int) -> float:
	return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# Words with wider letter spacing (headings cut in metal or stone).
func spaced(at: Vector2, words: String, font: Font, size: int, colour: Color, gap: float, centred := false) -> void:
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


# Wrapped words; returns the height they took, with `line_gap` after.
func paragraph(at: Vector2, words: String, font: Font, size: int, colour: Color, width: float, line_gap := 8.0, max_lines := -1) -> float:
	if words.is_empty():
		return 0.0
	draw_multiline_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, colour, TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_MANDATORY)
	var held := font.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_MANDATORY)
	return held.y + line_gap


# Where across a chapter's painting its way in is (HubSortie.DOOR_FOCUS).
func focus_of(index: int) -> Vector2:
	return Vector2(HubSortie.DOOR_FOCUS.get(model.chapter(index).id, 0.5), 0.55)


# A painting filling a rect, cropped round `focus`, `zoom` closer.
func picture(rect: Rect2, art: Texture2D, tint := Color.WHITE, focus := Vector2(0.5, 0.5), zoom := 1.0) -> void:
	if art == null:
		return
	var full := art.get_size()
	var part := rect.size / (maxf(rect.size.x / full.x, rect.size.y / full.y) * zoom)
	draw_texture_rect_region(art, rect, Rect2((full - part) * focus, part), tint)


# A painting as a disc, looking at `focus`.
func picture_round(centre: Vector2, radius: float, art: Texture2D, tint := Color.WHITE, focus := Vector2(0.5, 0.5)) -> void:
	if art == null:
		return
	var full := art.get_size()
	var half := full.y * 0.36
	var middle := (full * focus).clamp(Vector2.ONE * half, full - Vector2.ONE * half)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in 64:
		var turn := Vector2.from_angle(TAU * index / 64.0)
		points.append(centre + turn * radius)
		uvs.append((middle + turn * half) / full)
	draw_polygon(points, PackedColorArray([tint]), uvs, art)


# A picture kept whole and centred in a rect.
func fit(rect: Rect2, art: Texture2D, tint := Color.WHITE) -> void:
	if art == null:
		return
	var full := art.get_size()
	var held := full * minf(rect.size.x / full.x, rect.size.y / full.y)
	draw_texture_rect(art, Rect2(rect.get_center() - held * 0.5, held), false, tint)


func emblem(centre: Vector2, radius: float, key: String, tint := Color.WHITE) -> void:
	fit(Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), EmblemIcons.texture(key), tint)


func ring(centre: Vector2, radius: float, colour: Color, width := 1.5, start := 0.0, end := TAU) -> void:
	draw_arc(centre, radius, start, end, maxi(24, int(radius * 0.9)), colour, width, true)


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


# A soft round light.
func glow(centre: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([colour])
	for index in 49:
		points.append(centre + Vector2.from_angle(TAU * index / 48.0) * radius)
		colours.append(Color(colour, 0.0))
	for index in 48:
		draw_polygon(PackedVector2Array([points[0], points[index + 1], points[index + 2]]), PackedColorArray([colours[0], colours[index + 1], colours[index + 2]]))


func diamond(centre: Vector2, radius: float, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([centre + Vector2(0.0, -radius), centre + Vector2(radius, 0.0), centre + Vector2(0.0, radius), centre + Vector2(-radius, 0.0)]), colour)


# --- Parts the prototypes share, each in its own colours ---
# `pal` holds: dim, value, accent, warn (words), under (the disc behind a
# foe, or transparent), rule (hairlines), go, go_edge, go_text (the action),
# off, off_text (the action when it cannot be taken).

# The foes that come in the chosen chapter, `size` each, wrapping in `wide`;
# returns the height they took.
func foe_tiles(at: Vector2, wide: float, size: float, pal: Dictionary) -> float:
	var across := maxi(1, int((wide + 8.0) / (size + 8.0)))
	var listed := model.foes(chosen)
	for index in listed.size():
		var rect := Rect2(at + Vector2(index % across, index / across) * (size + 8.0), Vector2.ONE * size)
		var under: Color = pal.under
		if under.a > 0.0:
			draw_circle(rect.get_center(), size * 0.5, under)
		fit(rect.grow(-3.0), listed[index][0])
	return ceilf(float(listed.size()) / across) * (size + 8.0) - 8.0


# What she carries, as medallions; returns the width they took.
func gear_tiles(at: Vector2, size: float) -> float:
	var listed := model.gear()
	for index in listed.size():
		emblem(at + Vector2(index * (size + 8.0) + size * 0.5, size * 0.5), size * 0.5, listed[index][0])
	return listed.size() * (size + 8.0) - 8.0


# The difficulty step: its arrows round the number, a pip for every step
# (those open outlined, those taken filled), what it adds and brings back,
# and why the next is not open. Nothing before the steps open. Returns the
# height it took.
func step_block(at: Vector2, wide: float, pal: Dictionary) -> float:
	var most := model.steps_open()
	if most == 0:
		return 0.0
	var dim: Color = pal.dim
	var accent: Color = pal.accent
	var value: Color = pal.value
	var pop := 1.0 + 0.25 * (1.0 - eased(&"step", 0.25))
	text(at + Vector2(0.0, 24.0), tr("段階"), GOTHIC, 15, dim)
	var down := Rect2(at + Vector2(60.0, 0.0), Vector2(34.0, 34.0))
	var up := Rect2(at + Vector2(150.0, 0.0), Vector2(34.0, 34.0))
	text(down.position + Vector2(8.0, 24.0), "◀", GOTHIC, 16, value if model.step > 0 else Color(dim, 0.4))
	text(up.position + Vector2(10.0, 24.0), "▶", GOTHIC, 16, value if model.step < most else Color(dim, 0.4))
	text(at + Vector2(94.0, 28.0), str(model.step), MINCHO_B, int(30.0 * pop), accent, HORIZONTAL_ALIGNMENT_CENTER, 56.0)
	zone(down, [&"step", model.step - 1])
	zone(up, [&"step", model.step + 1])
	for level in DifficultySteps.MAX + 1:
		var spot := at + Vector2(210.0 + level * 26.0, 17.0)
		if level <= model.step:
			diamond(spot, 7.0, accent)
		elif level <= most:
			diamond(spot, 7.0, value)
			diamond(spot, 4.5, pal.ground)
		else:
			diamond(spot, 4.0, Color(dim, 0.45))
		if level <= most:
			zone(Rect2(spot - Vector2(13.0, 13.0), Vector2(26.0, 26.0)), [&"step", level])
	var y := at.y + 60.0
	text(Vector2(at.x, y), model.step_note(), GOTHIC, 17, value)
	var echo := model.step_echo()
	if not echo.is_empty():
		text(Vector2(at.x, y), echo, GOTHIC_B, 17, accent, HORIZONTAL_ALIGNMENT_RIGHT, wide)
	var hint := model.step_hint()
	if not hint.is_empty():
		y += 24.0
		text(Vector2(at.x, y), hint, GOTHIC, 14, dim)
	return y - at.y + 8.0


# The one action: setting out, or why it cannot be.
func go_button(rect: Rect2, pal: Dictionary) -> void:
	var can := model.open(chosen)
	var room := Rect2(rect.position + Vector2(refusal(), 0.0), rect.size)
	var lit := hovered(&"go") and can
	var leaving := 1.0 - departing()
	if can:
		var fill: Color = pal.go
		plate(room, fill.lightened(0.12 if lit else 0.0).lightened(0.5 * leaving), pal.go_edge, 4.0, 2.0)
		draw_rect(room.grow(-5.0), Color(pal.go_edge as Color, 0.35), false, 1.0)
	else:
		plate(room, pal.off, Color(pal.off_text as Color, 0.4), 4.0, 1.0)
	text(room.position + Vector2(0.0, room.size.y * 0.5 + 9.0), model.action(chosen), MINCHO_B, 24, pal.go_text if can else pal.off_text, HORIZONTAL_ALIGNMENT_CENTER, room.size.x)
	zone(rect, [&"go"])


# A backdrop painted by a shader, behind everything the screen draws.
func backdrop(code: String, params := {}) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	rect.material = material
	add_child(rect)
	return rect


# Value noise and its layered sum, for the backdrops' materials.
const NOISE := """
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return sum;
}
"""
