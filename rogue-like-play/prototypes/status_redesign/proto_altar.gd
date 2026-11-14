class_name ProtoAltar
extends ProtoScreen

# Prototype C, the altar: a round altar of cold stone seen from above. Her
# four slots are sockets at its four quarters, where the arrow keys point:
# up the attack, left and right the two skills, down the special. A channel
# cut from each socket to the altar's heart runs with light while the socket
# holds something, so the build reads as a lit sigil. Enter on a socket
# wakes it: the stones it can hold rise onto the ring round the altar, and
# left/right turns the ring to bring another to the socket; Enter sets the
# stone and the light runs in to the heart. The thing under the hand is
# carved large on a stele at the right; her five main figures stand on a
# narrow stele at the left, and R raises the full tablet.

const FLOOR := """
shader_type canvas_item;
%s
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	vec2 slab = p / vec2(230.0, 150.0);
	slab.x += floor(slab.y) * 0.5;
	vec2 cell = fract(slab);
	float seam = smoothstep(0.0, 0.02, min(min(cell.x, 1.0 - cell.x), min(cell.y, 1.0 - cell.y) * 1.5));
	float rock = fbm(p * 0.008) * 0.55 + fbm(p * 0.045) * 0.3 + noise(p * 0.5) * 0.15;
	vec3 col = mix(vec3(0.050, 0.060, 0.072), vec3(0.150, 0.172, 0.196), rock);
	col *= 0.86 + 0.14 * hash(floor(slab));
	col *= mix(0.5, 1.0, seam);
	// The altar's dais: a paler round of stone with rings cut in it.
	vec2 c = vec2(664.0, 456.0);
	float d = length(p - c);
	float dais = smoothstep(372.0, 368.0, d);
	vec3 pale = mix(vec3(0.085, 0.100, 0.118), vec3(0.200, 0.226, 0.254), fbm(p * 0.012 + 40.0) * 0.6 + noise(p * 0.3) * 0.4);
	col = mix(col, pale, dais);
	col *= 1.0 - 0.55 * smoothstep(4.0, 0.0, abs(d - 368.0));
	col *= 1.0 - 0.4 * smoothstep(2.5, 0.0, abs(d - 322.0));
	col *= 1.0 - 0.3 * smoothstep(2.0, 0.0, abs(d - 268.0));
	col *= 1.0 - 0.3 * smoothstep(2.0, 0.0, abs(d - 124.0));
	float light = exp(-d / 420.0);
	col += vec3(0.20, 0.55, 0.70) * light * 0.10;
	col *= smoothstep(1.35, 0.3, length((UV - vec2(0.42, 0.5)) * vec2(1.15, 1.5)));
	COLOR = vec4(col, 1.0);
}
""" % NOISE

const PALE := Color("dde7ee")
const DIM := Color("8797a5")
const FAINT := Color("4c5966")
const LIGHT := Color("86e4ff")
const LIGHT_DEEP := Color("2a8db6")
const SLAB := Color("1b222a")
const SLAB_HI := Color("3b4753")
const HEART := Vector2(664.0, 456.0)
const SOCKET_REACH := 198.0
const SOCKET := 50.0
const ORBIT := 326.0
const STONE := 34.0
const STEP := 0.44
# The sockets' quarters: attack up, skill 1 left, skill 2 right, special down.
const ANGLES := [-PI * 0.5, PI, 0.0, PI * 0.5]
const QUARTER := {&"up": 0, &"left": 1, &"right": 2, &"down": 3}
const STELE := Rect2(1070.0, 96.0, 486.0, 712.0)
const NARROW := Rect2(36.0, 168.0, 212.0, 576.0)

var socket := 1
var awake := false
var index := 0
var tablet_open := false
var _spin := 0.0
var _set_slot := -1


func _init(of: ProtoBuild) -> void:
	super(of)
	backdrop(FLOOR)
	index = _held_index()
	_spin = index


func title() -> String:
	return "C　祭壇"


func hints() -> Array:
	if tablet_open:
		return [["R / Esc", "祭壇に戻る"]]
	if awake:
		return [["← →", "石を巡らせる"], ["Enter", "石を嵌める"], ["X", "外す"], ["Esc", "手を離す"]]
	return [["↑ ← → ↓", "窪みを選ぶ"], ["Enter", "石を呼ぶ"], ["X", "外す"], ["R", "碑文"], ["Esc", "戻る"]]


func _stones() -> Array:
	return build.choices(socket)


func _held_index() -> int:
	var stones := _stones()
	for at in stones.size():
		if stones[at].state == ProtoBuild.State.HERE:
			return at
	return 0


func _socket_at(slot: int) -> Vector2:
	return HEART + Vector2.from_angle(ANGLES[slot]) * SOCKET_REACH


func _choose(slot: int) -> void:
	if slot != socket:
		socket = slot
		index = _held_index()
		_spin = index
		kick(&"socket")


func _key(action: StringName) -> void:
	if action == &"details":
		tablet_open = not tablet_open
		kick(&"tablet")
		return
	if tablet_open:
		if action == &"cancel":
			tablet_open = false
		return
	if action == &"clear":
		if build.can_clear(socket):
			build.equip(socket, ProtoBuild.CLEAR)
		else:
			kick(&"refuse")
		return
	if not awake:
		if QUARTER.has(action):
			_choose(QUARTER[action])
		elif action == &"accept":
			awake = true
			kick(&"wake")
		return
	match action:
		&"left", &"up", &"prev":
			index = maxi(0, index - 1)
			kick(&"turn")
		&"right", &"down", &"next":
			index = mini(_stones().size() - 1, index + 1)
			kick(&"turn")
		&"accept":
			_set_stone()
		&"cancel":
			awake = false
			index = _held_index()


func _set_stone() -> void:
	var stone: Dictionary = _stones()[index]
	if not build.account(socket, stone.id).can:
		kick(&"refuse")
		return
	build.equip(socket, stone.id)
	awake = false


func _on_changed(slots: Array) -> void:
	_set_slot = socket if slots.has(socket) else int(slots[0])
	for slot: int in slots:
		kick(StringName("set%d" % slot))
	kick(&"set")
	index = _held_index()


func _click(id: Variant) -> void:
	var what: Array = id
	if what[0] == &"tablet":
		_key(&"details")
	elif tablet_open:
		return
	elif what[0] == &"socket":
		if socket == what[1] and not awake:
			awake = true
			kick(&"wake")
		elif socket != what[1]:
			awake = false
			_choose(what[1])
	elif what[0] == &"stone":
		if not awake:
			awake = true
			kick(&"wake")
		if index == what[1]:
			_set_stone()
		else:
			index = what[1]
			kick(&"turn")
	elif what[0] == &"set":
		_set_stone()


func _wheel(step: int) -> void:
	if awake:
		_key(&"right" if step > 0 else &"left")


func pose(state: StringName) -> void:
	socket = 1
	awake = false
	tablet_open = false
	index = _held_index()
	match state:
		&"browse":
			awake = true
			index = 2
		&"change":
			awake = true
			index = 1
		&"stats":
			tablet_open = true
	_spin = index
	_kicks.clear()


func _process(delta: float) -> void:
	_spin = lerpf(_spin, float(index), minf(1.0, delta * 14.0))
	super(delta)


# --- Drawing ---

func _paint() -> void:
	spaced(Vector2(48.0, 66.0), "祭壇", MINCHO_B, 30, PALE, 14.0)
	text(Vector2(48.0, 96.0), "四つの窪みに、力の石を嵌める", MINCHO_M, 15, DIM)
	_paint_channels()
	_paint_orbit()
	for slot in 4:
		_paint_socket(slot)
	_paint_heart()
	_paint_narrow()
	if tablet_open:
		_paint_tablet()
	else:
		_paint_stele()
	_paint_hints()


# A slab of stone with cut corners, lit along its upper and left edges.
func _slab(rect: Rect2, cut := 14.0, lit := 0.0) -> void:
	var a := rect.position
	var b := rect.end
	var points := PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut), Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut)])
	var under := PackedVector2Array()
	for point in points:
		under.append(point + Vector2(4.0, 7.0))
	draw_colored_polygon(under, Color(0.0, 0.0, 0.0, 0.5))
	var top := SLAB.lightened(0.06).lerp(LIGHT_DEEP, lit * 0.2)
	draw_polygon(points, PackedColorArray([top, top, top, SLAB.darkened(0.25), SLAB.darkened(0.25), SLAB.darkened(0.25), SLAB, top]))
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, Color(SLAB_HI, 0.55).lerp(LIGHT, lit), 1.0, true)
	draw_polyline(PackedVector2Array([points[7], points[0], points[1], points[2]]), Color(PALE, 0.22), 1.0, true)


# A key cut into a small stone plate; returns its width.
func _glyph(at: Vector2, key: String, lit := false) -> float:
	var width := maxf(26.0, GOTHIC_B.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
	plate(Rect2(at, Vector2(width, 24.0)), Color(LIGHT, 0.9) if lit else Color("0b0f13"), Color(PALE, 0.9) if lit else Color(DIM, 0.8), 3.0)
	text(Vector2(at.x, at.y + 17.0), key, GOTHIC_B, 13, Color("0b0f13") if lit else PALE, HORIZONTAL_ALIGNMENT_CENTER, width)
	return width


# The channels from the sockets to the heart, running with light when filled.
func _paint_channels() -> void:
	for slot in 4:
		var way := Vector2.from_angle(ANGLES[slot])
		var from := HEART + way * 112.0
		var to := HEART + way * (SOCKET_REACH - SOCKET - 8.0)
		draw_line(from, to, Color(0.0, 0.0, 0.0, 0.55), 7.0)
		if build.content(slot).is_empty():
			continue
		var surge := since(StringName("set%d" % slot))
		var strength := 0.55 + 0.12 * sin(clock * 1.6 + slot)
		draw_line(from, to, Color(LIGHT_DEEP, 0.5), 5.0, true)
		draw_line(from, to, Color(LIGHT, strength), 2.0, true)
		if surge < 0.5:
			var head := to.lerp(from, clampf(surge / 0.3, 0.0, 1.0))
			glow(head, 46.0, Color(LIGHT, 0.9 * (1.0 - surge / 0.5)))
			draw_line(to, head, Color(1.0, 1.0, 1.0, 1.0 - surge / 0.5), 4.0, true)


func _paint_heart() -> void:
	var filled := 0
	for slot in 4:
		filled += 0 if build.content(slot).is_empty() else 1
	var pulse := since(&"set")
	glow(HEART, 190.0, Color(LIGHT, 0.05 + 0.035 * filled))
	if pulse < 0.9 and pulse > 0.25:
		var share := (pulse - 0.25) / 0.65
		ring(HEART, 100.0 + 280.0 * share, Color(LIGHT, 0.7 * (1.0 - share)), 3.0)
	# What is under the hand, large at the heart.
	var stone := _under_hand()
	var id: StringName = stone.id
	draw_circle(HEART, 104.0, Color(0.02, 0.03, 0.04, 0.85))
	if id.is_empty() or id == ProtoBuild.CLEAR:
		for step in 30:
			ring(HEART, 86.0, Color(FAINT, 0.9), 1.5, TAU * step / 30.0, TAU * (step + 0.5) / 30.0)
		text(Vector2(HEART.x - 90.0, HEART.y + 10.0), "空", MINCHO_B, 34, FAINT, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	elif stone.state == ProtoBuild.State.UNKNOWN:
		emblem(HEART, 92.0, stone.emblem, Color(0.07, 0.09, 0.11))
		text(Vector2(HEART.x - 90.0, HEART.y + 12.0), "眠る石", MINCHO_B, 26, DIM, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	else:
		emblem(HEART, 92.0, stone.emblem)
	ring(HEART, 96.0, Color(0.0, 0.0, 0.0, 0.8), 6.0)
	ring(HEART, 100.0, Color(LIGHT, 0.35 + 0.15 * filled), 1.5)
	for tick in 4:
		var way := Vector2.from_angle(ANGLES[tick])
		draw_line(HEART + way * 100.0, HEART + way * 112.0, Color(LIGHT if not build.content(tick).is_empty() else FAINT, 0.9), 2.0, true)


# The thing the stele tells: the stone at the socket on the ring while the
# socket is awake, else what the socket holds.
func _under_hand() -> Dictionary:
	var stones := _stones()
	if awake:
		return stones[clampi(index, 0, stones.size() - 1)]
	var held := build.content(socket)
	for stone: Dictionary in stones:
		if stone.id == held:
			return stone
	return {id = &"", emblem = "", name = "空き", note = "", state = ProtoBuild.State.FREE, other = -1}


func _paint_socket(slot: int) -> void:
	var at := _socket_at(slot)
	var chosen := slot == socket and not tablet_open
	var held := build.content(slot)
	var set_at := since(StringName("set%d" % slot))
	zone_round(at, SOCKET + 14.0, [&"socket", slot])
	if chosen:
		glow(at, SOCKET * 2.6, Color(LIGHT, 0.22 if awake else 0.14))
	elif hovered(&"socket", slot):
		glow(at, SOCKET * 2.2, Color(LIGHT, 0.08))
	draw_circle(at + Vector2(0.0, 3.0), SOCKET + 9.0, Color(0.0, 0.0, 0.0, 0.6))
	draw_circle(at, SOCKET + 7.0, SLAB.darkened(0.3))
	if held.is_empty():
		draw_circle(at, SOCKET - 2.0, Color(0.015, 0.02, 0.026))
		for step in 16:
			ring(at, SOCKET - 10.0, Color(FAINT, 0.9), 1.5, TAU * step / 16.0, TAU * (step + 0.5) / 16.0)
	else:
		var settle := 1.0 + 0.3 * maxf(0.0, 1.0 - set_at / 0.16)
		emblem(at, SOCKET * settle, ProtoBuild.emblem_of(held), Color.WHITE if chosen or awake == false else Color(0.75, 0.8, 0.85))
	ring(at, SOCKET + 1.0, Color(0.0, 0.0, 0.0, 0.85), 4.0)
	ring(at, SOCKET + 7.0, Color(LIGHT if chosen else SLAB_HI, 1.0 if chosen else 0.8), 2.5 if chosen else 1.5)
	if chosen and awake:
		# The awake socket's rim turns, a slow mark of the rite under way.
		for mark in 3:
			var from := clock * 0.9 + TAU * mark / 3.0
			ring(at, SOCKET + 13.0, Color(LIGHT, 0.9), 2.0, from, from + 0.7)
	if set_at < 0.6:
		var fade := 1.0 - set_at / 0.6
		ring(at, SOCKET + 8.0 + 50.0 * (1.0 - fade), Color(LIGHT, fade), 3.0)
		draw_circle(at, SOCKET, Color(0.8, 0.97, 1.0, 0.55 * fade * fade))
	# The socket's key, cut on a plate at its inner edge, and its name.
	var inward := -Vector2.from_angle(ANGLES[slot])
	var key: String = ProtoBuild.SLOT_KEYS[slot]
	var width := maxf(26.0, GOTHIC_B.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
	var plate_at := at + inward * (SOCKET + 2.0) - Vector2(width * 0.5, 12.0)
	_glyph(plate_at, key, chosen)
	var label := at - inward * (SOCKET + 30.0) if awake == false or slot != socket else Vector2.INF
	if slot in [1, 2]:
		label = at + Vector2(0.0, -SOCKET - 22.0)
	if label != Vector2.INF and not (awake and slot == socket):
		text(Vector2(label.x - 80.0, label.y + 6.0), ProtoBuild.SLOT_NAMES[slot], MINCHO_M, 16, PALE if chosen else DIM, HORIZONTAL_ALIGNMENT_CENTER, 160.0)


# The stones the chosen socket can hold, on the ring round the altar: the
# one at the socket's quarter is under the hand.
func _paint_orbit() -> void:
	if tablet_open:
		return
	var stones := _stones()
	var rise := eased(&"wake", 0.25) if awake else 0.0
	var quarter: float = ANGLES[socket]
	for at in stones.size():
		var stone: Dictionary = stones[at]
		var offset := at - _spin
		var angle := quarter + offset * STEP
		var here := awake and at == index
		var near := 1.0 - clampf(absf(offset) / 4.2, 0.0, 1.0)
		var alpha := (0.22 + 0.78 * rise) * near
		if alpha <= 0.02:
			continue
		var reach := ORBIT - (16.0 * rise if here else 0.0)
		var centre := HEART + Vector2.from_angle(angle) * reach
		var radius := STONE + (9.0 if here else 0.0)
		zone_round(centre, radius + 6.0, [&"stone", at])
		_paint_stone(centre, radius, stone, here, alpha)
	if awake:
		# The hand's place on the ring: a bracket of light at the socket's quarter.
		ring(HEART, ORBIT + 40.0, Color(LIGHT, 0.8 * rise), 2.0, quarter - 0.16, quarter + 0.16)
		ring(HEART, ORBIT - 70.0, Color(LIGHT, 0.5 * rise), 1.5, quarter - 0.2, quarter + 0.2)


func _paint_stone(centre: Vector2, radius: float, stone: Dictionary, here: bool, alpha: float) -> void:
	var unknown: bool = stone.state == ProtoBuild.State.UNKNOWN
	if here:
		glow(centre, radius * 2.6, Color(LIGHT, 0.3))
	elif hovered(&"stone") and (hover as Array)[1] == _stones().find(stone):
		glow(centre, radius * 2.2, Color(LIGHT, 0.12))
	draw_circle(centre + Vector2(2.0, 4.0), radius + 5.0, Color(0.0, 0.0, 0.0, 0.5 * alpha))
	draw_circle(centre, radius + 5.0, Color(SLAB.lightened(0.08), alpha))
	if unknown:
		emblem(centre, radius, stone.emblem, Color(0.06, 0.075, 0.09, alpha))
		ring(centre, radius - 6.0, Color(FAINT, 0.7 * alpha), 1.0)
	else:
		emblem(centre, radius, stone.emblem, Color(1.0, 1.0, 1.0, alpha) if here else Color(0.72, 0.78, 0.84, alpha))
	ring(centre, radius + 5.0, Color(LIGHT if here else SLAB_HI, alpha), 2.5 if here else 1.0)
	# A stone set in a socket carries that socket's key; a thread of light
	# ties one set elsewhere to where it sits.
	if awake and (stone.state == ProtoBuild.State.HERE or stone.state == ProtoBuild.State.ELSEWHERE):
		var holder: int = stone.other
		var key: String = ProtoBuild.SLOT_KEYS[holder]
		var width := maxf(26.0, GOTHIC_B.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
		var out := (centre - HEART).normalized()
		if stone.state == ProtoBuild.State.ELSEWHERE and awake:
			draw_line(centre - out * (radius + 6.0), _socket_at(holder) + (centre - _socket_at(holder)).normalized() * (SOCKET + 10.0), Color(LIGHT, 0.35 * alpha), 1.0, true)
		var tag := centre + out * (radius + 22.0) - Vector2(width * 0.5, 12.0)
		plate(Rect2(tag, Vector2(width, 24.0)), Color(LIGHT_DEEP, 0.9 * alpha), Color(LIGHT, alpha), 3.0)
		text(Vector2(tag.x, tag.y + 17.0), key, GOTHIC_B, 13, Color(PALE, alpha), HORIZONTAL_ALIGNMENT_CENTER, width)


func _paint_narrow() -> void:
	_slab(NARROW)
	spaced(Vector2(NARROW.position.x + NARROW.size.x * 0.5, NARROW.position.y + 40.0), "器", MINCHO_B, 22, PALE, 0.0, true)
	draw_line(Vector2(NARROW.position.x + 30.0, NARROW.position.y + 56.0), Vector2(NARROW.end.x - 30.0, NARROW.position.y + 56.0), Color(LIGHT, 0.45), 1.0)
	var y := NARROW.position.y + 96.0
	for row: Array in build.main_stats():
		text(Vector2(NARROW.position.x, y), row[0], MINCHO_M, 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, NARROW.size.x)
		var value: String = row[1]
		text(Vector2(NARROW.position.x, y + 34.0), value, MINCHO_B, 26 if value.length() < 8 else 19, PALE, HORIZONTAL_ALIGNMENT_CENTER, NARROW.size.x)
		var added: String = row[2]
		if not added.is_empty():
			text(Vector2(NARROW.position.x, y + 54.0), added, GOTHIC, 12, LIGHT, HORIZONTAL_ALIGNMENT_CENTER, NARROW.size.x)
		y += 96.0
	var tab := Rect2(NARROW.position.x + 26.0, NARROW.end.y - 44.0, NARROW.size.x - 52.0, 28.0)
	plate(tab, Color(LIGHT, 0.14) if tablet_open or hovered(&"tablet") else Color(0.0, 0.0, 0.0, 0.3), Color(LIGHT, 0.7) if tablet_open else Color(DIM, 0.6), 3.0)
	var used := _glyph(tab.position + Vector2(4.0, 2.0), "R", tablet_open)
	text(Vector2(tab.position.x + used + 14.0, tab.position.y + 20.0), "祭壇に戻る" if tablet_open else "碑文を読む", MINCHO_M, 14, PALE)
	zone(tab, [&"tablet"])


func _paint_stele() -> void:
	var stone := _under_hand()
	var told := build.account(socket, stone.id)
	_slab(STELE, 22.0)
	var left := STELE.position.x + 44.0
	var width := STELE.size.x - 88.0
	var y := STELE.position.y + 62.0
	# Which socket the stele speaks for.
	var used := _glyph(Vector2(left, y - 18.0), ProtoBuild.SLOT_KEYS[socket], true)
	text(Vector2(left + used + 12.0, y), "%s の窪み" % ProtoBuild.SLOT_NAMES[socket], MINCHO_M, 17, LIGHT)
	y += 70.0
	text(Vector2(left, y - 44.0), told.kind, MINCHO_M, 15, DIM)
	text(Vector2(left, y + 12.0), told.name, MINCHO_B, 48, DIM if told.unknown else PALE, HORIZONTAL_ALIGNMENT_LEFT, width)
	y += 44.0
	var where := ""
	var where_colour := DIM
	match stone.state:
		ProtoBuild.State.HERE:
			where = "この窪みに嵌まっている"
			where_colour = LIGHT
		ProtoBuild.State.ELSEWHERE:
			where = "%s の窪みに嵌まっている" % ProtoBuild.SLOT_KEYS[stone.other]
			where_colour = LIGHT_DEEP.lightened(0.3)
		ProtoBuild.State.UNKNOWN:
			where = "まだ目覚めていない"
			where_colour = FAINT
	text(Vector2(left, y), where, MINCHO_M, 16, where_colour)
	y += 26.0
	draw_line(Vector2(left, y), Vector2(left + width, y), Color(PALE, 0.18), 1.0)
	draw_line(Vector2(left, y), Vector2(left + 60.0, y), LIGHT, 2.0)
	y += 46.0
	y += paragraph(Vector2(left, y), told.description, MINCHO_M, 19, Color(PALE, 0.9), width, 30.0, 4)
	for row: Array in told.figures:
		text(Vector2(left, y), row[0], MINCHO_M, 17, DIM)
		text(Vector2(left, y), row[1], MINCHO_B, 21, PALE, HORIZONTAL_ALIGNMENT_RIGHT, width)
		draw_line(Vector2(left, y + 14.0), Vector2(left + width, y + 14.0), Color(PALE, 0.12), 1.0)
		y += 46.0
	# What the hand can do now.
	var foot := STELE.end.y - 56.0
	if not awake:
		var cap := _glyph(Vector2(left, foot - 18.0), "Enter", true)
		text(Vector2(left + cap + 12.0, foot), "石を呼んで、嵌め替える", MINCHO_B, 18, PALE)
	elif told.can:
		var cap := _glyph(Vector2(left, foot - 18.0), "Enter", true)
		text(Vector2(left + cap + 12.0, foot), "この石を嵌める", MINCHO_B, 18, PALE)
		text(Vector2(left + cap + 12.0, foot + 26.0), told.outcome, MINCHO_M, 15, LIGHT)
		zone(Rect2(left, foot - 26.0, width, 60.0), [&"set"])
	elif stone.state == ProtoBuild.State.HERE:
		text(Vector2(left, foot), "すでにこの窪みに嵌まっている", MINCHO_M, 16, DIM)
	else:
		text(Vector2(left, foot), "この石はまだ嵌められない", MINCHO_M, 16, FAINT)
	if since(&"refuse") < 0.35:
		draw_line(Vector2(left, foot + 36.0), Vector2(left + width * (1.0 - since(&"refuse") / 0.35), foot + 36.0), Color(LIGHT, 0.8), 2.0)


func _paint_tablet() -> void:
	var rise := eased(&"tablet", 0.25)
	draw_rect(Rect2(260.0, 0.0, 1340.0, 900.0), Color(0.01, 0.015, 0.02, 0.62 * rise))
	var rect := Rect2(300.0, 96.0 + 20.0 * (1.0 - rise), 1252.0, 712.0)
	_slab(rect, 22.0, 0.3)
	var rows := build.stats()
	for group in 2:
		var left := rect.position.x + 56.0 + 590.0 * group
		var width := 536.0
		spaced(Vector2(left, rect.position.y + 66.0), ["戦う力", "探索と成長"][group], MINCHO_B, 26, PALE, 8.0)
		draw_line(Vector2(left, rect.position.y + 84.0), Vector2(left + width, rect.position.y + 84.0), Color(PALE, 0.18), 1.0)
		draw_line(Vector2(left, rect.position.y + 84.0), Vector2(left + 60.0, rect.position.y + 84.0), LIGHT, 2.0)
		var y := rect.position.y + 138.0
		for row: Array in rows:
			if row[5] != group:
				continue
			var right := left + width
			var added: String = row[2]
			if not added.is_empty():
				var added_width := GOTHIC.get_string_size(added, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				text(Vector2(right - added_width, y), added, GOTHIC, 14, LIGHT)
				right -= added_width + 8.0
			text(Vector2(left, y), row[0], MINCHO_M, 19, PALE)
			text(Vector2(left, y), row[1], MINCHO_B, 22, PALE, HORIZONTAL_ALIGNMENT_RIGHT, right - left)
			text(Vector2(left, y + 24.0), row[3], MINCHO_M, 13, DIM, HORIZONTAL_ALIGNMENT_LEFT, width)
			draw_line(Vector2(left, y + 38.0), Vector2(left + width, y + 38.0), Color(PALE, 0.1), 1.0)
			y += 76.0


func _paint_hints() -> void:
	var x := 300.0
	for pair: Array in hints():
		x += _glyph(Vector2(x, 846.0), pair[0]) + 8.0
		text(Vector2(x, 864.0), pair[1], MINCHO_M, 15, DIM)
		x += MINCHO_M.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 26.0
