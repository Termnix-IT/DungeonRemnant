class_name GemField
extends Node2D

# The experience gems on a battlefield, all in packed arrays and drawn in one
# go: a fallen foe drops one, a gem within the hero's pull flies to her
# faster and faster, and one that reaches her is collected. A gem dropped
# springs out of the fallen foe: it slides a little way off and hops in a
# low arc before it settles, as loot sprays in action games. Past MAX_GEMS a
# new gem is added into the nearest one instead, so a long fight never piles
# up nodes or draw calls.
#
# A gem is a painted shard of the echo (echo_shards.png: a sliver, a pair, a
# cluster, by what it is worth) lying in its own light on the dark floor:
# it bobs and glints while it waits, stretches into a streak of light as it
# flies to her, and goes out in a small burst where she takes it. All of
# that is only how it is drawn; where a gem is and when it is taken is
# step() alone.

signal collected(amount: int)

const MAX_GEMS := 300
const PULL_RADIUS := 110.0
const COLLECT_RADIUS := 18.0
const PULL_ACCELERATION := 2600.0
const SMALL := Color("7fe6ff")
const MIDDLE := Color("8dff9a")
const LARGE := Color("ffd25e")
const SHARDS: Texture2D = preload("res://art/effects/painted/echo_shards.png")
const SHARD_FRAMES := 3
# How tall each kind is drawn (world px), how wide its light lies round it,
# and how much that light and the shard itself rise and fall as it waits.
const HEIGHTS: Array[float] = [17.0, 22.0, 28.0]
const GLOW := 2.6
const GLOW_ALPHA := 0.42
const BOB := 1.6
const GLINT := 0.3
# Flying to her it stretches into a streak this long at most (world px).
const STREAK := 26.0
# Where she takes one, a burst of its light: how many are shown at once,
# how long each lasts and how wide it opens.
const POPS := 16
const POP_TIME := 0.2
const POP_SIZE := 34.0
# The spray: how fast a dropped gem slides off (slowing by SPRAY_DRAG per
# second), and its hop's height and time.
const SPRAY_SPEED := Vector2(70.0, 150.0)
const SPRAY_DRAG := 7.0
const HOP_HEIGHT := 18.0
const HOP_TIME := 0.32

var positions := PackedVector2Array()
var values := PackedInt32Array()
var speeds := PackedFloat32Array()
# Each gem's slide, and the time left of its hop.
var drifts := PackedVector2Array()
var hops := PackedFloat32Array()
# How far the hero's pull reaches; boons may widen it.
var pull_radius := PULL_RADIUS
var _lights: Node2D
var _glow: GradientTexture2D
var _clock := 0.0
# Bursts still fading where gems were taken: [where, colour, seconds left].
var _pops: Array = []
# Where she was at the last step (the streaks point to her).
var _toward := Vector2.ZERO


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var fall := Gradient.new()
	fall.set_color(0, Color.WHITE)
	fall.set_color(1, Color(1, 1, 1, 0))
	fall.add_point(0.35, Color(1, 1, 1, 0.45))
	_glow = GradientTexture2D.new()
	_glow.gradient = fall
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 64
	_glow.height = 64
	# The gems' light: under them, added to the floor.
	_lights = Node2D.new()
	_lights.name = "Lights"
	_lights.show_behind_parent = true
	var added := CanvasItemMaterial.new()
	added.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = added
	_lights.draw.connect(_draw_lights)
	add_child(_lights)


func _process(delta: float) -> void:
	if positions.is_empty() and _pops.is_empty():
		return
	_clock += delta
	for index in range(_pops.size() - 1, -1, -1):
		_pops[index][2] -= delta
		if _pops[index][2] <= 0.0:
			_pops.remove_at(index)
	queue_redraw()
	_lights.queue_redraw()


func count() -> int:
	return positions.size()


func total() -> int:
	var sum := 0
	for value in values:
		sum += value
	return sum


func drop(at: Vector2, value: int) -> void:
	if value <= 0:
		return
	if positions.size() >= MAX_GEMS:
		var nearest := 0
		for index in positions.size():
			if positions[index].distance_squared_to(at) < positions[nearest].distance_squared_to(at):
				nearest = index
		values[nearest] += value
	else:
		positions.append(at)
		values.append(value)
		speeds.append(0.0)
		drifts.append(Vector2.from_angle(randf() * TAU) * randf_range(SPRAY_SPEED.x, SPRAY_SPEED.y))
		hops.append(HOP_TIME)
	queue_redraw()


# One physics frame: gems in her pull fly to her; those that reach her are
# collected. Tests call it directly.
func step(hero_at: Vector2, delta: float) -> void:
	if positions.is_empty():
		return
	var gained := 0
	_toward = hero_at
	var settle := exp(-SPRAY_DRAG * delta)
	for index in range(positions.size() - 1, -1, -1):
		if hops[index] > 0.0 or drifts[index] != Vector2.ZERO:
			positions[index] += drifts[index] * delta
			drifts[index] = drifts[index] * settle if drifts[index].length() > 4.0 else Vector2.ZERO
			hops[index] = maxf(0.0, hops[index] - delta)
		var offset := hero_at - positions[index]
		var distance := offset.length()
		if speeds[index] <= 0.0 and distance > pull_radius:
			continue
		speeds[index] += PULL_ACCELERATION * delta
		var move := speeds[index] * delta
		if distance <= COLLECT_RADIUS or move >= distance:
			gained += values[index]
			if _pops.size() < POPS:
				_pops.append([hero_at, _colour(values[index]), POP_TIME])
			positions.remove_at(index)
			values.remove_at(index)
			speeds.remove_at(index)
			drifts.remove_at(index)
			hops.remove_at(index)
			continue
		positions[index] += offset / distance * move
	queue_redraw()
	if gained > 0:
		collected.emit(gained)


func clear() -> void:
	positions.clear()
	values.clear()
	speeds.clear()
	drifts.clear()
	hops.clear()
	queue_redraw()


# 0 a sliver, 1 a pair, 2 a cluster: by what the gem is worth.
static func kind_of(value: int) -> int:
	return 2 if value >= 10 else (1 if value >= 4 else 0)


func _colour(value: int) -> Color:
	return [SMALL, MIDDLE, LARGE][kind_of(value)]


# Where a gem is drawn: lifted while it hops, bobbing while it waits.
func _shown_at(index: int) -> Vector2:
	var at := positions[index] - Vector2(0, HOP_HEIGHT * sin(PI * hops[index] / HOP_TIME))
	if speeds[index] <= 0.0 and hops[index] <= 0.0:
		at.y += sin(_clock * 3.0 + positions[index].x * 0.07) * BOB
	return at


# The shards themselves.
func _draw() -> void:
	var frame := Vector2(SHARDS.get_width() / float(SHARD_FRAMES), SHARDS.get_height())
	for index in positions.size():
		var kind := kind_of(values[index])
		var tall := HEIGHTS[kind]
		var extent := Vector2(tall * frame.x / frame.y, tall)
		var at := _shown_at(index)
		draw_texture_rect_region(SHARDS, Rect2(at - Vector2(extent.x * 0.5, extent.y * 0.72), extent), Rect2(kind * frame.x, 0.0, frame.x, frame.y))


# Their light on the floor, the streak of one flying to her, and the bursts
# where she takes them.
func _draw_lights() -> void:
	for index in positions.size():
		var kind := kind_of(values[index])
		var colour: Color = [SMALL, MIDDLE, LARGE][kind]
		var across := HEIGHTS[kind] * GLOW
		var at := _shown_at(index)
		var glint := 1.0 + GLINT * sin(_clock * 4.3 + positions[index].y * 0.11)
		if speeds[index] > 0.0:
			# Flying: stretched along its way to her.
			var way := (_toward - positions[index]).normalized()
			var long := minf(STREAK, speeds[index] * 0.035)
			_lights.draw_set_transform(at - way * long * 0.5, way.angle(), Vector2(1.0 + long / across, 0.6))
			_lights.draw_texture_rect(_glow, Rect2(Vector2.ONE * -across * 0.5, Vector2.ONE * across), false, Color(colour, 0.7))
			_lights.draw_set_transform(Vector2.ZERO)
		else:
			_lights.draw_texture_rect(_glow, Rect2(at - Vector2.ONE * across * 0.5, Vector2.ONE * across), false, Color(colour, GLOW_ALPHA * glint))
	for pop: Array in _pops:
		var gone := 1.0 - float(pop[2]) / POP_TIME
		var wide := POP_SIZE * (0.4 + 0.6 * gone)
		_lights.draw_texture_rect(_glow, Rect2((pop[0] as Vector2) + Vector2(0.0, -22.0) - Vector2.ONE * wide * 0.5, Vector2.ONE * wide), false, Color(pop[1], 0.75 * (1.0 - gone)))
