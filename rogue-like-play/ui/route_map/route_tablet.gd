class_name RouteTablet
extends Node2D

# The chapter's whole route, cut into a stone tablet that hangs over the
# hall of gates (RouteGates). Every area is a socket ringed with bronze and
# every way between two a groove in the slate, and they are lit the way the
# gates are: the way walked stands filled with gold, the socket she is at
# under a small star; each way open now is a jewel in the colour of its
# gate; the gate turned to sends its light along the groove to its socket,
# which wears a ring, and faintly on down every way that pick keeps open,
# while the areas it would put out of reach go dark; the boss is a lozenge
# at the end, dim until her way reaches it. Asked, the jewels of the gates
# not chosen go out as their grilles land; going, the star walks the groove
# with her.
#
# The page tells it nothing but when the route is shown anew and when the
# gate turned to changes; what each area is to her now it asks the page
# (mark, reach, veiled, light_of). It lies in the page's design space, its
# own place the space's corner.

const CARVING := preload("res://ui/route_map/route_tablet.gdshader")
const SLAB := "res://art/ui/route/route_tablet.png"
# The tablet on the page: its size, how far down from the top its upper
# edge hangs, and how far in from its ends the start and the boss lie.
const SIZE := Vector2(736.0, 94.0)
const TOP := 4.0
const INSET := 50.0
# The gap between a layer's areas, and the room a layer may take in all.
const ROW := 25.0
const ROOM := 62.0
# The sockets: an area's, the boss's, the start's and one passed by.
const SOCKET := 8.5
const BOSS_SOCKET := 12.5
const START := 4.5
const EMPTY := 4.5
# How long the light takes to run to the area turned to, the tablet to come
# down as the page opens, and the way just walked to cool to gold.
const RUN_TIME := 0.26
const DROP_TIME := 0.5
const COOL_TIME := 1.1
const WAYS := 40
const AREAS := 20

var page: RouteGates
var slab: Sprite2D
# Each area's place on the page (null: the start), light and reward.
var _spots: Dictionary = {}
var _tones: Dictionary = {}
var _rewards: Dictionary = {}
# The light each area's jewel holds now (eased), by area.
var _held: Dictionary = {}
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


# The route is shown anew: its areas are given their places.
func present() -> void:
	_spots.clear()
	_tones.clear()
	_rewards.clear()
	_held.clear()
	var route := page.route
	var face := rect()
	var from := face.position.x + INSET
	var gap := (face.size.x - INSET * 2.0) / route.size()
	var middle := face.get_center().y
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
	modulate.a = come
	slab.position = rect().position
	_carve()
	queue_redraw()


# How far the tablet has come down as the page opened.
func _come() -> float:
	var share := clampf((_clock - _opened) / DROP_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


# How far the light has run to the area turned to.
func _run() -> float:
	var share := clampf((_clock - _turned) / RUN_TIME, 0.0, 1.0)
	return share * share * (3.0 - 2.0 * share)


# Tells the carving what every way and every area holds now.
func _carve() -> void:
	var route := page.route
	var corner := rect().position
	var chosen := page.selected()
	var kept := page.reach_from([chosen]) if chosen != null else {}
	var colour: Color = _tones.get(chosen, page.theme_colour(&"pale"))
	var pale := page.theme_colour(&"pale")
	var gold := page.theme_colour(&"boon")
	var walked := page.run.taken.slice(0, page.route_layer)
	var asking := page.asking()
	var going := page.going()
	var ways := PackedVector4Array()
	var way_tones := PackedColorArray()
	var way_runs := PackedVector2Array()
	var pairs: Array = []
	for point: RouteMap.Waypoint in route.nodes(0):
		pairs.append([null, point])
	for layer in route.size() - 1:
		for from: RouteMap.Waypoint in route.nodes(layer):
			for to: RouteMap.Waypoint in from.next:
				pairs.append([from, to])
	for pair: Array in pairs:
		if ways.size() >= WAYS:
			break
		var from: RouteMap.Waypoint = pair[0]
		var to: RouteMap.Waypoint = pair[1]
		var a := spot(from) - corner
		var b := spot(to) - corner
		var tone := Color(pale, 0.0)
		var run := Vector2(1.0, 0.0)
		var at := walked.find(to)
		if at >= 0 and (from == null and at == 0 or at > 0 and walked[at - 1] == from):
			# The way walked: gold, the last of it still cooling from white.
			var fresh := 1.0 - clampf((_clock - _opened) / COOL_TIME, 0.0, 1.0) if at == walked.size() - 1 else 0.0
			tone = Color(gold.lerp(Color.WHITE, 0.6 * fresh), 0.85 + 0.6 * fresh)
		elif from == page.here() and page.open.has(to):
			if to == chosen:
				# As she goes, the way turns to gold behind her.
				tone = Color(colour.lerp(gold, going), 1.0 + 0.45 * asking)
				run = Vector2(maxf(_run(), going), 1.0 - going)
			else:
				tone = Color(pale, 0.3 * (1.0 - 0.8 * asking))
		elif from != null and page.reach.has(from) and from.layer >= page.route_layer:
			if kept.has(from):
				tone = Color(colour, 0.36 * _run())
				run = Vector2(1.0, 0.7 if from == chosen else 0.0)
			else:
				tone = Color(pale, 0.07)
		ways.append(Vector4(a.x, a.y, b.x, b.y))
		way_tones.append(tone)
		way_runs.append(run)
	var areas := PackedVector4Array()
	var area_tones := PackedColorArray()
	var area_rings := PackedVector2Array()
	var start := spot(null) - corner
	areas.append(Vector4(start.x, start.y, START, 0.0))
	area_tones.append(Color(gold if not walked.is_empty() else pale, 0.8 if not walked.is_empty() else 0.45))
	area_rings.append(Vector2(0.0, 0.3 if walked.is_empty() else 0.0))
	for layer in route.size():
		for point: RouteMap.Waypoint in route.nodes(layer):
			if areas.size() >= AREAS:
				break
			var at := spot(point) - corner
			var state := page.mark(point)
			var radius := SOCKET
			var want := 0.0
			var tone: Color = _tones.get(point, pale)
			var ring := Vector2.ZERO
			if point.area.boss != null:
				radius = BOSS_SOCKET
				var dark := page.veiled(point)
				want = 0.2 + 0.1 * sin(_clock * TAU / RouteGates.BOSS_BEAT) if dark else 1.1
				ring = Vector2(0.0 if dark or point != chosen else 1.0, 0.18 if dark else 0.7)
			else:
				match state:
					RouteGates.Mark.TAKEN:
						tone = gold
						want = 1.15 if point == page.here() else 0.85
						ring.y = 0.75 if point == page.here() else 0.0
					RouteGates.Mark.OPEN:
						if point == chosen:
							want = 1.2 + 0.3 * asking
							ring = Vector2(1.0, 0.95)
						else:
							# Its jewel goes out as its gate's grille comes down.
							want = lerpf(0.6, 0.06, page.grille_of(point))
							ring.y = 0.25 * (1.0 - page.grille_of(point))
					RouteGates.Mark.AHEAD:
						radius = SOCKET - 1.0
						want = 0.2 if kept.has(point) else 0.045
					_:
						radius = EMPTY
			var light: float = move_toward(_held.get(point, 0.0), want, 0.12 + absf(want - float(_held.get(point, 0.0))) * 0.22)
			_held[point] = light
			areas.append(Vector4(at.x, at.y, radius, 1.0 if point.area.boss != null else 0.0))
			area_tones.append(Color(tone, light))
			area_rings.append(ring)
	var carved := slab.material as ShaderMaterial
	carved.set_shader_parameter(&"way_count", ways.size())
	carved.set_shader_parameter(&"area_count", areas.size())
	ways.resize(WAYS)
	way_tones.resize(WAYS)
	way_runs.resize(WAYS)
	areas.resize(AREAS)
	area_tones.resize(AREAS)
	area_rings.resize(AREAS)
	carved.set_shader_parameter(&"way", ways)
	carved.set_shader_parameter(&"way_tone", way_tones)
	carved.set_shader_parameter(&"way_run", way_runs)
	carved.set_shader_parameter(&"area", areas)
	carved.set_shader_parameter(&"area_tone", area_tones)
	carved.set_shader_parameter(&"area_ring", area_rings)
	carved.set_shader_parameter(&"clock", _clock)


# Over the carving: each area's sign in its socket, the star over where she
# is, and the mark round an area being read.
func _draw() -> void:
	if page == null or page.route == null:
		return
	var route := page.route
	var chosen := page.selected()
	var kept := page.reach_from([chosen]) if chosen != null else {}
	var night := page.theme_colour(&"night")
	var pale := page.theme_colour(&"pale")
	var gold := page.theme_colour(&"boon")
	for layer in route.size():
		for point: RouteMap.Waypoint in route.nodes(layer):
			if point.area.boss != null:
				continue
			var at := spot(point)
			match page.mark(point):
				RouteGates.Mark.OPEN:
					# Dark on its lit jewel.
					RouteSigns.reward(self, at, 4.6, _rewards.get(point, -1), Color(night, 0.78 * clampf(float(_held.get(point, 0.0)) * 1.6, 0.0, 1.0)))
				RouteGates.Mark.AHEAD:
					RouteSigns.reward(self, at, 4.6, _rewards.get(point, -1), Color(_tones.get(point, pale), 0.95 if kept.has(point) else 0.3))
	# Where she is: a small star over the socket, walking the groove as she goes.
	var here := spot(page.here())
	if chosen != null:
		here = here.lerp(spot(chosen), page.going())
	var bob := sin(_clock * 2.4) * 1.5
	HubUI.mark(self, here + Vector2(0.0, -SOCKET - 9.0 + bob), 5.0, gold.lerp(Color.WHITE, 0.35))
	var reading := page.read()
	if reading != null and _spots.has(reading):
		var at := spot(reading)
		var radius := (BOSS_SOCKET if reading.area.boss != null else SOCKET) + 7.0
		draw_arc(at, radius, 0.0, TAU, 28, pale, 1.5, true)
		for tick in 4:
			var way := Vector2.from_angle(TAU * tick / 4.0 + _clock * 0.5)
			draw_line(at + way * radius, at + way * (radius + 5.0), pale, 1.5, true)
