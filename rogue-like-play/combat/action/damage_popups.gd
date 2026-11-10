class_name DamagePopups
extends Node2D

# The numbers that jump off a struck body: dealt in pale gold, taken in red.
# Each pops a little larger, rises and fades. Only MAX_SHOWN are kept, the
# oldest dropped first, so a crowd struck at once never floods the screen.
# A number stands where no number still showing would cross it, so blows
# landing together on one body read as their own numbers and not as one
# longer number: at its body's spot when that is free, else beside it, else
# in a row above (LANES); when a crowd struck at once has taken them all,
# where it crosses the fewest.

const MAX_SHOWN := 36
const DEALT := Color("ffe9b0")
const DEALT_OUTLINE := Color("241606")
const TAKEN := Color("ff5a4e")
const TAKEN_OUTLINE := Color("2e0707")
const FONT_SIZE := 22
const OUTLINE := 6
const RISE := 30.0
const LIFE := 0.6
# Where a number may stand round its spot, tried in turn. The row above
# stands higher than the first row climbs, the taller red numbers too.
const LANES: Array[Vector2] = [Vector2.ZERO, Vector2(-34, 0), Vector2(34, 0), Vector2(-68, 0), Vector2(68, 0),
	Vector2(-17, -62), Vector2(17, -62), Vector2(-51, -62), Vector2(51, -62)]
# A number holds its lane this long; after that it is fading and gives way.
const HOLD := 0.45
# Kept clear round a number's digits.
const CLEARANCE := 2.0

var _shown: Array[Label] = []


func _ready() -> void:
	z_index = 30


func dealt(amount: int, at: Vector2) -> void:
	show_number(str(amount), at, DEALT, DEALT_OUTLINE)


func taken(amount: int, at: Vector2) -> void:
	show_number(str(amount), at, TAKEN, TAKEN_OUTLINE, FONT_SIZE + 4)


func show_number(text: String, at: Vector2, color: Color, outline: Color, size: int = FONT_SIZE) -> Label:
	while _shown.size() >= MAX_SHOWN:
		var oldest: Label = _shown.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", OUTLINE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, size + 10)
	label.pivot_offset = label.size * 0.5
	add_child(label)
	# Its digits' extent, known once it has the scene's font.
	var digits := Vector2(label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + OUTLINE, size)
	var track := _free_track(at, digits)
	label.set_meta(&"track", track)
	label.set_meta(&"born", Time.get_ticks_msec())
	label.position = Vector2(track.get_center().x, track.end.y - CLEARANCE - digits.y * 0.5) - label.size * 0.5
	_shown.append(label)
	label.scale = Vector2.ONE * 1.45
	var tween := label.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - RISE, LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.22).set_delay(LIFE - 0.22)
	tween.tween_callback(func():
		_shown.erase(label)
		label.queue_free())
	return label


# What a number showing covers on its way up (track()); an empty rectangle
# for one that has gone.
static func track_of(label: Label) -> Rect2:
	return label.get_meta(&"track", Rect2()) if is_instance_valid(label) else Rect2()


# The ground a number of these digits covers from `at` to the top of its
# climb.
static func track(at: Vector2, digits: Vector2) -> Rect2:
	var half := digits * 0.5 + Vector2.ONE * CLEARANCE
	return Rect2(at.x - half.x, at.y - RISE - half.y, half.x * 2.0, RISE + half.y * 2.0)


# The first lane round `at` whose climb crosses no number still holding its
# own; with every lane taken (a crowd struck at once), the lane that crosses
# the fewest.
func _free_track(at: Vector2, digits: Vector2) -> Rect2:
	var now := Time.get_ticks_msec()
	var held: Array[Rect2] = []
	for other in _shown:
		if is_instance_valid(other) and now - int(other.get_meta(&"born", 0)) < HOLD * 1000.0:
			held.append(track_of(other))
	var best := track(at, digits)
	var fewest := -1
	for lane in LANES:
		var candidate := track(at + lane, digits)
		var crossed := 0
		for taken_track in held:
			if taken_track.intersects(candidate):
				crossed += 1
		if crossed == 0:
			return candidate
		if fewest < 0 or crossed < fewest:
			fewest = crossed
			best = candidate
	return best
