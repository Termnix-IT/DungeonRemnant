class_name GroundRing
extends Node2D

# A ring of light racing out over the floor from where a round blow (a
# charged swing, the skill) lands, to the blow's reach, and fading as it
# goes: what the blow covered, shown at once. Drawn under the actors, added
# as light; it frees itself.

const TIME := 0.32
const SEGMENTS := 48
const WIDTH := 7.0
# Ring colours by the attack's painted effect.
const COLORS := {&"magic": Color(0.62, 0.7, 1.0), &"heavy": Color(1.0, 0.8, 0.45), &"roar": Color(1.0, 0.28, 0.18)}
const DEFAULT := Color(1.0, 0.92, 0.75)

var radius := 100.0
var color := DEFAULT
var phase := 0.0:
	set(value):
		phase = value
		queue_redraw()


func _ready() -> void:
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light


func start(at: Vector2, reach: float, effect: StringName) -> void:
	position = at
	radius = reach
	color = COLORS.get(effect, DEFAULT)
	var tween := create_tween()
	tween.tween_property(self, "phase", 1.0, TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var fade := 1.0 - phase
	# A true circle, as the blow's reach is measured (and the foes' warnings
	# are drawn).
	var at := lerpf(radius * 0.25, radius, phase)
	draw_circle(Vector2.ZERO, at, Color(color, 0.1 * fade))
	draw_arc(Vector2.ZERO, at, 0.0, TAU, SEGMENTS, Color(color, 0.85 * fade), WIDTH * fade + 1.0, true)
	draw_arc(Vector2.ZERO, at * 0.82, 0.0, TAU, SEGMENTS, Color(color, 0.35 * fade), 2.0, true)
