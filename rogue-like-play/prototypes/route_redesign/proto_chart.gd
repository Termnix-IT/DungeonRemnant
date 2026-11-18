class_name ProtoChart
extends ProtoScreen

# Prototype A, the expedition chart: the whole chapter on one sheet of old
# paper, nothing scrolled. Each area is drawn where it lies with the beast
# that leads it sketched over it, as old charts mark their dangers; the ways
# walked are inked in red, the ways ahead dotted, the boss a storm at the
# sheet's far end. Picking a way is plotting a course: the cursor draws a
# red course from her to an open area, and the arrows carry it on along the
# ways that lead from there, so a whole road to the boss can be pencilled in
# before the first leg is taken (Right: on a layer, Left: back, Up/Down:
# the other way at that fork). What the course's end is, a note pinned to
# the sheet's margin tells; the ways a pick would close fade as it is
# pointed at. Enter asks, Enter again goes: she walks the first leg and the
# view dives into the sheet.

const PAPER := preload("res://prototypes/route_redesign/chart_paper.gdshader")
const GRAIN := preload("res://art/ui/grimoire/paper.png")
const INK := Color("2b2118")
const SEPIA := Color("6d5a41")
const FAINT := Color("9a8866")
const RED := Color("9c2d20")
const BLUE := Color("2c5a80")
const OCHRE := Color("9c6a12")
const VIOLET := Color("5d3f83")
const SLIP := Color("f3ead4")
const NEATLINE := Rect2(34.0, 30.0, 1532.0, 840.0)
const NOTE := Rect2(1190.0, 62.0, 352.0, 500.0)
const CARRIED := Rect2(1190.0, 596.0, 352.0, 200.0)
# The map: where the start and the boss stand, the rows' middle and gap.
const START_X := 150.0
const END_X := 1104.0
const MIDDLE := 472.0
const ROW := 166.0
const FIGURE := 78.0
const HERO_HEIGHT := 76.0

# The course plotted: the open area under the cursor, then the areas the
# arrows carried it on to.
var plan: Array = []
# An area the pointer reads that the course does not pass.
var looked: RouteMap.Waypoint
var hero: DirectionalRig
var _spots: Dictionary = {}
var _curves: Dictionary = {}
var _strokes: Array = []
static var _sketches: Dictionary = {}


func _build() -> void:
	var sheet := ColorRect.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.show_behind_parent = true
	var paper := ShaderMaterial.new()
	paper.shader = PAPER
	paper.set_shader_parameter(&"paper_grain", GRAIN)
	sheet.material = paper
	add_child(sheet)
	hero = MIO_RIG.instantiate()
	hero.world_height = HERO_HEIGHT
	add_child(hero)
	hero.facing = Vector2i(1, 1)


func go_time() -> float:
	return 1.15


# --- The lay of the sheet ---

func _laid() -> void:
	plan = [model.selected()] if model.selected() != null else []
	looked = null
	_spots.clear()
	_curves.clear()
	var route := model.route
	var gap := (END_X - START_X) / route.size()
	for index in route.size():
		var points := route.nodes(index)
		for row in points.size():
			var point: RouteMap.Waypoint = points[row]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%d:%d" % [index, row]) + ProtoRoute.SEED
			var boss := point.area.boss != null
			var drift := Vector2.ZERO if boss else Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-16.0, 16.0))
			_spots[point] = Vector2(START_X + gap * (index + 1), MIDDLE + (row - (points.size() - 1) * 0.5) * ROW) + drift
	_strew()
	pivot_offset = Vector2.ZERO
	scale = Vector2.ONE
	if hero != null:
		hero.position = _stand()
		hero.facing = Vector2i(1, 1)
		hero.idle()


func _start() -> Vector2:
	return Vector2(START_X, MIDDLE)


func spot(point: RouteMap.Waypoint) -> Vector2:
	return _spots[point] if point != null else _start()


# Where she stands: on the ground of the area last taken.
func _stand() -> Vector2:
	return spot(model.here()) + Vector2(-4.0, 8.0)


# The drawn way between two places: a gentle S that wavers a little, as a
# hand draws it.
func way(from: RouteMap.Waypoint, to: RouteMap.Waypoint) -> PackedVector2Array:
	var key := [from, to]
	if _curves.has(key):
		return _curves[key]
	var a := spot(from)
	var b := spot(to)
	var bend := Vector2((b.x - a.x) * 0.5, 0.0)
	var side := (b - a).orthogonal().normalized()
	var phase := float(hash("%s>%s" % [a, b]) % 628) / 100.0
	var points := PackedVector2Array()
	for step in 29:
		var t := step / 28.0
		points.append(a.bezier_interpolate(a + bend, b - bend, b, t) + side * sin(t * TAU * 1.5 + phase) * 5.0 * sin(t * PI))
	_curves[key] = points
	return points


# The country round the route, in a few light strokes: the chapter's woods,
# kept clear of the places, the ways and the words.
func _strew() -> void:
	_strokes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(model.chapter.id))
	# [where, how much room it keeps] each.
	var kept: Array = []
	for point: RouteMap.Waypoint in _spots:
		kept.append([_spots[point], 92.0])
		for to: RouteMap.Waypoint in point.next:
			var path := way(point, to)
			for index in range(0, path.size(), 3):
				kept.append([path[index], 34.0])
	kept.append([_start(), 80.0])
	for point: RouteMap.Waypoint in model.route.nodes(0):
		var path := way(null, point)
		for index in range(0, path.size(), 3):
			kept.append([path[index], 34.0])
	var tries := 0
	while _strokes.size() < 150 and tries < 1600:
		tries += 1
		var at := Vector2(rng.randf_range(70.0, 1160.0), rng.randf_range(176.0, 800.0))
		if at.x < 520.0 and at.y < 250.0:
			continue
		if at.y > 786.0 and at.x < 640.0:
			continue
		var clear := true
		for other: Array in kept:
			var near: float = other[1]
			if absf(other[0].x - at.x) < near and absf(other[0].y - at.y) < near * 1.05:
				clear = false
				break
		if clear:
			_strokes.append([at, rng.randf_range(0.7, 1.25), rng.randi_range(0, 5)])
			kept.append([at, 34.0])


# --- Input ---

func lens() -> RouteMap.Waypoint:
	if looked != null:
		return looked
	return plan.back() if not plan.is_empty() else null


func _key(action: StringName) -> void:
	looked = null
	match action:
		&"up", &"down":
			var step := -1 if action == &"up" else 1
			if plan.size() <= 1:
				choose(posmod(model.cursor + step, maxi(1, model.open.size())))
				plan = [model.selected()]
			else:
				model.armed = false
				var siblings: Array = (plan[plan.size() - 2] as RouteMap.Waypoint).next
				plan[plan.size() - 1] = siblings[clampi(siblings.find(plan.back()) + step, 0, siblings.size() - 1)]
				kick(&"scout")
		&"right":
			var last: RouteMap.Waypoint = plan.back() if not plan.is_empty() else null
			if last != null and not last.next.is_empty():
				model.armed = false
				plan.append(last.next[0])
				kick(&"scout")
		&"left":
			if plan.size() > 1:
				model.armed = false
				plan.pop_back()
				kick(&"scout")
		_:
			super(action)


func number(index: int) -> void:
	choose(index)
	plan = [model.selected()]
	arm()


func _point(id: Variant) -> void:
	looked = null
	if not (id is Array and id[0] == &"node"):
		return
	var point: RouteMap.Waypoint = id[1]
	match model.mark(point):
		ProtoRoute.Mark.OPEN:
			if plan.is_empty() or plan[0] != point or plan.size() > 1:
				choose(model.open.find(point))
				plan = [point]
		ProtoRoute.Mark.AHEAD:
			var found := model.way_to(point, plan)
			if not found.is_empty():
				if found[0] != model.selected():
					choose(model.open.find(found[0]))
				model.armed = false
				plan = found
				kick(&"scout")
		_:
			looked = point


func _click(id: Variant) -> void:
	var what: Array = id
	if what[0] == &"node":
		var point: RouteMap.Waypoint = what[1]
		if model.mark(point) == ProtoRoute.Mark.OPEN:
			plan = [point]
			common_click([&"open", model.open.find(point)])
	else:
		common_click(id)


func _pose_detail() -> void:
	var first := model.selected()
	plan = [first, first.next[mini(1, first.next.size() - 1)]]


# --- Painting ---

func ink_of(reward: int) -> Color:
	return {AreaData.Reward.BOON: OCHRE, AreaData.Reward.HEAL: RED, AreaData.Reward.ECHO: BLUE}.get(reward, VIOLET)


func _paint() -> void:
	if plan.is_empty() and model.selected() != null:
		plan = [model.selected()]
	_frame()
	_country()
	_ways()
	_places()
	_note()
	_carried()
	_foot()
	_walk()


# The neatline, the title, the compass.
func _frame() -> void:
	draw_rect(NEATLINE, Color(INK, 0.75), false, 1.5)
	draw_rect(NEATLINE.grow(-5.0), Color(INK, 0.35), false, 1.0)
	for step in int(NEATLINE.size.x / 80.0) + 1:
		var x := NEATLINE.position.x + step * 80.0
		draw_line(Vector2(x, NEATLINE.position.y), Vector2(x, NEATLINE.position.y + 5.0), Color(INK, 0.5), 1.0)
		draw_line(Vector2(x, NEATLINE.end.y - 5.0), Vector2(x, NEATLINE.end.y), Color(INK, 0.5), 1.0)
	spaced(Vector2(72.0, 78.0), "遠征図", GOTHIC_B, 13, RED, 6.0)
	text(Vector2(160.0, 78.0), Chapters.short_name(model.chapter), GOTHIC, 14, SEPIA)
	text(Vector2(70.0, 126.0), Chapters.title(model.chapter), MINCHO_B, 40, INK)
	var wide := width_of(Chapters.title(model.chapter), MINCHO_B, 40)
	draw_line(Vector2(72.0, 140.0), Vector2(72.0 + wide + 60.0, 140.0), Color(INK, 0.8), 1.5)
	draw_line(Vector2(72.0, 144.0), Vector2(72.0 + wide + 60.0, 144.0), Color(INK, 0.35), 1.0)
	text(Vector2(72.0, 168.0), "%s　／　%s" % [layer_words(), span_words()], GOTHIC, 15, SEPIA)
	if not model.note.is_empty():
		text(Vector2(72.0, 194.0), model.note, MINCHO_M, 16, Color(RED, 0.9))
	# The compass.
	var rose := Vector2(1092.0, 756.0)
	ring(rose, 30.0, Color(INK, 0.55), 1.0)
	ring(rose, 24.0, Color(INK, 0.3), 1.0)
	for index in 8:
		var way_out := Vector2.from_angle(TAU * index / 8.0 - PI * 0.5)
		var reach := 40.0 if index % 2 == 0 else 20.0
		var side := way_out.orthogonal() * (5.0 if index % 2 == 0 else 3.0)
		draw_colored_polygon(PackedVector2Array([rose + way_out * reach, rose + side, rose - side]), Color(INK, 0.7 if index % 4 == 0 else 0.4))
	text(Vector2(rose.x - 5.0, rose.y - 46.0), "N", MINCHO_B, 14, Color(INK, 0.7))


# The woods and hills strewn over the sheet, and the heights round the boss.
func _country() -> void:
	var soft := Color(SEPIA, 0.5)
	for stroke: Array in _strokes:
		var at: Vector2 = stroke[0]
		var size: float = stroke[1]
		if stroke[2] <= 3:
			# A fir: its trunk and three boughs.
			draw_line(at, at + Vector2(0.0, -6.0 * size), soft, 1.0, true)
			for bough in 3:
				var top := at + Vector2(0.0, (-22.0 + bough * 5.0) * size)
				var half := (4.0 + bough * 2.2) * size
				draw_polyline(PackedVector2Array([top + Vector2(-half, 7.0 * size), top, top + Vector2(half, 7.0 * size)]), soft, 1.0, true)
		else:
			# A rise of the ground.
			draw_arc(at + Vector2(0.0, 6.0), 13.0 * size, PI * 1.15, PI * 1.85, 10, soft, 1.0, true)
			draw_arc(at + Vector2(15.0 * size, 8.0), 9.0 * size, PI * 1.2, PI * 1.8, 8, Color(soft, soft.a * 0.7), 1.0, true)
	var lair := spot(model.route.nodes(model.route.size() - 1)[0])
	for index in 4:
		var radius := 84.0 + index * 22.0
		draw_arc(lair + Vector2(8.0, 0.0), radius, -PI * 0.42 + index * 0.1, PI * 0.42 - index * 0.07, 24, Color(SEPIA, 0.3 - index * 0.05), 1.0, true)
		draw_arc(lair + Vector2(-8.0, 0.0), radius, PI * 0.62 + index * 0.06, PI * 1.38 - index * 0.09, 24, Color(SEPIA, 0.3 - index * 0.05), 1.0, true)


# How plainly a place within reach is drawn while a course is plotted: the
# ways the cursor's pick would close fade.
func _kept(point: RouteMap.Waypoint) -> float:
	if model.selected() == null or model.mark(point) != ProtoRoute.Mark.AHEAD:
		return 1.0
	var lost := model.closes(model.selected()).has(point)
	return lerpf(1.0, 0.3, eased(&"move", 0.3)) if lost else 1.0


func _ways() -> void:
	var route := model.route
	var walked := model.run.taken
	var here := model.here()
	var opening := eased(&"open", OPEN_TIME)
	# From the start.
	for point: RouteMap.Waypoint in route.nodes(0):
		_way(null, point, walked, here, opening)
	for index in route.size() - 1:
		for from: RouteMap.Waypoint in route.nodes(index):
			for to: RouteMap.Waypoint in from.next:
				_way(from, to, walked, here, opening)
	# The course: its first leg in red, the legs pencilled on beyond it.
	if plan.is_empty():
		return
	var first := way(here, plan[0])
	var drawn := minf(opening, eased(&"move", 0.32) if since(&"move") < 1.0 else 1.0)
	var bold := 3.4 + 1.2 * arming()
	if model.armed:
		draw_polyline(_part(first, drawn), RED, bold, true)
	else:
		dashes(first, RED, bold, 13.0, 7.0, -clock * 22.0, drawn)
	_arrow(first, drawn, RED)
	for index in range(1, plan.size()):
		var leg := way(plan[index - 1], plan[index])
		var reach := eased(&"scout", 0.25) if index == plan.size() - 1 and since(&"scout") < 1.0 else 1.0
		dashes(leg, Color(RED, 0.75), 2.4, 9.0, 7.0, -clock * 14.0, reach)
		_arrow(leg, reach, Color(RED, 0.75), 0.8)


func _way(from: RouteMap.Waypoint, to: RouteMap.Waypoint, walked: Array, here: RouteMap.Waypoint, opening: float) -> void:
	var path := way(from, to)
	var at := walked.find(to)
	if at >= 0 and (from == null and at == 0 or at > 0 and walked[at - 1] == from):
		# Walked: inked in red, with the dots of her camps along it.
		draw_polyline(path, Color(RED, 0.9), 2.6, true)
		for step in range(4, 28, 6):
			draw_circle(path[step], 2.6, Color(RED, 0.9))
		return
	if from == here and model.open.has(to):
		if plan.is_empty() or plan[0] != to:
			dashes(path, Color(INK, 0.8 - 0.55 * arming()), 2.2, 10.0, 7.0, 0.0, opening)
		return
	if from != null and model.reach.has(from) and from.layer >= model.run.layer:
		var keep := minf(_kept(from), _kept(to))
		dashes(path, Color(SEPIA, 0.72 * keep), 1.5, 6.0, 6.0)
		return
	dashes(path, Color(FAINT, 0.4), 1.0, 2.0, 7.0)


func _part(points: PackedVector2Array, upto: float) -> PackedVector2Array:
	var count := maxi(2, int(ceil(points.size() * clampf(upto, 0.0, 1.0))))
	return points.slice(0, count)


func _arrow(path: PackedVector2Array, upto: float, colour: Color, size := 1.0) -> void:
	if upto < 0.2:
		return
	var tip := along(path, upto * 0.86)
	var back := along(path, upto * 0.86 - 0.02)
	var heading := (tip - back).normalized()
	var side := heading.orthogonal()
	draw_colored_polygon(PackedVector2Array([tip + heading * 11.0 * size, tip - heading * 5.0 * size + side * 7.0 * size, tip - heading * 5.0 * size - side * 7.0 * size]), colour)


func _places() -> void:
	# The camp she set out from.
	var camp := _start()
	_ground(camp, 30.0, Color(INK, 0.7))
	draw_line(camp + Vector2(-16.0, 0.0), camp + Vector2(-16.0, -34.0), Color(INK, 0.8), 1.5, true)
	draw_colored_polygon(PackedVector2Array([camp + Vector2(-16.0, -34.0), camp + Vector2(4.0, -28.0), camp + Vector2(-16.0, -21.0)]), Color(RED, 0.85))
	text(Vector2(camp.x - 40.0, camp.y + 30.0), "出発", MINCHO_M, 15, SEPIA, HORIZONTAL_ALIGNMENT_CENTER, 80.0)
	for index in model.route.size():
		for point: RouteMap.Waypoint in model.route.nodes(index):
			_place(point)


func _place(point: RouteMap.Waypoint) -> void:
	var at := spot(point)
	var state := model.mark(point)
	var told := model.tell(point)
	var boss: bool = told.boss
	var alpha: float = {ProtoRoute.Mark.OPEN: 1.0, ProtoRoute.Mark.TAKEN: 0.95, ProtoRoute.Mark.AHEAD: 0.78, ProtoRoute.Mark.SHUT: 0.26, ProtoRoute.Mark.PASSED: 0.26}[state] * _kept(point)
	if state == ProtoRoute.Mark.OPEN and point != model.selected():
		alpha *= 1.0 - 0.6 * arming()
	var tall := FIGURE * (1.5 if boss else 1.0)
	zone(Rect2(at - Vector2(56.0, tall + 8.0), Vector2(112.0, tall + 62.0)), [&"node", point])
	var pointed := hovered([&"node", point])
	if told.veiled:
		# The boss in the dark: a storm over the heights.
		for layer in 3:
			glow(at + Vector2(-10.0 + layer * 12.0, -44.0 + layer * 6.0), 82.0 - layer * 14.0, Color(INK, 0.5), 0.8)
		for index in 5:
			var turn := clock * 0.12 + index * 1.3
			draw_arc(at + Vector2(0.0, -40.0), 46.0 + index * 9.0, turn, turn + 1.5, 16, Color(INK, 0.4), 1.5, true)
		text(Vector2(at.x - 40.0, at.y - 24.0), "？", MINCHO_B, 48, Color(SLIP, 0.92), HORIZONTAL_ALIGNMENT_CENTER, 80.0)
		text(Vector2(at.x - 60.0, at.y + 34.0), "？？？", MINCHO_B, 17, Color(INK, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		return
	_ground(at, 40.0 if not boss else 56.0, Color(INK, 0.75 * alpha))
	var here := point == model.here()
	if state != ProtoRoute.Mark.TAKEN:
		var art := figure_of(point)
		if art != null:
			var shown := art if state == ProtoRoute.Mark.OPEN else sketch(art)
			fit(Rect2(at.x - tall * 0.62, at.y - tall + 6.0, tall * 1.24, tall), shown, Color(1.0, 1.0, 1.0, alpha), true)
	elif not here:
		# Cleared: a red tick over empty ground.
		draw_polyline(PackedVector2Array([at + Vector2(-12.0, -18.0), at + Vector2(-3.0, -8.0), at + Vector2(16.0, -34.0)]), Color(RED, 0.85), 3.0, true)
	# Its name, where she has been or can go now; its signs everywhere.
	var named := state == ProtoRoute.Mark.OPEN or state == ProtoRoute.Mark.TAKEN or pointed or plan.has(point)
	var y := at.y + 30.0
	if named:
		text(Vector2(at.x - 90.0, y), told.name, MINCHO_B, 17 if state == ProtoRoute.Mark.OPEN else 15, Color(INK, maxf(alpha, 0.8)), HORIZONTAL_ALIGNMENT_CENTER, 180.0)
		y += 21.0
	if state != ProtoRoute.Mark.TAKEN:
		_signs(Vector2(at.x, y - 5.0), told, maxf(alpha, 0.45), 0.85 if state != ProtoRoute.Mark.OPEN else 1.0)
	if state == ProtoRoute.Mark.OPEN:
		# Its key, in a red ring.
		var key := at + Vector2(-50.0, -tall + 4.0)
		var pop := eased(&"open", OPEN_TIME)
		draw_circle(key, 13.0 * pop, Color(SLIP, 0.95))
		ring(key, 13.0 * pop, RED, 1.5)
		text(Vector2(key.x - 12.0, key.y + 6.0), NUMERALS[model.open.find(point)], MINCHO_B, 17, RED, HORIZONTAL_ALIGNMENT_CENTER, 24.0)
	if not plan.is_empty() and plan[0] == point:
		_circle(at + Vector2(0.0, -tall * 0.36), Vector2(70.0, tall * 0.5 + 34.0), RED, 2.6 + arming() * 1.4, eased(&"move", 0.32) if since(&"move") < 1.0 else 1.0)
		if arming() > 0.0:
			_stamp(at + Vector2(54.0, -tall - 2.0), "出立", arming())
	elif plan.has(point):
		_circle(at + Vector2(0.0, -tall * 0.36), Vector2(62.0, tall * 0.5 + 28.0), Color(RED, 0.6), 1.6, eased(&"scout", 0.25) if plan.back() == point and since(&"scout") < 1.0 else 1.0)
	elif pointed:
		_circle(at + Vector2(0.0, -tall * 0.36), Vector2(62.0, tall * 0.5 + 28.0), Color(INK, 0.45), 1.2, 1.0)


# The ground a place stands on: an oval of ink with a few strokes of shade.
func _ground(at: Vector2, half: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for step in 33:
		var turn := TAU * step / 32.0
		points.append(at + Vector2(cos(turn) * half, sin(turn) * half * 0.26))
	draw_polyline(points, colour, 1.3, true)
	for index in 5:
		var x := at.x + half * (0.15 + index * 0.16)
		draw_line(Vector2(x, at.y + half * 0.26 + 2.0), Vector2(x - 7.0, at.y + half * 0.26 + 8.0), Color(colour, colour.a * 0.55), 1.0, true)


# A place's signs in a row: its danger as peaks, then what it gives.
func _signs(centre: Vector2, told: Dictionary, alpha: float, size: float) -> void:
	var danger: int = told.danger
	var gives: bool = told.reward >= 0 or told.event
	var wide := danger * 13.0 * size + (22.0 * size if gives else 0.0) + (6.0 if danger > 0 and gives else 0.0)
	var x := centre.x - wide * 0.5
	for index in danger:
		draw_colored_polygon(PackedVector2Array([Vector2(x + 5.5 * size, centre.y - 6.0 * size), Vector2(x + 11.0 * size, centre.y + 5.0 * size), Vector2(x, centre.y + 5.0 * size)]), Color(RED, alpha))
		x += 13.0 * size
	if gives:
		if danger > 0:
			x += 6.0
		sign_of(Vector2(x + 9.0 * size, centre.y), 7.5 * size, told.reward, Color(ink_of(told.reward), alpha))


# A ring drawn round a place by hand: not quite closed where it began, and
# running a little past it.
func _circle(centre: Vector2, radii: Vector2, colour: Color, width: float, upto: float) -> void:
	var points := PackedVector2Array()
	var steps := int(56.0 * clampf(upto, 0.0, 1.0))
	for step in steps + 1:
		var turn := -PI * 0.62 + TAU * 1.07 * step / 56.0
		var swell := 1.0 + 0.035 * sin(turn * 2.0 + 0.6) + 0.05 * step / 56.0
		points.append(centre + Vector2(cos(turn) * radii.x, sin(turn) * radii.y) * swell)
	if points.size() >= 2:
		draw_polyline(points, colour, width, true)


# A red seal struck on the sheet.
func _stamp(centre: Vector2, words: String, share: float) -> void:
	var size := lerpf(1.7, 1.0, share)
	draw_set_transform(centre, -0.16, Vector2.ONE * size)
	var colour := Color(RED, 0.92 * share)
	plate(Rect2(-33.0, -19.0, 66.0, 38.0), Color(RED, 0.08 * share), colour, 4.0, 2.0)
	draw_rect(Rect2(-29.0, -15.0, 58.0, 30.0), Color(colour, colour.a * 0.5), false, 1.0)
	text(Vector2(-33.0, 8.0), words, MINCHO_B, 21, colour, HORIZONTAL_ALIGNMENT_CENTER, 66.0)
	draw_set_transform(Vector2.ZERO)


# The note pinned to the margin: what the course's end is.
func _note() -> void:
	var point := lens()
	if point == null:
		return
	var told := model.tell(point)
	# A thread from the note to the place it tells of.
	var end := spot(point) + Vector2(60.0, -FIGURE * 0.5)
	var from := Vector2(NOTE.position.x + 2.0, NOTE.position.y + 116.0)
	if end.x < from.x - 40.0:
		draw_polyline(PackedVector2Array([from, Vector2(from.x - 36.0, from.y), end]), Color(INK, 0.5), 1.0, true)
		draw_circle(end, 3.0, Color(INK, 0.7))
	draw_set_transform(NOTE.get_center(), 0.012)
	var rect := Rect2(-NOTE.size * 0.5, NOTE.size)
	plate(Rect2(rect.position + Vector2(5.0, 8.0), rect.size), Color(0.0, 0.0, 0.0, 0.22), Color.TRANSPARENT, 2.0)
	plate(rect, SLIP, Color(INK, 0.35), 2.0)
	draw_circle(Vector2(0.0, rect.position.y + 14.0), 6.0, Color("7a5a2a"))
	draw_circle(Vector2(-1.5, rect.position.y + 12.5), 2.2, Color("e2c88c"))
	var left := rect.position.x + 26.0
	var wide := rect.size.x - 52.0
	var y := rect.position.y + 54.0
	var fade := 0.3 + 0.7 * maxf(eased(&"move", MOVE_TIME), eased(&"scout", MOVE_TIME)) if since(&"move") < 0.6 or since(&"scout") < 0.6 else 1.0
	spaced(Vector2(left, y), told.kind, GOTHIC_B, 13, Color(SEPIA, fade), 3.0)
	var state: String = told.state
	if not state.is_empty():
		text(Vector2(left, y), state, GOTHIC_B, 13, Color(RED, fade), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y += 44.0
	text(Vector2(left, y), told.name, MINCHO_B, 30, Color(INK, fade))
	y += 16.0
	draw_line(Vector2(left, y), Vector2(left + wide, y), Color(INK, 0.7), 1.5)
	draw_line(Vector2(left, y + 4.0), Vector2(left + wide, y + 4.0), Color(INK, 0.3), 1.0)
	y += 34.0
	if told.veiled:
		paragraph(Vector2(left, y), told.goal, MINCHO_M, 17, Color(INK, fade), wide)
	elif told.event:
		text(Vector2(left, y), "戦闘なし", GOTHIC_B, 15, Color(VIOLET, fade))
		y += 34.0
		sign_of(Vector2(left + 9.0, y - 6.0), 8.0, -1, Color(VIOLET, fade))
		y += paragraph(Vector2(left + 28.0, y), told.reward_words, MINCHO_B, 19, Color(VIOLET, fade), wide - 28.0, 14.0)
		y += paragraph(Vector2(left, y), told.summary, GOTHIC, 15, Color(SEPIA, fade), wide, 10.0)
	else:
		text(Vector2(left, y), "脅威", GOTHIC, 14, SEPIA)
		for index in 3:
			var x := left + 44.0 + index * 19.0
			var peak := PackedVector2Array([Vector2(x + 8.0, y - 14.0), Vector2(x + 16.0, y + 1.0), Vector2(x, y + 1.0)])
			if index < told.danger:
				draw_colored_polygon(peak, Color(RED, fade))
			else:
				peak.append(peak[0])
				draw_polyline(peak, Color(SEPIA, 0.6), 1.0, true)
		text(Vector2(left, y), "目安 " + told.time, GOTHIC, 14, SEPIA, HORIZONTAL_ALIGNMENT_RIGHT, wide)
		y += 38.0
		if told.boss:
			text(Vector2(left, y), tr(point.area.boss.epithet), MINCHO_M, 16, Color(RED, fade))
			y += 30.0
		else:
			var gives: Color = ink_of(told.reward)
			sign_of(Vector2(left + 10.0, y - 7.0), 9.0, told.reward, Color(gives, fade))
			var words: String = "残響 %s" % UIFormat.amount(told.echo) if told.reward == AreaData.Reward.ECHO else told.reward_words
			text(Vector2(left + 30.0, y), words, MINCHO_B, 22, Color(gives, fade))
			if told.reward != AreaData.Reward.ECHO and told.echo > 0:
				text(Vector2(left, y), "＋ 残響 %s" % UIFormat.amount(told.echo), GOTHIC, 15, Color(BLUE, fade), HORIZONTAL_ALIGNMENT_RIGHT, wide)
			y += 36.0
		y += paragraph(Vector2(left, y), told.goal, MINCHO_M, 17, Color(INK, fade), wide, 14.0)
		var x := left
		var foes: Array = told.foes
		var each := minf(48.0, wide / maxf(1.0, foes.size()))
		for entry: Array in foes:
			var tile := foe_tile(entry[0], entry[1])
			if tile != null:
				draw_texture_rect(tile, Rect2(x, y + 42.0 - (each - 5.0), each - 5.0, each - 5.0), false, Color(1.0, 1.0, 1.0, fade))
			x += each
		y += 62.0
		y += paragraph(Vector2(left, y), told.summary, GOTHIC, 14, Color(SEPIA, fade), wide, 12.0)
	# The ways on from it.
	if not told.veiled and told.ways > 0 and not told.boss:
		var foot := rect.end.y - 104.0
		draw_line(Vector2(left, foot - 22.0), Vector2(left + wide, foot - 22.0), Color(INK, 0.2), 1.0)
		var leads := point.next
		var onward := "その先　ボスへ" if (leads[0] as RouteMap.Waypoint).area.boss != null else "その先　%dつの道" % leads.size()
		text(Vector2(left, foot), onward, GOTHIC, 14, SEPIA)
		if (leads[0] as RouteMap.Waypoint).area.boss == null:
			for index in leads.size():
				_signs(Vector2(left + wide - 30.0 - (leads.size() - 1 - index) * 66.0, foot - 5.0), model.tell(leads[index]), 0.9, 0.8)
	# Going there, when the note tells of the course's first leg.
	var button := Rect2(left, rect.end.y - 78.0, wide, 50.0)
	if not plan.is_empty() and point == plan[0] and looked == null:
		var asked := arming()
		plate(button, Color(RED, 0.06 + 0.86 * asked), RED, 3.0, 2.0)
		text(Vector2(button.position.x, button.get_center().y + 8.0), "Enter でもう一度：出発する" if model.armed else "ここへ進む", MINCHO_B, 20, SLIP.lerp(RED, 1.0 - asked), HORIZONTAL_ALIGNMENT_CENTER, wide)
		draw_set_transform(Vector2.ZERO)
		zone(Rect2(NOTE.get_center() + button.position, button.size), [&"go"])
	elif plan.size() > 1 and looked == null:
		text(Vector2(left, button.get_center().y + 6.0), "下書きの道　%d手先" % (plan.size() - 1), MINCHO_M, 16, Color(RED, 0.85), HORIZONTAL_ALIGNMENT_CENTER, wide)
	draw_set_transform(Vector2.ZERO)


# What she carries: her health, level, echo and boons, on the margin.
func _carried() -> void:
	var left := CARRIED.position.x + 6.0
	var wide := CARRIED.size.x - 12.0
	var y := CARRIED.position.y + 24.0
	spaced(Vector2(left, y), "携行", GOTHIC_B, 13, SEPIA, 6.0)
	draw_line(Vector2(left + 54.0, y - 5.0), Vector2(left + wide, y - 5.0), Color(INK, 0.3), 1.0)
	y += 40.0
	text(Vector2(left, y), "HP", GOTHIC_B, 14, RED)
	text(Vector2(left + 34.0, y), "%d" % model.hp(), MINCHO_B, 28, INK)
	text(Vector2(left + 34.0 + width_of("%d" % model.hp(), MINCHO_B, 28) + 6.0, y), "/ %d" % model.max_hp(), MINCHO_M, 17, SEPIA)
	text(Vector2(left, y), "Lv %d" % model.run.progression.level, MINCHO_B, 20, INK, HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y += 12.0
	var bar := Rect2(left, y, wide, 9.0)
	draw_rect(bar, Color(INK, 0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * model.hp() / float(model.max_hp()), bar.size.y)), Color(RED, 0.9))
	draw_rect(bar, Color(INK, 0.7), false, 1.0)
	for index in range(1, 4):
		draw_line(Vector2(bar.position.x + bar.size.x * index / 4.0, bar.position.y), Vector2(bar.position.x + bar.size.x * index / 4.0, bar.end.y), Color(INK, 0.5), 1.0)
	y += 44.0
	sign_of(Vector2(left + 9.0, y - 7.0), 8.0, AreaData.Reward.ECHO, BLUE)
	text(Vector2(left + 28.0, y), "残響", GOTHIC, 14, SEPIA)
	text(Vector2(left + 66.0, y + 1.0), UIFormat.amount(model.run.echo), MINCHO_B, 22, INK)
	if not model.run.curses.is_empty():
		text(Vector2(left, y), "呪い：" + model.run.curse_names(), GOTHIC_B, 14, RED, HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y += 22.0
	var x := left
	for held: Array in boons():
		emblem(Vector2(x + 19.0, y + 19.0), 19.0, held[0])
		if held[2]:
			draw_circle(Vector2(x + 33.0, y + 33.0), 8.0, SLIP)
			text(Vector2(x + 25.0, y + 38.0), str(held[1]), GOTHIC_B, 12, INK, HORIZONTAL_ALIGNMENT_CENTER, 16.0)
		x += 46.0


# The key to the signs, and the keys.
func _foot() -> void:
	var y := 826.0
	var x := 72.0
	spaced(Vector2(x, y), "凡例", GOTHIC_B, 13, SEPIA, 4.0)
	x += 60.0
	draw_colored_polygon(PackedVector2Array([Vector2(x + 6.0, y - 12.0), Vector2(x + 12.0, y), Vector2(x, y)]), RED)
	x = _legend(x + 18.0, y, "脅威")
	for entry: Array in [[AreaData.Reward.BOON, "強化"], [AreaData.Reward.HEAL, "回復"], [AreaData.Reward.ECHO, "残響"], [-1, "イベント"]]:
		sign_of(Vector2(x + 7.0, y - 6.0), 7.0, entry[0], ink_of(entry[0]))
		x = _legend(x + 20.0, y, entry[1])
	draw_polyline(PackedVector2Array([Vector2(x, y - 5.0), Vector2(x + 34.0, y - 5.0)]), RED, 2.6)
	x = _legend(x + 42.0, y, "通った道")
	dashes(PackedVector2Array([Vector2(x, y - 5.0), Vector2(x + 34.0, y - 5.0)]), SEPIA, 1.5, 6.0, 6.0)
	x = _legend(x + 42.0, y, "この先の道")
	x = 72.0
	for pair: Array in [["↑ / ↓", "道を替える"], ["→ / ←", "先を読む"], ["Enter", "進む"], ["1〜3", "すぐ選ぶ"], ["Esc", "やめる" if model.armed else "メニュー"]]:
		text(Vector2(x, 854.0), pair[0], GOTHIC_B, 15, RED)
		x += width_of(pair[0], GOTHIC_B, 15) + 10.0
		text(Vector2(x, 854.0), pair[1], GOTHIC, 15, INK)
		x += width_of(pair[1], GOTHIC, 15) + 30.0


func _legend(x: float, y: float, words: String) -> float:
	text(Vector2(x, y), words, GOTHIC, 14, Color(INK, 0.8))
	return x + width_of(words, GOTHIC, 14) + 22.0


# Her figure: standing where she is, or walking the first leg once the pick
# is gone ahead with, the view diving into the sheet after her.
func _walk() -> void:
	if hero == null:
		return
	if not going:
		hero.position = _stand()
		return
	var share := clampf(since(&"go") / go_time(), 0.0, 1.0)
	var path := way(model.here(), plan[0])
	var next := along(path, smoothstep(0.0, 0.8, share)) + Vector2(-4.0, 8.0)
	var heading := next - hero.position
	if heading.length() > 0.05:
		hero.facing = Vector2i(1 if heading.x >= 0.0 else -1, 1 if heading.y > absf(heading.x) * 0.5 else (-1 if heading.y < -absf(heading.x) * 0.5 else 0))
		hero.step(heading)
	hero.position = next
	pivot_offset = spot(plan[0]) + Vector2(0.0, -30.0)
	scale = Vector2.ONE * (1.0 + 0.7 * smoothstep(0.35, 1.0, share))


# --- A sketch of a picture ---

# A foe's picture as a drawing in brown ink: dark where it is dark, and the
# paper showing through where it is light.
static func sketch(art: Texture2D) -> Texture2D:
	if _sketches.has(art):
		return _sketches[art]
	var image := art.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if colour.a <= 0.0:
				continue
			var light := colour.get_luminance()
			var drawn := Color(0.24, 0.17, 0.11).lerp(Color(0.62, 0.5, 0.36), smoothstep(0.1, 0.75, light))
			image.set_pixel(x, y, Color(drawn, colour.a * (1.0 - 0.55 * smoothstep(0.35, 0.95, light))))
	var texture := ImageTexture.create_from_image(image)
	_sketches[art] = texture
	return texture
