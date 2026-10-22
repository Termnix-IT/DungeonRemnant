class_name GemField
extends Node2D

# The experience gems on a battlefield, all in packed arrays and drawn in one
# go: a fallen foe drops one, a gem within the hero's pull flies to her
# faster and faster, and one that reaches her is collected. A gem dropped
# springs out of the fallen foe: it slides a little way off and hops in a
# low arc before it settles, as loot sprays in action games. Past MAX_GEMS a
# new gem is added into the nearest one instead, so a long fight never piles
# up nodes or draw calls.

signal collected(amount: int)

const MAX_GEMS := 300
const PULL_RADIUS := 110.0
const COLLECT_RADIUS := 18.0
const PULL_ACCELERATION := 2600.0
const SMALL := Color("7fe6ff")
const MIDDLE := Color("8dff9a")
const LARGE := Color("ffd25e")
const EDGE := Color(1, 1, 1, 0.8)
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


func _ready() -> void:
	z_index = 1


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


func _draw() -> void:
	for index in positions.size():
		var value := values[index]
		var color := LARGE if value >= 10 else (MIDDLE if value >= 4 else SMALL)
		var size := 5.0 if value < 4 else (7.0 if value < 10 else 9.0)
		# Lifted off the ground while it hops.
		var at := positions[index] - Vector2(0, HOP_HEIGHT * sin(PI * hops[index] / HOP_TIME))
		var diamond := PackedVector2Array([at + Vector2(0, -size * 1.3), at + Vector2(size, 0), at + Vector2(0, size * 1.3), at + Vector2(-size, 0)])
		draw_colored_polygon(diamond, color)
		diamond.append(diamond[0])
		draw_polyline(diamond, EDGE, 1.0)
