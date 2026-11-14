class_name ProtoScreen
extends Control

# What the three status-page prototypes share: the build they show
# (ProtoBuild), one way of taking input (keys and pad through the ui_*
# actions, the pointer through zones named while drawing), a clock for their
# motion, and a few drawing helpers. A prototype draws itself whole in
# _paint() every frame and answers _key(), _click() and _wheel(); it styles
# nothing through the game's theme, so each stands on its own look.

const MINCHO_B := preload("res://ui/fonts/ShipporiMincho-Bold.ttf")
const MINCHO_M := preload("res://ui/fonts/ShipporiMincho-Medium.ttf")
const GOTHIC := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Regular.ttf")
const GOTHIC_B := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Bold.ttf")
const VIEW := Vector2(1600.0, 900.0)
# The medallions' painted picture without their bronze rim: this share of
# the texture's width, as a radius.
const EMBLEM_CORE := 0.36

var build: ProtoBuild
# Seconds since the screen was shown.
var clock := 0.0
var hover: Variant = null
var _zones: Array = []
var _kicks: Dictionary = {}


func _init(of: ProtoBuild) -> void:
	build = of
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	build.changed.connect(_on_changed)


# --- For the prototype to answer ---

func title() -> String:
	return ""


# [key, what it does] pairs for the foot of the screen.
func hints() -> Array:
	return []


func _paint() -> void:
	pass


# One of &"up", &"down", &"left", &"right", &"accept", &"cancel",
# &"details" (R), &"prev" (Q), &"next" (E), &"clear" (X).
func _key(_action: StringName) -> void:
	pass


func _click(_id: Variant) -> void:
	pass


func _wheel(_step: int) -> void:
	pass


func _on_changed(_slots: Array) -> void:
	pass


# Puts the screen in a named state for a screenshot: &"initial", &"browse",
# &"change", &"stats".
func pose(_state: StringName) -> void:
	pass


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


# --- Input ---

func _draw() -> void:
	_zones.clear()
	_paint()


func zone(rect: Rect2, id: Variant) -> void:
	_zones.append([rect, id])


func zone_round(centre: Vector2, radius: float, id: Variant) -> void:
	_zones.append([Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), id])


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
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_key(&"cancel")
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
		var named: Variant = {KEY_R: &"details", KEY_Q: &"prev", KEY_E: &"next", KEY_X: &"clear", KEY_DELETE: &"clear"}.get(event.keycode)
		if named != null:
			_key(named)
			get_viewport().set_input_as_handled()


# --- Drawing helpers ---

func text(at: Vector2, words: String, font: Font, size: int, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, at, words, align, width, size, colour)


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


func paragraph(at: Vector2, words: String, font: Font, size: int, colour: Color, width: float, line_gap := 8.0, max_lines := -1) -> float:
	draw_multiline_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, colour, TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_MANDATORY)
	var held := font.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_MANDATORY)
	return held.y + line_gap


# The picture inside a medallion, without its rim, as a disc.
func emblem(centre: Vector2, radius: float, key: String, tint := Color.WHITE) -> bool:
	var picture := EmblemIcons.texture(key)
	if picture == null:
		return false
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in 48:
		var turn := Vector2.from_angle(TAU * index / 48.0)
		points.append(centre + turn * radius)
		uvs.append(Vector2(0.5, 0.5) + turn * EMBLEM_CORE)
	draw_polygon(points, PackedColorArray([tint]), uvs, picture)
	return true


func ring(centre: Vector2, radius: float, colour: Color, width := 1.5, from := 0.0, to := TAU) -> void:
	draw_arc(centre, radius, from, to, maxi(24, int(radius * 0.9)), colour, width, true)


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


# Whether the pointer rests on a zone named [kind, a, b] (null matches any).
func hovered(kind: StringName, a: Variant = null, b: Variant = null) -> bool:
	if not hover is Array or (hover as Array)[0] != kind:
		return false
	var what: Array = hover
	return (a == null or what[1] == a) and (b == null or what[2] == b)
