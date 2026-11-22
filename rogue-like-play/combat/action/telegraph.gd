class_name Telegraph
extends Node2D

# The warning of a foe's attack on the floor: its shape (AttackData) drawn
# where it will strike, filling from the attacker outward as the wind-up
# runs, so the moment it lands can be read and dodged. It flashes when the
# blow comes and fades. Drawn under the actors. Its red edge carries a pale
# line down its middle, so the shape's outline reads by its brightness on a
# floor that is itself red or brown, where the red alone sank into it.
# Over the plain shape a shader lights it (telegraph.gdshader): deeper
# toward the blow's edge, a bright front running out with the wind-up and
# bands behind it, throbbing as the blow nears. A heavier blow (`weight`: an
# elite's 1, a boss's 2) is drawn deeper and with a thicker edge, so the
# blows that matter most are the ones seen first.

const FILL := Color(1.0, 0.26, 0.16, 0.16)
const EDGE := Color(1.0, 0.36, 0.22, 0.75)
const CHARGE := Color(1.0, 0.3, 0.18, 0.34)
const STRIKE := Color(1.0, 0.78, 0.55, 0.32)
const LIGHT := Color(1.0, 0.93, 0.8, 0.7)
const EDGE_WIDTH := 3.0
const LIGHT_WIDTH := 1.0
const FADE := 0.14
const SEGMENTS := 40
const LOOK := preload("res://combat/action/telegraph.gdshader")

var attack: AttackData
var facing := Vector2.RIGHT
var progress := 0.0
# 0 a crowd foe's blow, 1 an elite's, 2 a boss's.
var weight := 0.0
var _struck := false
var _fade := 1.0
var _look: ShaderMaterial
var _clock := 0.0


func setup(shape: AttackData, origin: Vector2, direction: Vector2, heavy: float = 0.0) -> void:
	attack = shape
	position = origin
	facing = direction.normalized()
	weight = heavy
	_look = ShaderMaterial.new()
	_look.shader = LOOK
	_look.set_shader_parameter(&"reach", attack.reach)
	_look.set_shader_parameter(&"weight", weight)
	_look.set_shader_parameter(&"along", facing if attack.shape == AttackData.Shape.LINE else Vector2.ZERO)
	material = _look
	queue_redraw()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if _look != null:
		_look.set_shader_parameter(&"progress", progress)
	queue_redraw()


# The blow lands: a flash, then it fades and frees itself.
func strike() -> void:
	if _struck:
		return
	_struck = true
	progress = 1.0
	if _look != null:
		_look.set_shader_parameter(&"struck", 1.0)
	var tween := create_tween()
	tween.tween_property(self, "_fade", 0.0, FADE)
	tween.tween_callback(queue_free)


func cancel() -> void:
	queue_free()


func _process(delta: float) -> void:
	_clock += delta
	if _look != null:
		_look.set_shader_parameter(&"clock", _clock)
	if _struck:
		queue_redraw()


func _draw() -> void:
	if attack == null:
		return
	var edge := Color(EDGE, EDGE.a * _fade)
	var edge_width := EDGE_WIDTH + weight
	var light := Color(LIGHT, LIGHT.a * _fade)
	var fill := Color(STRIKE, STRIKE.a * _fade) if _struck else FILL
	match attack.shape:
		AttackData.Shape.CIRCLE:
			draw_circle(Vector2.ZERO, attack.reach, fill)
			if not _struck:
				draw_circle(Vector2.ZERO, attack.reach * progress, CHARGE)
			draw_arc(Vector2.ZERO, attack.reach, 0.0, TAU, SEGMENTS, edge, edge_width)
			draw_arc(Vector2.ZERO, attack.reach, 0.0, TAU, SEGMENTS, light, LIGHT_WIDTH)
		AttackData.Shape.LINE:
			var side := facing.orthogonal() * attack.width * 0.5
			var tip := facing * attack.reach
			draw_colored_polygon(PackedVector2Array([side, tip + side, tip - side, -side]), fill)
			if not _struck:
				var reached := facing * attack.reach * progress
				draw_colored_polygon(PackedVector2Array([side, reached + side, reached - side, -side]), CHARGE)
			var outline := PackedVector2Array([side, tip + side, tip - side, -side, side])
			draw_polyline(outline, edge, edge_width)
			draw_polyline(outline, light, LIGHT_WIDTH)
		AttackData.Shape.ARC:
			var half := deg_to_rad(attack.arc_degrees) * 0.5
			var angle := facing.angle()
			draw_colored_polygon(_sector(attack.reach, angle, half), fill)
			if not _struck:
				draw_colored_polygon(_sector(attack.reach * maxf(progress, 0.02), angle, half), CHARGE)
			var rim := _sector(attack.reach, angle, half, true)
			draw_polyline(rim, edge, edge_width)
			draw_polyline(rim, light, LIGHT_WIDTH)


func _sector(radius: float, angle: float, half: float, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	for index in SEGMENTS + 1:
		points.append(Vector2.from_angle(angle - half + 2.0 * half * index / SEGMENTS) * radius)
	if closed:
		points.append(Vector2.ZERO)
	return points
