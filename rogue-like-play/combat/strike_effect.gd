extends Node2D

# One attack's effect on each cell it reaches. A kind with a frame strip in
# SHEETS plays it (third-party pixel art built by tools/build_effect_sheets.py;
# see THIRD_PARTY_NOTICES.md); the rest are drawn as lines. On a line of cells
# (a bolt) each later cell starts a beat after the one before.
const TP := "res://art/third_party/"
# kind: [strip, frames per second, world px per art px, pivot in art px, turns with the attack]
const SHEETS := {
	&"magic": [TP + "devwizard_pixel_art_spells/magic.png", 15.0, 3.0, Vector2(8, 8), true],
	&"flame": [TP + "foozle_pixel_magic_effects/flame.png", 20.0, 1.0, Vector2(32, 32), true],
	&"slash": [TP + "pvfx_foundry/slash.png", 20.0, 1.0, Vector2(48, 50), true],
	&"heavy": [TP + "pvfx_foundry/heavy.png", 20.0, 1.0, Vector2(48, 71), false],
	&"hit": [TP + "pvfx_foundry/hit.png", 20.0, 1.0, Vector2(48, 56), false],
	&"heal": [TP + "pvfx_foundry/heal.png", 20.0, 1.0, Vector2(48, 67), false],
	&"death": [TP + "pvfx_foundry/death.png", 20.0, 1.0, Vector2(48, 48), false],
}
const STAGGER := 0.04
static var _strips: Dictionary = {}

var kind: StringName = &"slash"
var points: Array[Vector2] = []
var direction := Vector2.RIGHT
var phase := 0.0:
	set(value):
		phase = value
		queue_redraw()
var _strip: Texture2D
var _duration := 0.22


func start(effect_kind: StringName, cells: Array[Vector2], facing: Vector2, duration: float = 0.22) -> void:
	kind = effect_kind
	points = cells
	direction = facing.normalized()
	z_index = 12
	_strip = strip(kind)
	_duration = duration
	if _strip != null:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var fps: float = SHEETS[kind][1]
		_duration = frame_count(_strip) / fps + STAGGER * maxi(points.size() - 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "phase", 1.0, _duration)
	tween.tween_callback(queue_free)


static func strip(effect_kind: StringName) -> Texture2D:
	if not SHEETS.has(effect_kind):
		return null
	if not _strips.has(effect_kind):
		_strips[effect_kind] = load(SHEETS[effect_kind][0])
	return _strips[effect_kind]


# How long the longest strip plays, for callers that wait for effects to clear.
static func longest_duration() -> float:
	var longest := 0.0
	for effect_kind: StringName in SHEETS:
		var fps: float = SHEETS[effect_kind][1]
		longest = maxf(longest, frame_count(strip(effect_kind)) / fps)
	return longest


static func frame_count(texture: Texture2D) -> int:
	return maxi(1, texture.get_width() / texture.get_height())


# The strip is drawn mirrored rather than upside down for attacks to the left,
# so fire and arcs keep their top side up.
func _draw_frames() -> void:
	var spec: Array = SHEETS[kind]
	var fps: float = spec[1]
	var world_scale: float = spec[2]
	var pivot: Vector2 = spec[3]
	var turns: bool = spec[4]
	var side := float(_strip.get_height())
	var count := frame_count(_strip)
	var flip := turns and direction.x < -0.01
	var aim := Vector2(-direction.x, direction.y) if flip else direction
	var angle := 0.0
	if turns:
		angle = -aim.angle() if flip else aim.angle()
	var scale := Vector2(-world_scale if flip else world_scale, world_scale)
	var elapsed := phase * _duration
	for index in points.size():
		var local := (elapsed - index * STAGGER) * fps
		if local < 0.0 or local >= count:
			continue
		draw_set_transform(points[index], angle, scale)
		draw_texture_rect_region(_strip, Rect2(-pivot, Vector2.ONE * side), Rect2(floorf(local) * side, 0, side, side))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if _strip != null:
		_draw_frames()
		return
	var tint := Color("f3dfb2")
	if kind == &"magic":
		tint = Color("bdb1f1")
	elif kind == &"heal":
		tint = Color("8ed7b6")
	elif kind == &"heavy":
		tint = Color("d6b287")
	tint.a = (1.0 - phase) * 0.9
	var side := direction.orthogonal()
	for center in points:
		match kind:
			&"slash":
				var angle := direction.angle() - 1.2 + phase * 1.1
				draw_arc(center - direction * 9, 17 + phase * 7, angle, angle + 1.7, 12, tint, 3, true)
			&"thrust":
				var tip := center + direction * (phase * 18 - 6)
				draw_line(tip - direction * 22, tip, tint, 3, true)
				draw_line(tip - direction * 6 + side * 4, tip, tint, 2, true)
				draw_line(tip - direction * 6 - side * 4, tip, tint, 2, true)
			&"magic":
				draw_circle(center, 5 + phase * 11, Color(tint, tint.a * 0.2))
				draw_arc(center, 8 + phase * 12, 0, TAU, 16, tint, 2, true)
				for index in 4:
					var ray := Vector2.from_angle(index * PI / 2 + phase)
					draw_line(center + ray * 5, center + ray * (12 + phase * 6), tint, 2, true)
			&"heal":
				draw_arc(center, 12 + phase * 12, 0, TAU, 20, tint, 2, true)
				draw_line(center + Vector2(0, -9 - phase * 8), center + Vector2(0, 3 - phase * 8), tint, 3)
				draw_line(center + Vector2(-6, -3 - phase * 8), center + Vector2(6, -3 - phase * 8), tint, 3)
			_:
				for index in 6:
					var ray := Vector2.from_angle(index * TAU / 6 + direction.angle())
					draw_line(center + ray * (3 + phase * 10), center + ray * (11 + phase * 16), tint, 2, true)
				if kind == &"heavy":
					draw_arc(center, 4 + phase * 23, 0, TAU, 20, tint, 2, true)
