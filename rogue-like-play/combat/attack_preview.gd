extends Node2D

# Attack range while aiming: a faint wash with gold corner brackets per cell,
# and a reticle on cells that currently hold a target.
const RANGE_COLOR := Color(1.0, 0.8, 0.42)
const TARGET_COLOR := Color(1.0, 0.46, 0.32)
const BRACKET := 0.26
const PULSE_SPEED := 4.0

var cells: Array[Vector2i] = []
var target_cells: Array[Vector2i] = []
var tile_size := 48
var _phase := 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_phase = fmod(_phase + delta * PULSE_SPEED, TAU)
	queue_redraw()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(_phase)
	for cell in cells:
		var area := Rect2(Vector2(cell * tile_size), Vector2.ONE * tile_size).grow(-3.0)
		var target := cell in target_cells
		var color := TARGET_COLOR if target else RANGE_COLOR
		draw_rect(area, Color(color, (0.16 if target else 0.08) + 0.05 * glow))
		_brackets(area, Color(color, 0.7 + 0.3 * glow), 2.0)
		if target:
			_reticle(area.get_center(), area.size.x * 0.32, Color(color, 0.85))


func _brackets(area: Rect2, color: Color, width: float) -> void:
	var arm := area.size.x * BRACKET
	for corner in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
		var horizontal := Vector2(arm if corner.x == area.position.x else -arm, 0)
		var vertical := Vector2(0, arm if corner.y == area.position.y else -arm)
		draw_polyline(PackedVector2Array([corner + horizontal, corner, corner + vertical]), color, width)


func _reticle(center: Vector2, radius: float, color: Color) -> void:
	draw_arc(center, radius, 0, TAU, 32, color, 1.5, true)
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + direction * (radius - 4), center + direction * (radius + 5), color, 2.0)
