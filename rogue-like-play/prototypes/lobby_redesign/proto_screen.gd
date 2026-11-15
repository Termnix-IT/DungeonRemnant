class_name ProtoScreen
extends Control

# What the three lobby prototypes share: the lobby they show (ProtoLobby),
# one way of taking input (keys and pad through the ui_* actions, the
# pointer through zones named while drawing), a clock for their motion, the
# heroine, her line and the echo held drawn the same way, and a few drawing
# helpers. A prototype draws itself whole in _paint() every frame and
# answers _key(), _click() and _wheel(); it styles nothing through the
# game's theme, so each stands on its own look. All draw in a 1600x900 view.

const MINCHO_B := preload("res://ui/fonts/ShipporiMincho-Bold.ttf")
const MINCHO_M := preload("res://ui/fonts/ShipporiMincho-Medium.ttf")
const GOTHIC := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Regular.ttf")
const GOTHIC_B := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Bold.ttf")
const HALL := preload("res://art/hub/lobby_hall.png")
const HERO := preload("res://art/characters/mio_lobby.png")
const VIEW := Vector2(1600.0, 900.0)
const MOVE_TIME := 0.2
const ENTER_TIME := 0.5
const SPEECH_TIME := 4.0
const PALE := Color(0.95, 0.93, 0.88)
const DIM := Color(0.72, 0.69, 0.63)
const GOLD := Color(1.0, 0.84, 0.50)
const GILT := Color(0.84, 0.72, 0.48)
const INK := Color(0.04, 0.038, 0.04)

var model: ProtoLobby
# The entry under the cursor (its place in HubLobby.ENTRIES), and the one
# the cursor came from.
var chosen := 0
var from := 0
# Seconds since the screen was shown.
var clock := 0.0
var hover: Variant = null
var _zones: Array = []
var _kicks: Dictionary = {}
var _icons: Array[NavigationIcon] = []
var _icons_used := 0


func _init(of: ProtoLobby) -> void:
	model = of
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


# --- For the prototype to answer ---

func _paint() -> void:
	pass


# One of &"up", &"down", &"left", &"right", &"accept", &"cancel".
func _key(_action: StringName) -> void:
	pass


func _click(id: Variant) -> void:
	common_click(id)


func _wheel(_step: int) -> void:
	pass


# Moves the cursor to an entry.
func choose(index: int) -> void:
	var to := clampi(index, 0, model.count() - 1)
	if to == chosen:
		return
	from = chosen
	chosen = to
	kick(&"move")


# Enter: opens the entry under the cursor.
func enter() -> void:
	model.enter(chosen)
	kick(&"enter")


# A click on her: she says her next line.
func talk() -> void:
	model.talk()
	kick(&"talk")


# The zones every prototype names: [&"entry", index] (the cursor goes
# there; the one it is on already is entered), [&"enter", index] and [&"hero"].
func common_click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"entry":
			if what[1] == chosen:
				enter()
			else:
				choose(what[1])
		&"enter":
			choose(what[1])
			enter()
		&"hero":
			talk()


# Puts the screen in a named state for a screenshot: &"initial" (the
# departure), &"upgrade", &"status", &"codex", &"settings", and &"talk" (she
# has just spoken).
func pose(state: StringName) -> void:
	model.reset()
	_kicks.clear()
	chosen = maxi(0, [&"initial", &"upgrade", &"status", &"codex", &"settings"].find(state))
	from = chosen
	if state == &"talk":
		talk()
		_kicks[&"talk"] = clock - 0.3


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


# How far the cursor has come to the entry it is on (0 to 1).
func moved() -> float:
	return eased(&"move", MOVE_TIME)


# How forward an entry stands: 1 under the cursor, 0 otherwise, easing as
# the cursor moves.
func stand(index: int) -> float:
	if index == chosen:
		return moved() if from != chosen else 1.0
	return 1.0 - moved() if index == from else 0.0


# A flash as an entry is entered (1 to 0).
func entering() -> float:
	return 1.0 - clampf(since(&"enter") / ENTER_TIME, 0.0, 1.0)


# --- Input ---

func _draw() -> void:
	_zones.clear()
	_icons_used = 0
	_paint()
	for index in range(_icons_used, _icons.size()):
		_icons[index].hide()


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


# Whether the pointer rests on a zone that is about an entry.
func hovered(index: int) -> bool:
	return hover is Array and (hover as Array).size() > 1 and (hover as Array)[1] == index


# --- Parts the prototypes share ---

# The hall behind everything, darkened to `dark` (0 as painted, 1 black).
func hall(dark: float) -> void:
	picture(Rect2(Vector2.ZERO, VIEW), HALL, Color(1.0 - dark, 1.0 - dark, 1.0 - dark))


# An entry's mark (NavigationIcon), `size` across, centred at `at`.
func icon(kind: StringName, at: Vector2, size: float, tint := Color.WHITE) -> void:
	if _icons_used == _icons.size():
		var made := NavigationIcon.new()
		made.theme = preload("res://ui/theme/dungeon_theme.tres")
		add_child(made)
		_icons.append(made)
	var mark := _icons[_icons_used]
	_icons_used += 1
	if mark.kind != kind:
		mark.kind = kind
		mark.queue_redraw()
	mark.show()
	mark.size = Vector2(48.0, 48.0)
	mark.scale = Vector2.ONE * size / 48.0
	mark.position = at - Vector2.ONE * size * 0.5
	mark.modulate = tint


# The heroine standing with her soles at `feet`, `tall` high, with the pool
# of shade under her; a click on her figure makes her speak. Returns where
# her face is.
func heroine(feet: Vector2, tall: float, grounded := true) -> Vector2:
	var extent := Vector2(HERO.get_size().aspect(), 1.0) * tall
	var corner := feet - extent * HubLobby.FEET
	if grounded:
		glow(feet + Vector2(0.0, 6.0), 190.0, Color(0.0, 0.0, 0.0, 0.5))
	var lift := 3.0 * sin(clock * 1.4) + 10.0 * maxf(0.0, 1.0 - since(&"talk") / 0.25) * sin(since(&"talk") * 24.0)
	draw_texture_rect(HERO, Rect2(corner + Vector2(0.0, lift), extent), false, Color(0.92, 0.90, 0.88))
	zone(Rect2(corner + Vector2(extent.x * 0.24, extent.y * 0.05), Vector2(extent.x * 0.52, extent.y * 0.9)), [&"hero"])
	return corner + extent * HubLobby.FACE


# Her line in a dark strip beside her face, its tail toward her, while it lasts.
func speech(face: Vector2, to_left := true) -> void:
	if model.line.is_empty() or since(&"talk") > SPEECH_TIME:
		return
	var fade := minf(1.0, since(&"talk") / 0.15) * minf(1.0, (SPEECH_TIME - since(&"talk")) / 0.4)
	var wide := width_of(model.line, GOTHIC_B, 19) + 48.0
	var rect := Rect2(Vector2(face.x - 56.0 - wide if to_left else face.x + 56.0, face.y - 26.0), Vector2(wide, 52.0))
	rect.position.x = clampf(rect.position.x, 12.0, VIEW.x - wide - 12.0)
	plate(rect, Color(INK, 0.9 * fade), Color(GILT, 0.7 * fade), 6.0, 1.0)
	var tip := Vector2(rect.end.x if to_left else rect.position.x, rect.get_center().y)
	var way := 1.0 if to_left else -1.0
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-2.0 * way, -8.0), tip + Vector2(18.0 * way, 0.0), tip + Vector2(-2.0 * way, 8.0)]), Color(INK, 0.9 * fade))
	text(rect.position + Vector2(24.0, 33.0), model.line, GOTHIC_B, 19, Color(PALE, fade))


# The echo held, at the top right.
func purse() -> void:
	draw_circle(Vector2(1476.0, 46.0), 11.0, GILT)
	draw_circle(Vector2(1476.0, 46.0), 7.0, GILT.darkened(0.35))
	text(Vector2(1500.0, 58.0), str(model.meta.echo), MINCHO_B, 32, GOLD)
	draw_line(Vector2(1400.0, 74.0), Vector2(1556.0, 74.0), Color(GILT, 0.6), 1.0)


# The keys at the foot.
func keys(pairs: Array) -> void:
	var x := 52.0
	for pair: Array in pairs:
		text(Vector2(x, 866.0), pair[0], GOTHIC, 16, DIM)
		x += width_of(pair[0], GOTHIC, 16) + 16.0
		text(Vector2(x, 866.0), pair[1], GOTHIC, 16, PALE)
		x += width_of(pair[1], GOTHIC, 16) + 40.0


# An entry's two facts side by side, each its caption over its value.
func facts(index: int, at: Vector2, wide: float, tint := 1.0) -> void:
	var listed := model.facts(index)
	for place in listed.size():
		var x := at.x + wide * place / listed.size()
		text(Vector2(x, at.y), listed[place][0], GOTHIC, 14, Color(DIM, tint))
		text(Vector2(x, at.y + 34.0), listed[place][1], MINCHO_B, 24, Color(PALE, tint))


# The action that opens an entry: a gilt plate with its words.
func action(index: int, rect: Rect2, lit := true) -> void:
	var flash := entering() if index == chosen else 0.0
	var over: bool = hover is Array and (hover as Array)[0] == &"enter" and (hover as Array)[1] == index
	plate(rect, Color(0.36, 0.26, 0.10).lightened(0.5 * flash + (0.1 if over else 0.0)) if lit else Color(0.12, 0.11, 0.10), Color(GOLD if lit else GILT, 1.0 if lit else 0.4), 4.0, 2.0 if lit else 1.0)
	text(Vector2(rect.position.x, rect.get_center().y + 8.0), model.action(index), MINCHO_B, 22, Color(1.0, 0.95, 0.82) if lit else DIM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	zone(rect, [&"enter", index])


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
