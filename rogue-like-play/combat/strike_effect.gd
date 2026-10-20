extends Node2D

# One attack's effect on each cell it reaches: a painted still at the
# effect's fullest (art/effects/painted/<kind>.png, built by
# tools/build_painted_effects.py), which this animates (it grows, turns with
# the attack, flickers and fades), drawn added as light or, for smoke, over
# the scene. On a line of cells (a bolt) each later cell starts a beat after
# the one before.
const DIRECTORY := "res://art/effects/painted/"
# kind: [world px across at full size, seconds, start scale, end scale,
#  turns with the attack, added as light, slide along the attack in world px,
#  spin in radians over the effect]
const PAINTED := {
	&"slash": [70.0, 0.22, 0.75, 1.1, true, true, 0.0, 0.5],
	&"thrust": [76.0, 0.18, 0.6, 1.05, true, true, 14.0, 0.0],
	&"heavy": [84.0, 0.3, 0.45, 1.15, false, true, 0.0, 0.0],
	&"hit": [54.0, 0.18, 0.5, 1.1, false, true, 0.0, 0.35],
	&"magic": [46.0, 0.3, 0.7, 1.15, true, true, 10.0, 0.0],
	&"flame": [64.0, 0.4, 0.55, 1.1, false, true, 0.0, 0.0],
	&"heal": [60.0, 0.55, 0.8, 1.05, false, true, 0.0, 0.0],
	&"death": [62.0, 0.6, 0.5, 1.25, false, false, 0.0, 0.25],
	&"level_up": [100.0, 1.0, 0.7, 1.05, false, true, 0.0, 0.0],
}
const STAGGER := 0.04
static var _images: Dictionary = {}

var kind: StringName = &"slash"
var points: Array[Vector2] = []
var direction := Vector2.RIGHT
var phase := 0.0:
	set(value):
		phase = value
		queue_redraw()
var _image: Texture2D
var _duration := 0.22


func start(effect_kind: StringName, cells: Array[Vector2], facing: Vector2) -> void:
	kind = effect_kind if PAINTED.has(effect_kind) else &"hit"
	points = cells
	direction = facing.normalized()
	z_index = 12
	_image = image(kind)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if PAINTED[kind][5]:
		var light := CanvasItemMaterial.new()
		light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = light
	_duration = float(PAINTED[kind][1]) + STAGGER * maxi(points.size() - 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "phase", 1.0, _duration)
	tween.tween_callback(queue_free)


# Loads every image; called before anything draws one (a texture first
# loaded inside a draw call can be drawn as a blank white quad).
static func warm() -> void:
	for effect_kind: StringName in PAINTED:
		image(effect_kind)


static func image(effect_kind: StringName) -> Texture2D:
	if not _images.has(effect_kind):
		var path := DIRECTORY + String(effect_kind) + ".png"
		_images[effect_kind] = load(path) if ResourceLoader.exists(path) else null
	return _images[effect_kind]


# How long the longest effect plays, for callers that wait for effects to clear.
static func longest_duration() -> float:
	var longest := 0.0
	for effect_kind: StringName in PAINTED:
		longest = maxf(longest, float(PAINTED[effect_kind][1]))
	return longest


# The still grows from its start to its end scale, eased out, turned with the
# attack (mirrored rather than upside down to the left), sliding and spinning
# a little; it is fullest a fifth of the way in and fades to nothing.
func _draw() -> void:
	if _image == null:
		return
	var spec: Array = PAINTED[kind]
	var across: float = spec[0]
	var life: float = spec[1]
	var turns: bool = spec[4]
	var slide: float = spec[6]
	var spin: float = spec[7]
	var flip := turns and direction.x < -0.01
	var aim := Vector2(-direction.x, direction.y) if flip else direction
	var angle := (-aim.angle() if flip else aim.angle()) if turns else 0.0
	var elapsed := phase * _duration
	for index in points.size():
		var t := (elapsed - index * STAGGER) / life
		if t < 0.0 or t >= 1.0:
			continue
		var grow := 1.0 - pow(1.0 - t, 3.0)
		var size: float = across * lerpf(spec[2], spec[3], grow)
		var alpha := smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.35, 1.0, t))
		# Light flickers a touch as it fades.
		if spec[5]:
			alpha *= 0.9 + 0.1 * sin(t * 40.0 + index)
		var at := points[index] + direction * slide * grow
		draw_set_transform(at, angle + spin * t, Vector2(-1.0 if flip else 1.0, 1.0))
		draw_texture_rect(_image, Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

