class_name ProtoScreen
extends Control

# What the three status prototypes share: the status they show (ProtoStatus,
# which asks the shipped page's own rules), one way of taking input (keys and
# pad through the ui_* actions, the pointer through zones named while
# drawing), a clock for their motion, the night sky of the upgrades' chart
# behind them, and the parts all three draw the same way: the card that
# tells the entry under the cursor, and her figures in full. A prototype
# draws itself whole in _paint() every frame and answers _key(), _click()
# and _wheel(); it styles nothing through the game's theme. All draw in a
# 1600x900 view, in the colours of the upgrades' chart.

const MINCHO_B := preload("res://ui/fonts/ShipporiMincho-Bold.ttf")
const MINCHO_M := preload("res://ui/fonts/ShipporiMincho-Medium.ttf")
const GOTHIC := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Regular.ttf")
const GOTHIC_B := preload("res://art/third_party/biz_udp_gothic/BIZUDPGothic-Bold.ttf")
const SKY := preload("res://ui/star_chart/star_sky.gdshader")
const HERO := preload("res://art/characters/mio_lobby.png")
const VIEW := Vector2(1600.0, 900.0)
const MOVE_TIME := 0.18
const SEAL_TIME := 0.8
const REFUSE_TIME := 0.3
const VOID := Color(0.02, 0.03, 0.06)
const PANEL := Color(0.035, 0.05, 0.095)
const PALE := Color("e3e9f7")
const DIM := Color("94a0bd")
const FAINT := Color("7c88a6")
const DARK := Color("3f4962")
const GOLD := Color("ffdc92")
const BRASS := Color("c9a45c")
const BLUE := Color("8cc6ff")
const WARN := Color("f39584")
const CARD := Rect2(1104.0, 110.0, 440.0, 700.0)

var model: ProtoStatus
# Seconds since the screen was shown.
var clock := 0.0
var hover: Variant = null
var _zones: Array = []
var _kicks: Dictionary = {}


func _init(of: ProtoStatus) -> void:
	model = of
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
	night.set_shader_parameter(&"pole", _pole())
	night.set_shader_parameter(&"centre", VIEW * 0.5)
	night.set_shader_parameter(&"reach", VIEW * 0.5)
	sky.material = night
	add_child(sky)


# Where the sky's warm light is: the middle of what the prototype shows.
func _pole() -> Vector2:
	return Vector2(560.0, 470.0)


# --- For the prototype to answer ---

func _paint() -> void:
	pass


# One of &"up", &"down", &"left", &"right", &"accept", &"cancel",
# &"clear" (X), &"figures" (R), &"prev" (Q), &"next" (E).
func _key(_action: StringName) -> void:
	pass


func _click(id: Variant) -> void:
	common_click(id)


func _wheel(_step: int) -> void:
	pass


# Turns to a slot.
func slot_to(index: int) -> void:
	if model.turn_to(posmod(index, ProtoStatus.SLOT_COUNT)):
		kick(&"turn")


# Moves the cursor in the open slot's index.
func row_to(index: int) -> void:
	if model.move_to(index):
		kick(&"move")


# Enter: sets the entry under the cursor in the open slot.
func seal() -> void:
	kick(&"seal" if model.seal() else &"refuse")


# X: empties the open slot.
func clear() -> void:
	kick(&"seal" if model.clear() else &"refuse")


# R: her figures in full, and back.
func toggle_figures() -> void:
	model.figures_open = not model.figures_open
	kick(&"turn")


# The keys all three share: Enter, X, R, and Q / E through the slots.
func common_key(action: StringName) -> void:
	match action:
		&"accept":
			seal()
		&"clear":
			clear()
		&"figures":
			toggle_figures()
		&"prev":
			slot_to(model.slot - 1)
		&"next":
			slot_to(model.slot + 1)


# The zones every prototype names: [&"slot", index], [&"row", slot, index]
# (the cursor goes there; the entry it is on already is set), [&"seal"],
# [&"clear"] and [&"figures"].
func common_click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"slot":
			if model.figures_open:
				toggle_figures()
			slot_to(what[1])
		&"row":
			if what[1] == model.slot and what[2] == model.row:
				seal()
			else:
				slot_to(what[1])
				row_to(what[2])
		&"seal":
			seal()
		&"clear":
			clear()
		&"figures":
			toggle_figures()


# Puts the screen in a named state for a screenshot: &"initial" (the first
# skill slot, on what it holds), &"candidate" (a skill held nowhere),
# &"swap" (a skill the other slot holds), &"unknown" (one not learned),
# &"attack" (the weapons), &"sealed" (the moment a skill is set) and
# &"figures".
func pose(state: StringName) -> void:
	model.reset()
	_kicks.clear()
	match state:
		&"candidate":
			model.move_to(model.row_of(&"swallow_cut"))
		&"swap":
			model.move_to(model.row_of(&"thunder_flash"))
		&"unknown":
			model.move_to(model.row_of(&"blaze_ring"))
		&"attack":
			model.turn_to(0)
			model.move_to(model.row_of(&"spear"))
		&"sealed":
			model.move_to(model.row_of(&"swallow_cut"))
			seal()
			_kicks[&"seal"] = clock + 0.45
		&"figures":
			model.figures_open = true


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


# How far through the moment of an equip (0 to 1; 1 once over).
func sealing() -> float:
	return clampf(since(&"seal") / SEAL_TIME, 0.0, 1.0)


# A short sideways shake after a refusal.
func refusal() -> float:
	var share := clampf(since(&"refuse") / REFUSE_TIME, 0.0, 1.0)
	return sin(share * TAU * 2.0) * 5.0 * (1.0 - share)


func breath() -> float:
	return 0.5 + 0.5 * sin(clock * 3.0)


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
		var named: Variant = {KEY_X: &"clear", KEY_R: &"figures", KEY_Q: &"prev", KEY_E: &"next"}.get(event.keycode)
		if named != null:
			_key(named)
			get_viewport().set_input_as_handled()


func hovered(id: Array) -> bool:
	return hover is Array and hover == id


# --- Parts the prototypes share ---

# A thing's medallion: whole, or darkened to a shadow when not learned;
# nothing for an empty slot but a ring.
func medal(centre: Vector2, radius: float, key: String, known := true, alpha := 1.0) -> void:
	var art := EmblemIcons.texture(key) if not key.is_empty() else null
	if art == null:
		draw_circle(centre, radius * 0.86, Color(VOID, alpha))
		ring(centre, radius * 0.86, Color(DARK, alpha), 1.5)
		return
	var tint := Color(1.0, 1.0, 1.0, alpha) if known else Color(0.16, 0.19, 0.28, alpha)
	draw_texture_rect(art, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)


# The four rays of a star held, breathing.
func rays(centre: Vector2, radius: float, colour: Color) -> void:
	for index in 4:
		var way := Vector2.from_angle(TAU * index / 4.0 + PI * 0.25)
		draw_line(centre + way * (radius + 3.0), centre + way * (radius + 11.0 + 3.0 * breath()), colour, 1.5, true)


# The cursor: a ring with four ticks that turn.
func cursor(centre: Vector2, radius: float) -> void:
	ring(centre, radius, PALE, 2.0)
	for index in 4:
		var way := Vector2.from_angle(TAU * index / 4.0 + clock * 0.4)
		draw_line(centre + way * radius, centre + way * (radius + 8.0), PALE, 2.0, true)


func title(words: String) -> void:
	text(Vector2(52.0, 62.0), words, MINCHO_B, 34, PALE)
	draw_circle(Vector2(1476.0, 46.0), 11.0, BRASS)
	draw_circle(Vector2(1476.0, 46.0), 7.0, BRASS.darkened(0.35))
	text(Vector2(1500.0, 58.0), str(model.meta.echo), MINCHO_B, 32, GOLD)


# The keys at the foot.
func keys(pairs: Array) -> void:
	var x := 52.0
	for pair: Array in pairs:
		text(Vector2(x, 866.0), pair[0], GOTHIC, 16, DIM)
		x += width_of(pair[0], GOTHIC, 16) + 16.0
		text(Vector2(x, 866.0), pair[1], GOTHIC, 16, PALE)
		x += width_of(pair[1], GOTHIC, 16) + 40.0


# The card: the entry under the cursor in full. Its kind, medallion and
# name; what it is; its figures, each set beside that of what the slot holds
# now when the two differ; what setting it would do; and the one action.
func card(rect := CARD) -> void:
	var told := model.told()
	draw_rect(rect, PANEL)
	draw_rect(rect, Color(BRASS, 0.8), false, 1.0)
	draw_rect(rect.grow(-6.0), Color(BRASS, 0.3), false, 1.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		HubUI.mark(self, corner, 6.0, BRASS)
	if told.is_empty():
		return
	var mid := rect.get_center().x
	var left := rect.position.x + 30.0
	var inner := rect.size.x - 60.0
	var fade := 0.35 + 0.65 * maxf(eased(&"move", MOVE_TIME), eased(&"turn", MOVE_TIME)) if since(&"move") < 1.0 or since(&"turn") < 1.0 else 1.0
	var unknown: bool = told.unknown
	var lit := 1.0 - sealing()
	text(Vector2(rect.position.x, rect.position.y + 40.0), "%s　%s" % [model.slot_name(model.slot), told.kind], GOTHIC, 15, Color(DIM, fade), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	glow(Vector2(mid, rect.position.y + 118.0), 110.0, Color(GOLD if model.here() else BLUE, 0.12 + 0.4 * lit))
	medal(Vector2(mid, rect.position.y + 118.0), 58.0, told.emblem, not unknown, fade)
	text(Vector2(rect.position.x + 12.0, rect.position.y + 222.0), told.name, MINCHO_B, 32, Color(PALE if not unknown else DIM, fade), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 24.0)
	HubUI.hairline(self, Vector2(left, rect.position.y + 246.0), Vector2(left + inner, rect.position.y + 246.0), Color(BRASS, 0.5))
	var y := rect.position.y + 282.0
	y += paragraph(Vector2(left, y), told.description, GOTHIC, 17, Color(PALE, 0.92 * fade), inner, 12.0, 4)
	# Its figures, beside what the slot holds now where they differ.
	var held := model.held_figures()
	var listed: Array = told.figures
	for figure: Array in listed:
		text(Vector2(left, y + 20.0), figure[0], GOTHIC, 15, DIM)
		var now: String = held.get(figure[0], "")
		var differs: bool = not now.is_empty() and now != figure[1] and not model.here()
		text(Vector2(left, y + 20.0), figure[1], GOTHIC_B, 18, Color(GOLD if differs else PALE, fade), HORIZONTAL_ALIGNMENT_RIGHT, inner)
		if differs:
			text(Vector2(left, y + 40.0), "いま　" + now, GOTHIC, 14, FAINT, HORIZONTAL_ALIGNMENT_RIGHT, inner)
			y += 18.0
		draw_line(Vector2(left, y + 30.0), Vector2(left + inner, y + 30.0), Color(BRASS, 0.18), 1.0)
		y += 38.0
	var outcome: String = told.outcome
	if not outcome.is_empty():
		text(Vector2(left, rect.end.y - 104.0), outcome, GOTHIC, 16, Color(BLUE, fade), HORIZONTAL_ALIGNMENT_CENTER, inner)
	# The one action.
	var can: bool = told.can
	var button := Rect2(left + refusal(), rect.end.y - 84.0, inner, 56.0)
	var action: String = told.action if told.acts else ""
	if not action.is_empty():
		plate(button, Color(0.30, 0.22, 0.09).lightened(0.5 * lit) if can else Color(0.06, 0.07, 0.11), Color(GOLD if can else DARK, 1.0), 4.0, 2.0 if can else 1.0)
		text(Vector2(button.position.x, button.get_center().y + 8.0), action, MINCHO_B, 22, Color(1.0, 0.95, 0.82) if can else FAINT, HORIZONTAL_ALIGNMENT_CENTER, inner)
		zone(button, [&"seal"])


# Her figures in full: two groups side by side, each row its name, its
# value, what the upgrades add, and under them how it is made up.
func figures(rect: Rect2) -> void:
	draw_rect(rect, Color(PANEL, 0.94))
	draw_rect(rect, Color(BRASS, 0.8), false, 1.0)
	draw_rect(rect.grow(-6.0), Color(BRASS, 0.3), false, 1.0)
	var rows := model.stats()
	var half := (rect.size.x - 100.0) * 0.5
	for group in 2:
		var x := rect.position.x + 36.0 + group * (half + 28.0)
		var y := rect.position.y + 56.0
		text(Vector2(x, y), tr(HubStatus.GROUPS[group]), MINCHO_B, 24, GOLD)
		HubUI.trail(self, Vector2(x, y + 14.0), Vector2(x + half, y + 14.0), Color(BRASS, 0.7))
		y += 34.0
		for stat: Array in rows:
			if stat[5] != group:
				continue
			text(Vector2(x, y + 24.0), stat[0], GOTHIC, 17, PALE)
			var added: String = stat[2]
			var value_right := half - (width_of(added, GOTHIC, 14) + 8.0 if not added.is_empty() else 0.0)
			text(Vector2(x, y + 24.0), stat[1], MINCHO_B, 22, GOLD if stat[4] else PALE, HORIZONTAL_ALIGNMENT_RIGHT, value_right)
			if not added.is_empty():
				text(Vector2(x, y + 24.0), added, GOTHIC, 14, BLUE, HORIZONTAL_ALIGNMENT_RIGHT, half)
			draw_string(GOTHIC, Vector2(x, y + 46.0), stat[3], HORIZONTAL_ALIGNMENT_LEFT, half, 14, FAINT)
			draw_line(Vector2(x, y + 58.0), Vector2(x + half, y + 58.0), Color(BRASS, 0.15), 1.0)
			y += 68.0


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




