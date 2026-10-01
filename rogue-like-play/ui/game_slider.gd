class_name GameSlider
extends HSlider

# A game-style bar for a level such as volume: ◈━━━●━━━━◇. HSlider keeps the
# pointer drag, wheel, keyboard and gamepad handling; the theme makes its own
# track and grabber invisible and this draws the gilt bar over the same
# geometry, so the knob sits exactly where the native grabber would.

const END_RADIUS := 7.0
const KNOB_RADIUS := 9.0

var _hovered := false


func _init() -> void:
	theme_type_variation = &"GameSlider"
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var track := get_theme_color(&"track")
	var fill := get_theme_color(&"fill")
	var knob := get_theme_color(&"knob")
	var active := has_focus() or _hovered
	var middle := size.y * 0.5
	# The native grabber travels between half its width from either edge.
	var reach := get_theme_icon(&"grabber").get_width() * 0.5
	var start := Vector2(reach, middle)
	var finish := Vector2(size.x - reach, middle)
	var ratio := 0.0 if is_equal_approx(max_value, min_value) else (value - min_value) / (max_value - min_value)
	var at := start.lerp(finish, ratio)
	draw_line(start, finish, track, 2.0, true)
	draw_line(start, at, fill, 3.0, true)
	# Filled diamond at the quiet end, hollow at the loud end.
	_diamond(start, END_RADIUS, fill, true)
	_diamond(start, END_RADIUS * 0.45, get_theme_color(&"knob_core"), true)
	_diamond(finish, END_RADIUS, fill if ratio >= 1.0 else track, false)
	if active:
		for ring in 4:
			draw_circle(at, KNOB_RADIUS + 10.0 - ring * 3.0, Color(fill, 0.08))
	draw_circle(at, KNOB_RADIUS, knob)
	draw_circle(at, KNOB_RADIUS * 0.45, get_theme_color(&"knob_core"))
	draw_arc(at, KNOB_RADIUS, 0, TAU, 24, fill, 1.5, true)


func _diamond(center: Vector2, radius: float, color: Color, filled: bool) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	if filled:
		draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, 1.5, true)
