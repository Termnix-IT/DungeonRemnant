class_name GemField
extends Node2D

# The experience gems on a battlefield, all in packed arrays and drawn in one
# go: a fallen foe drops one, a gem within the hero's pull flies to her
# faster and faster, and one that reaches her is collected. Past MAX_GEMS a
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

var positions := PackedVector2Array()
var values := PackedInt32Array()
var speeds := PackedFloat32Array()
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
	queue_redraw()


# One physics frame: gems in her pull fly to her; those that reach her are
# collected. Tests call it directly.
func step(hero_at: Vector2, delta: float) -> void:
	if positions.is_empty():
		return
	var gained := 0
	for index in range(positions.size() - 1, -1, -1):
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
			continue
		positions[index] += offset / distance * move
	queue_redraw()
	if gained > 0:
		collected.emit(gained)


func clear() -> void:
	positions.clear()
	values.clear()
	speeds.clear()
	queue_redraw()


func _draw() -> void:
	for index in positions.size():
		var value := values[index]
		var color := LARGE if value >= 10 else (MIDDLE if value >= 4 else SMALL)
		var size := 5.0 if value < 4 else (7.0 if value < 10 else 9.0)
		var at := positions[index]
		var diamond := PackedVector2Array([at + Vector2(0, -size * 1.3), at + Vector2(size, 0), at + Vector2(0, size * 1.3), at + Vector2(-size, 0)])
		draw_colored_polygon(diamond, color)
		diamond.append(diamond[0])
		draw_polyline(diamond, EDGE, 1.0)
