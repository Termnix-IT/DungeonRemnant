class_name RouteTablet
extends Node2D

# The chapter's whole route, cut into a stone tablet that hangs over the
# hall of gates (RouteGates), to be read at a glance: where she has been,
# where she is, what she may choose now, and how far the boss still is.
#
# What an area is to her is told by its socket's size and shape, not by its
# colour alone. Where she is: the largest round, gold, a star in it and a
# compass turning round it. The areas she has taken: small gold stones, the
# grooves between them filled with gold (the widest on the tablet). The ways
# open now: large jewels in their gates' colours, each with its gate's
# number, the one turned to grown larger and ringed, its light running to it
# along the groove. The areas further on: smaller sockets with the sign of
# what they give, glowing faintly where the gate turned to still leads and
# dark where it does not. The areas out of reach: small empty sockets, their
# grooves only scratched. The boss: a lozenge at the end, dim until her way
# reaches it. Along the tablet's foot a small stone for every stage counts
# the way to the boss.
#
# A way runs straight out of its area, slants, and runs straight into the
# next, so ways that part or meet do so at an area's side and are not
# mistaken for ways that merely cross.
#
# The page tells it nothing but when the route is shown anew and when the
# gate turned to changes; what each area is to her now it asks the page
# (mark, reach, veiled, light_of). It lies in the page's design space, its
# own place the space's corner.

const CARVING := preload("res://ui/route_map/route_tablet.gdshader")
const SLAB := "res://art/ui/route/route_tablet.png"
# The tablet on the page: its size, how far down from the top its upper
# edge hangs, and how far in from its ends the start and the boss lie.
const SIZE := Vector2(820.0, 105.0)
const TOP := 4.0
const INSET := 58.0
# The gap between a layer's areas, the room a layer may take in all, how far
# above the tablet's middle the route's own middle lies (the stages run
# along the foot), and how far a way runs straight out of an area.
const ROW := 28.0
const ROOM := 62.0
const LIFT := 3.0
const STUB := 22.0
# The sockets: an area further on, a way open now, the one turned to, where
# she is, an area taken, the boss's, the start's and one out of reach.
const SOCKET := 8.5
const OPEN := 10.5
const CHOSEN := 12.5
const HERE := 10.5
const TAKEN := 6.0
const BOSS_SOCKET := 14.0
const START := 5.0
const EMPTY := 4.0
# The stages' line, up from the tablet's foot.
const STAGE_LINE := 8.5
# How long the light takes to run to the area turned to, the tablet to come
# down as the page opens, and the way just walked to cool to gold.
const RUN_TIME := 0.26
const DROP_TIME := 0.5
const COOL_TIME := 1.1
const WAYS := 96
const AREAS := 20
const STAGES := 8

var page: RouteGates
var slab: Sprite2D
# Each area's place on the page (null: the start), light and reward.
var _spots: Dictionary = {}
var _tones: Dictionary = {}
var _rewards: Dictionary = {}
# The light each area's jewel holds now and its socket's size (eased), by area.
var _held: Dictionary = {}
var _sized: Dictionary = {}
var _clock := 0.0
var _opened := 0.0
var _turned := -100.0
# The spark a gate sends up to its socket as it is turned to.
var _spark: CPUParticles2D
var _flight: Tween


func _init(owner_page: RouteGates) -> void:
	page = owner_page
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	slab = Sprite2D.new()
	slab.centered = false
	slab.show_behind_parent = true
	if ResourceLoader.exists(SLAB):
		slab.texture = load(SLAB)
		slab.scale = SIZE / slab.texture.get_size()
	var carved := ShaderMaterial.new()
	carved.shader = CARVING
	carved.set_shader_parameter(&"size", SIZE)
	carved.set_shader_parameter(&"stage_y", SIZE.y - STAGE_LINE)
	slab.material = carved
	add_child(slab)
	_spark = CPUParticles2D.new()
	_spark.texture = RouteGateView.spark()
	var adding := CanvasItemMaterial.new()
	adding.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spark.material = adding
	_spark.emitting = false
	_spark.amount = 26
	_spark.lifetime = 0.42
	_spark.local_coords = false
	_spark.direction = Vector2.ZERO
	_spark.spread = 180.0
	_spark.gravity = Vector2.ZERO
	_spark.initial_velocity_min = 0.0
	_spark.initial_velocity_max = 9.0
	_spark.scale_amount_min = 0.05
	_spark.scale_amount_max = 0.13
	var life := Gradient.new()
	life.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	life.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_spark.color_ramp = life
	add_child(_spark)


# Where the tablet lies on the page.
func rect() -> Rect2:
	return Rect2((RouteGates.DESIGN.x - SIZE.x) * 0.5, TOP, SIZE.x, SIZE.y)


# Where an area lies on the tablet, on the page (null: the start).
func spot(point: RouteMap.Waypoint) -> Vector2:
	return _spots.get(point, rect().get_center())


# The way from one area to another on the tablet, as the groove runs: out of
# the one, aslant, into the other.
func way(from: RouteMap.Waypoint, to: RouteMap.Waypoint) -> PackedVector2Array:
	var a := spot(from)
	var b := spot(to)
	return PackedVector2Array([a, a + Vector2(STUB, 0.0), b - Vector2(STUB, 0.0), b])


# A place a share of the way along a groove.
func along(from: RouteMap.Waypoint, to: RouteMap.Waypoint, share: float) -> Vector2:
	var points := way(from, to)
	var lengths: Array[float] = []
	var whole := 0.0
	for index in points.size() - 1:
		lengths.append(points[index].distance_to(points[index + 1]))
		whole += lengths[index]
	var left := clampf(share, 0.0, 1.0) * whole
	for index in lengths.size():
		if left <= lengths[index] or index == lengths.size() - 1:
			return points[index].lerp(points[index + 1], left / maxf(lengths[index], 0.001))
		left -= lengths[index]
	return points[points.size() - 1]


# The route is shown anew: its areas are given their places.
func present() -> void:
	_spots.clear()
	_tones.clear()
	_rewards.clear()
	_held.clear()
	_sized.clear()
	var route := page.route
	var face := rect()
	var from := face.position.x + INSET
	var gap := (face.size.x - INSET * 2.0) / route.size()
	var middle := face.get_center().y - LIFT
	_spots[null] = Vector2(from, middle)
	for layer in route.size():
		var points := route.nodes(layer)
		var row := minf(ROW, ROOM / maxf(1.0, points.size() - 1.0))
		for index in points.size():
			var point: RouteMap.Waypoint = points[index]
			_spots[point] = Vector2(from + gap * (layer + 1), middle + (index - (points.size() - 1) * 0.5) * row)
			var told := page.tell(point)
			_tones[point] = page.light_of(told)
			_rewards[point] = told.reward
	_opened = _clock
	_turned = _clock
	_spark.emitting = false
	step(0.0)


# The gate turned to has changed: its light runs to its socket anew.
func turn() -> void:
	_turned = _clock


# A spark flies from a gate's keystone (`from`, on the page) to the socket
# of its area.
func send_spark(from: Vector2, point: RouteMap.Waypoint, colour: Color) -> void:
	if not _spots.has(point):
		return
	if _flight != null:
		_flight.kill()
	var to := spot(point)
	var over := (from + to) * 0.5 + Vector2((to.x - from.x) * 0.1, -34.0)
	_spark.color = colour.lerp(Color.WHITE, 0.45)
	_spark.position = from
	_spark.restart()
	_spark.emitting = true
	_flight = create_tween()
	_flight.tween_method(func(share: float) -> void:
		_spark.position = from.lerp(over, share).lerp(over.lerp(to, share), share), 0.0, 1.0, RUN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flight.tween_callback(func() -> void: _spark.emitting = false)


# One frame: how the tablet hangs, and what stands in its grooves.
func step(delta: float) -> void:
	_clock += delta
	if page.route == null:
		return
	var come := _come()
	position = Vector2(0.0, -(1.0 - come) * 30.0) + page.toll_shake() * 0.6
	modulate.a = come * (1.0 - page.leaving())
	slab.position = rect().position
	_carve(delta)
	queue_redraw()


# How far the tablet has come down as the page opened.
func _come() -> float:
	var share := clampf((_clock - _opened) / DROP_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


# How far the light has run to the area turned to.
func _run() -> float:
	var share := clampf((_clock - _turned) / RUN_TIME, 0.0, 1.0)
	return share * share * (3.0 - 2.0 * share)


# What a way between two areas holds now: its light, how far along it the
# light has come, the beads running on it, half its width and its depth.
func _way_state(from: RouteMap.Waypoint, to: RouteMap.Waypoint, shared: Dictionary) -> Dictionary:
	var pale: Color = shared.pale
	var gold: Color = shared.gold
	var walked: Array = shared.walked
	var at := walked.find(to)
	if at >= 0 and (from == null and at == 0 or at > 0 and walked[at - 1] == from):
		# The way walked: gold, the last of it still cooling from white.
		var fresh := 1.0 - clampf((_clock - _opened) / COOL_TIME, 0.0, 1.0) if at == walked.size() - 1 else 0.0
		return {tone = Color(gold.lerp(Color.WHITE, 0.6 * fresh), 0.9 + 0.6 * fresh), fill = 1.0, beads = 0.0, wide = 2.7, deep = 1.0}
	if from == page.here() and page.open.has(to):
		if to == shared.chosen:
			# As she goes, the way turns to gold behind her.
			return {tone = Color((shared.colour as Color).lerp(gold, shared.going), 1.05 + 0.45 * shared.asking), fill = maxf(_run(), shared.going), beads = 1.0 - shared.going, wide = 2.4, deep = 1.0}
		return {tone = Color(pale, 0.34 * (1.0 - 0.85 * shared.asking)), fill = 1.0, beads = 0.0, wide = 1.7, deep = 1.0}
	if from != null and page.reach.has(from) and from.layer >= page.route_layer:
		if (shared.kept as Dictionary).has(from):
			return {tone = Color(shared.colour, 0.4 * _run()), fill = 1.0, beads = 0.7 if from == shared.chosen else 0.0, wide = 1.6, deep = 1.0}
		return {tone = Color(pale, 0.08), fill = 1.0, beads = 0.0, wide = 1.5, deep = 0.8}
	return {tone = Color(pale, 0.0), fill = 1.0, beads = 0.0, wide = 1.2, deep = 0.3}


# Tells the carving what every way and every area holds now.
func _carve(delta := 0.0) -> void:
	var route := page.route
	var corner := rect().position
	var chosen := page.selected()
	var pale := page.theme_colour(&"pale")
	var gold := page.theme_colour(&"boon")
	var walked := page.run.taken.slice(0, page.route_layer)
	var shared := {
		chosen = chosen, kept = page.reach_from([chosen]) if chosen != null else {}, colour = _tones.get(chosen, pale),
		pale = pale, gold = gold, walked = walked, asking = page.asking(), going = page.going(),
	}
	var ways := PackedVector4Array()
	var way_tones := PackedColorArray()
	var way_runs := PackedVector4Array()
	var pairs: Array = []
	for point: RouteMap.Waypoint in route.nodes(0):
		pairs.append([null, point])
	for layer in route.size() - 1:
		for from: RouteMap.Waypoint in route.nodes(layer):
			for to: RouteMap.Waypoint in from.next:
				pairs.append([from, to])
	# The straight runs out of an area and into one are shared by every way
	# through it: each takes the brightest of them.
	var outs := {}
	var ins := {}
	var slants: Array = []
	for pair: Array in pairs:
		var state := _way_state(pair[0], pair[1], shared)
		var light := (state.tone as Color).a * 10.0 + float(state.wide) + float(state.deep)
		if not outs.has(pair[0]) or light > outs[pair[0]][1]:
			outs[pair[0]] = [state, light]
		if not ins.has(pair[1]) or light > ins[pair[1]][1]:
			ins[pair[1]] = [state, light]
		slants.append([pair[0], pair[1], state])
	var stretches: Array = []
	for from: Variant in outs:
		var a := spot(from)
		stretches.append([a, a + Vector2(STUB, 0.0), outs[from][0], 0.0, 0.2])
	for entry: Array in slants:
		stretches.append([spot(entry[0]) + Vector2(STUB, 0.0), spot(entry[1]) - Vector2(STUB, 0.0), entry[2], 0.2, 0.8])
	for to: Variant in ins:
		var b := spot(to)
		stretches.append([b - Vector2(STUB, 0.0), b, ins[to][0], 0.8, 1.0])
	for stretch: Array in stretches:
		if ways.size() >= WAYS:
			break
		var a: Vector2 = stretch[0] - corner
		var b: Vector2 = stretch[1] - corner
		var state: Dictionary = stretch[2]
		# The light comes along the whole way; this stretch is a part of it.
		var filled := clampf((float(state.fill) - float(stretch[3])) / (float(stretch[4]) - float(stretch[3])), 0.0, 1.0) if float(state.fill) < 1.0 else 1.0
		ways.append(Vector4(a.x, a.y, b.x, b.y))
		way_tones.append(state.tone if filled > 0.0 else Color(state.tone, 0.0))
		way_runs.append(Vector4(filled, state.beads, state.wide, state.deep))
	var areas := PackedVector4Array()
	var area_tones := PackedColorArray()
	var area_rings := PackedVector2Array()
	var start := spot(null) - corner
	var at_start := page.here() == null
	areas.append(Vector4(start.x, start.y, HERE - 2.0 if at_start else START, 2.0 if at_start else 0.0))
	area_tones.append(Color(gold, 1.1 if at_start else 0.85))
	area_rings.append(Vector2(0.0, 0.7 if at_start else 0.0))
	for layer in route.size():
		for point: RouteMap.Waypoint in route.nodes(layer):
			if areas.size() >= AREAS:
				break
			var at := spot(point) - corner
			var state := page.mark(point)
			var radius := EMPTY
			var want := 0.0
			var shape := 0.0
			var tone: Color = _tones.get(point, pale)
			var ring := Vector2.ZERO
			if point.area.boss != null:
				radius = BOSS_SOCKET
				shape = 1.0
				var dark := page.veiled(point)
				want = 0.2 + 0.1 * sin(_clock * TAU / RouteGates.BOSS_BEAT) if dark else 1.1
				ring = Vector2(0.0 if dark or point != chosen else 1.0, 0.18 if dark else 0.7)
			else:
				match state:
					RouteGates.Mark.TAKEN:
						tone = gold
						if point == page.here():
							radius = HERE
							shape = 2.0
							want = 1.2
							ring.y = 0.85
						else:
							radius = TAKEN
							want = 0.95
					RouteGates.Mark.OPEN:
						if point == chosen:
							radius = CHOSEN
							want = 1.2 + 0.3 * float(shared.asking)
							ring = Vector2(1.0, 0.95)
						else:
							# Its jewel goes out as its gate's grille comes down.
							radius = OPEN
							want = lerpf(0.7, 0.06, page.grille_of(point))
							ring.y = 0.3 * (1.0 - page.grille_of(point))
					RouteGates.Mark.AHEAD:
						radius = SOCKET
						want = 0.22 if (shared.kept as Dictionary).has(point) else 0.05
			var held: float = _held.get(point, 0.0)
			var light := want if delta <= 0.0 else move_toward(held, want, delta * (3.0 + absf(want - held) * 9.0))
			_held[point] = light
			var size: float = radius if delta <= 0.0 else move_toward(float(_sized.get(point, radius)), radius, delta * 26.0)
			_sized[point] = size
			areas.append(Vector4(at.x, at.y, size, shape))
			area_tones.append(Color(tone, light))
			area_rings.append(ring)
	# The stages along the foot: those behind her gold, the one she chooses
	# now alight in the colour of the gate turned to, the rest dark, the
	# boss's red.
	var stage_xs := PackedFloat32Array()
	var stage_tones := PackedColorArray()
	for layer in mini(route.size(), STAGES):
		var points := route.nodes(layer)
		stage_xs.append(spot(points[0]).x - corner.x)
		if layer < page.route_layer:
			stage_tones.append(Color(gold, 0.9))
		elif layer == page.route_layer:
			stage_tones.append(Color(shared.colour, 0.75 + 0.2 * sin(_clock * 2.6)))
		elif (points[0] as RouteMap.Waypoint).area.boss != null:
			stage_tones.append(Color(page.theme_colour(&"boss"), 0.5))
		else:
			stage_tones.append(Color(pale, 0.1))
	var carved := slab.material as ShaderMaterial
	carved.set_shader_parameter(&"way_count", ways.size())
	carved.set_shader_parameter(&"area_count", areas.size())
	carved.set_shader_parameter(&"stage_count", stage_xs.size())
	ways.resize(WAYS)
	way_tones.resize(WAYS)
	way_runs.resize(WAYS)
	areas.resize(AREAS)
	area_tones.resize(AREAS)
	area_rings.resize(AREAS)
	stage_xs.resize(STAGES)
	stage_tones.resize(STAGES)
	carved.set_shader_parameter(&"way", ways)
	carved.set_shader_parameter(&"way_tone", way_tones)
	carved.set_shader_parameter(&"way_run", way_runs)
	carved.set_shader_parameter(&"area", areas)
	carved.set_shader_parameter(&"area_tone", area_tones)
	carved.set_shader_parameter(&"area_ring", area_rings)
	carved.set_shader_parameter(&"stage_x", stage_xs)
	carved.set_shader_parameter(&"stage_tone", stage_tones)
	carved.set_shader_parameter(&"clock", _clock)


# Over the carving: each open way's number and each further area's sign in
# its socket, the star where she is (walking the groove as she goes), and
# the mark round an area being read.
func _draw() -> void:
	if page == null or page.route == null:
		return
	var route := page.route
	var chosen := page.selected()
	var kept := page.reach_from([chosen]) if chosen != null else {}
	var night := page.theme_colour(&"night")
	var pale := page.theme_colour(&"pale")
	var gold := page.theme_colour(&"boon")
	var face := page.get_theme_font(&"bold_font")
	var size := page.get_theme_font_size(&"label_size")
	for layer in route.size():
		for point: RouteMap.Waypoint in route.nodes(layer):
			if point.area.boss != null:
				continue
			var at := spot(point)
			match page.mark(point):
				RouteGates.Mark.OPEN:
					# Its gate's number, as on the gate's keystone.
					var number := str(page.open.find(point) + 1)
					var lit := clampf(float(_held.get(point, 0.0)) * 1.8, 0.25, 1.0)
					var from := at + Vector2(-12.0, size * 0.36)
					draw_string_outline(face, from, number, HORIZONTAL_ALIGNMENT_CENTER, 24.0, size, 4, Color(night, 0.9 * lit))
					draw_string(face, from, number, HORIZONTAL_ALIGNMENT_CENTER, 24.0, size, Color(pale.lerp(Color.WHITE, 0.4), lit))
				RouteGates.Mark.AHEAD:
					RouteSigns.reward(self, at, 4.8, _rewards.get(point, -1), Color(_tones.get(point, pale), 0.95 if kept.has(point) else 0.34))
	# Where she is: a star in the socket, walking the groove as she goes.
	var here := spot(page.here())
	if chosen != null and page.going() > 0.0:
		here = along(page.here(), chosen, page.going())
	HubUI.star(self, here, 7.5, Color(night, 0.85))
	HubUI.star(self, here, 6.0, gold.lerp(Color.WHITE, 0.75))
	var reading := page.read()
	if reading != null and _spots.has(reading):
		var at := spot(reading)
		var radius := float(_sized.get(reading, SOCKET)) + 8.0
		draw_arc(at, radius, 0.0, TAU, 28, pale, 1.5, true)
		for tick in 4:
			var out := Vector2.from_angle(TAU * tick / 4.0 + _clock * 0.5)
			draw_line(at + out * radius, at + out * (radius + 5.0), pale, 1.5, true)
