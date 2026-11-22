class_name SparkField
extends Node2D

# The small lights that fly off what happens in a fight: sparks off a blow
# that lands, motes of the echo rising out of a foe that falls, embers off a
# blast, the gold that rises round her as she grows. All of them are kept in
# packed arrays and drawn in one go, added as light, so a crowd struck at
# once costs one node and no more than MAX of them are ever alive (the
# oldest give way). They never change what happens in the fight.

const MAX := 420
# A spark slows by this share a second, and one that rises is lifted by this
# much (world px/s squared).
const DRAG := 3.2
const LIFT := -60.0

var positions := PackedVector2Array()
var speeds := PackedVector2Array()
# Seconds left and seconds in all, of each.
var lives := PackedFloat32Array()
var spans := PackedFloat32Array()
var sizes := PackedFloat32Array()
var colours := PackedColorArray()
# 1: it rises as it fades (a mote); 0: it only slows (a spark).
var rises := PackedFloat32Array()
var _dot: GradientTexture2D


func _ready() -> void:
	z_index = 14
	var added := CanvasItemMaterial.new()
	added.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = added
	var fall := Gradient.new()
	fall.set_color(0, Color.WHITE)
	fall.set_color(1, Color(1, 1, 1, 0))
	fall.add_point(0.3, Color(1, 1, 1, 0.55))
	_dot = GradientTexture2D.new()
	_dot.gradient = fall
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	_dot.width = 32
	_dot.height = 32


func count() -> int:
	return positions.size()


# `amount` lights thrown from a point: along `toward` within `spread`
# radians either side (a zero `toward`: every way), at speeds between
# `speed`'s two, living between `life`'s two seconds. `rise` above 0 lifts
# them as they go.
func burst(at: Vector2, amount: int, colour: Color, toward := Vector2.ZERO, spread := PI, speed := Vector2(60.0, 220.0), life := Vector2(0.18, 0.4), size := 5.0, rise := 0.0) -> void:
	var aim := toward.angle() if toward.length() > 0.01 else 0.0
	var around := spread if toward.length() > 0.01 else PI
	for index in amount:
		if positions.size() >= MAX:
			_drop(0)
		var way := Vector2.from_angle(aim + randf_range(-around, around))
		var span := randf_range(life.x, life.y)
		positions.append(at + way * randf_range(0.0, 6.0))
		speeds.append(way * randf_range(speed.x, speed.y))
		lives.append(span)
		spans.append(span)
		sizes.append(size * randf_range(0.7, 1.3))
		colours.append(colour)
		rises.append(rise)


func _drop(index: int) -> void:
	positions.remove_at(index)
	speeds.remove_at(index)
	lives.remove_at(index)
	spans.remove_at(index)
	sizes.remove_at(index)
	colours.remove_at(index)
	rises.remove_at(index)


func _process(delta: float) -> void:
	if positions.is_empty():
		return
	var slow := exp(-DRAG * delta)
	for index in range(positions.size() - 1, -1, -1):
		lives[index] -= delta
		if lives[index] <= 0.0:
			_drop(index)
			continue
		speeds[index] = speeds[index] * slow + Vector2(0.0, LIFT * rises[index] * delta)
		positions[index] += speeds[index] * delta
	queue_redraw()


# Each a point of light stretched along its way, fading and shrinking.
func _draw() -> void:
	for index in positions.size():
		var left := lives[index] / spans[index]
		var across := sizes[index] * (0.5 + 0.5 * left)
		var fast := speeds[index].length()
		draw_set_transform(positions[index], speeds[index].angle(), Vector2(1.0 + minf(fast * 0.012, 3.0), 1.0))
		draw_texture_rect(_dot, Rect2(Vector2.ONE * -across, Vector2.ONE * across * 2.0), false, Color(colours[index], left))
	draw_set_transform(Vector2.ZERO)
