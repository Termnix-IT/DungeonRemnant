class_name ProtoScreen
extends Control

# What the three help prototypes share: the help they show (the game's own
# topics and keys, HubSettings.HELP and HELP_KEYS), one way of taking input
# (keys and pad through the ui_* actions, the pointer through zones named
# while drawing), a clock for their motion, the night sky of the upgrades'
# chart behind them, and a few drawing helpers. A prototype draws itself
# whole in _paint() every frame and answers _key(), _click() and _wheel();
# it styles nothing through the game's theme. All draw in a 1600x900 view,
# in the colours of the upgrades' chart.

const MINCHO_B := preload("res://ui/fonts/ShipporiMincho-Bold.ttf")
const MINCHO_M := preload("res://ui/fonts/ShipporiMincho-Medium.ttf")
const GOTHIC := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Regular.ttf")
const GOTHIC_B := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Bold.ttf")
const SKY := preload("res://ui/star_chart/star_sky.gdshader")
const VIEW := Vector2(1600.0, 900.0)
const MOVE_TIME := 0.22
const VOID := Color(0.02, 0.03, 0.06)
const PANEL := Color(0.035, 0.05, 0.095)
const PALE := Color("e3e9f7")
const DIM := Color("94a0bd")
const FAINT := Color("7c88a6")
const DARK := Color("3f4962")
const GOLD := Color("ffdc92")
const BRASS := Color("c9a45c")
const BLUE := Color("8cc6ff")
const BREAKS := TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_MANDATORY

# The topic open (its place in HubSettings.HELP), and the one left.
var topic := 0
var from := 0
# The help was closed (Esc).
var closed := false
# Seconds since the screen was shown.
var clock := 0.0
var hover: Variant = null
var _zones: Array = []
var _kicks: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.show_behind_parent = true
	var night := ShaderMaterial.new()
	night.shader = SKY
	night.set_shader_parameter(&"extent", VIEW)
	night.set_shader_parameter(&"pole", Vector2(800.0, 120.0))
	night.set_shader_parameter(&"centre", VIEW * 0.5)
	night.set_shader_parameter(&"reach", VIEW * 0.5)
	sky.material = night
	add_child(sky)


# --- The help ---

static func count() -> int:
	return HubSettings.HELP.size()


static func title_of(index: int) -> String:
	return TranslationServer.translate(HubSettings.HELP[index][0])


# A topic's points, a line of its own each.
static func points_of(index: int) -> Array[String]:
	var listed: Array[String] = []
	for point: String in HubSettings.HELP[index][1]:
		listed.append(TranslationServer.translate(point))
	return listed


# The controls' table: [what it does, the keys, the pad's buttons] a row.
static func key_rows() -> Array:
	var rows := []
	for entry: Array in HubSettings.HELP_KEYS:
		rows.append([TranslationServer.translate(entry[0]), (entry[1] as Array).map(func(key: String) -> String: return TranslationServer.translate(key)), (entry[2] as Array).map(func(key: String) -> String: return TranslationServer.translate(key))])
	return rows


# --- For the prototype to answer ---

func _paint() -> void:
	pass


# One of &"up", &"down", &"left", &"right", &"accept", &"cancel".
func _key(action: StringName) -> void:
	if action == &"cancel":
		closed = true


func _click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"topic":
			open(what[1])
		&"close":
			closed = true


func _wheel(_step: int) -> void:
	pass


# Opens a topic.
func open(index: int) -> void:
	var to := clampi(index, 0, count() - 1)
	if to == topic:
		return
	from = topic
	topic = to
	kick(&"move")


# Puts the screen on a topic for a screenshot.
func pose(index: int) -> void:
	_kicks.clear()
	topic = index
	from = index
	closed = false
	_posed()


func _posed() -> void:
	pass


# --- Clock and one-shot motion ---

func _process(delta: float) -> void:
	if is_visible_in_tree():
		clock += delta
		queue_redraw()


func kick(what: StringName) -> void:
	_kicks[what] = clock


func since(what: StringName) -> float:
	return clock - float(_kicks.get(what, -1000.0))


# 0 to 1 over `time` seconds after kick(what), eased out.
func eased(what: StringName, time: float) -> float:
	var share := clampf(since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


# How far the page has come to the topic it shows (0 to 1).
func moved() -> float:
	return eased(&"move", MOVE_TIME)


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


func hovered(id: Array) -> bool:
	return hover is Array and hover == id


# --- Parts the prototypes share ---

func heading() -> void:
	text(Vector2(52.0, 62.0), "ヘルプ", MINCHO_B, 34, PALE)


# The keys at the foot.
func keys(pairs: Array) -> void:
	var x := 52.0
	for pair: Array in pairs:
		text(Vector2(x, 866.0), pair[0], GOTHIC, 16, DIM)
		x += width_of(pair[0], GOTHIC, 16) + 16.0
		text(Vector2(x, 866.0), pair[1], GOTHIC, 16, PALE)
		x += width_of(pair[1], GOTHIC, 16) + 40.0
	zone(Rect2(40.0, 844.0, 400.0, 32.0), [&"close"])


# How tall words stand when wrapped to a width.
func tall(words: String, font: Font, size: int, width: float) -> float:
	return font.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, BREAKS).y


# A point: a star by its first line, then the words; returns its height.
func point(at: Vector2, words: String, width: float, size: int, alpha := 1.0) -> float:
	HubUI.mark(self, at + Vector2(6.0, size * 0.62 - size), 4.0, Color(GOLD, alpha))
	draw_multiline_string(GOTHIC, at + Vector2(26.0, 0.0), words, HORIZONTAL_ALIGNMENT_LEFT, width - 26.0, size, -1, Color(PALE, alpha), BREAKS)
	return tall(words, GOTHIC, size, width - 26.0)


# A key on its cap; returns the cap's width.
func cap(at: Vector2, words: String, size := 15, alpha := 1.0) -> float:
	var wide := maxf(34.0, width_of(words, GOTHIC_B, size) + 18.0)
	plate(Rect2(at.x, at.y - size - 6.0, wide, size + 14.0), Color(PANEL, alpha), Color(BRASS, 0.8 * alpha), 4.0, 1.0)
	text(Vector2(at.x, at.y), words, GOTHIC_B, size, Color(PALE, alpha), HORIZONTAL_ALIGNMENT_CENTER, wide)
	return wide


# The controls' table: a row an action, its keys and its buttons on caps;
# returns its height.
func key_table(at: Vector2, width: float, alpha := 1.0) -> float:
	var second := at.x + width * 0.30
	var third := at.x + width * 0.66
	text(Vector2(second, at.y), "キーボード", GOTHIC, 14, Color(DIM, alpha))
	text(Vector2(third, at.y), "ゲームパッド", GOTHIC, 14, Color(DIM, alpha))
	var y := at.y + 38.0
	for row: Array in key_rows():
		text(Vector2(at.x, y), row[0], GOTHIC, 17, Color(PALE, alpha))
		for pair: Array in [[second, row[1]], [third, row[2]]]:
			var x: float = pair[0]
			for name: String in pair[1]:
				x += cap(Vector2(x, y), name, 15, alpha) + 8.0
		draw_line(Vector2(at.x, y + 14.0), Vector2(at.x + width, y + 14.0), Color(BRASS, 0.15 * alpha), 1.0)
		y += 40.0
	return y - at.y


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


# A painting filling a rect, cropped round `focus`, `zoom` closer.
func picture(rect: Rect2, art: Texture2D, tint := Color.WHITE, focus := Vector2(0.5, 0.5), zoom := 1.0) -> void:
	if art == null:
		return
	var full := art.get_size()
	var part := rect.size / (maxf(rect.size.x / full.x, rect.size.y / full.y) * zoom)
	draw_texture_rect_region(art, rect, Rect2((full - part) * focus, part), tint)


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




