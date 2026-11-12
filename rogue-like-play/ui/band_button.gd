class_name BandButton
extends Button

# A question's answer on its band (ChoicePrompt): a plate with a thin edge,
# its words in the display face. Only the chosen one lights: its edge turns
# gold, its face warms from the bottom up and a faint glow spreads round it.
# Moving between the answers fades one out as the other lights (`stand`,
# tweened by UIMotion.stand()), so the change reads as a glide, not a blink.
# Pointing at an answer chooses it (the focus follows the pointer), so the
# keys and the pointer never light two answers at once. A press darkens the
# plate. An answer that cannot be undone (BandDangerButton) is drawn in red.
#
# The plate is drawn on a layer behind the words (show_behind_parent); the
# button's own styles only keep the room round the words.

const GLOW_STEPS := [10.0, 7.0, 4.5, 2.5]
const PRESS_SHADE := 0.8

# 0 rests, 1 lit as the chosen answer.
var stand := 0.0:
	set(value):
		stand = value
		if _back != null:
			_back.queue_redraw()
var _back: Control


func _init() -> void:
	theme_type_variation = &"BandButton"
	_back = Control.new()
	_back.name = "Plate"
	_back.show_behind_parent = true
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.draw.connect(_draw_back)
	focus_entered.connect(_light)
	focus_exited.connect(_light)
	draw.connect(_back.queue_redraw)


func _light() -> void:
	UIMotion.of(self).stand(has_focus())


func _draw_back() -> void:
	var weight := clampf(stand, 0.0, 1.0)
	var plate := Rect2(Vector2.ZERO, _back.size)
	var shade := PRESS_SHADE if get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else 1.0
	if weight > 0.0:
		var glow := get_theme_color(&"glow")
		for reach: float in GLOW_STEPS:
			_back.draw_rect(plate.grow(reach), Color(glow, glow.a * weight), true)
	var top := get_theme_color(&"face").lerp(get_theme_color(&"lit_face_top"), weight)
	var bottom := get_theme_color(&"face").lerp(get_theme_color(&"lit_face_bottom"), weight)
	top = Color(top.r * shade, top.g * shade, top.b * shade, top.a)
	bottom = Color(bottom.r * shade, bottom.g * shade, bottom.b * shade, bottom.a)
	_back.draw_polygon(
		PackedVector2Array([plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var edge := get_theme_color(&"edge").lerp(get_theme_color(&"lit_edge"), weight)
	# Hairlines one screen pixel wide (-1): a 1-unit line scaled down on a
	# smaller window would drop out on some sides.
	_back.draw_rect(plate.grow(-0.5), edge, false, -1.0)
	# A finer inner line once lit, as a gilded plate's double edge.
	if weight > 0.0:
		var lit := get_theme_color(&"lit_edge")
		_back.draw_rect(plate.grow(-3.5), Color(lit, lit.a * 0.28 * weight), false, -1.0)
