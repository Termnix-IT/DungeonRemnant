class_name DamagePopups
extends Node2D

# The numbers that jump off a struck body: dealt in pale gold, taken in red.
# Each pops a little larger, rises and fades. Only MAX_SHOWN are kept, the
# oldest dropped first, so a crowd struck at once never floods the screen.

const MAX_SHOWN := 36
const DEALT := Color("ffe9b0")
const DEALT_OUTLINE := Color("241606")
const TAKEN := Color("ff5a4e")
const TAKEN_OUTLINE := Color("2e0707")
const FONT_SIZE := 22
const RISE := 30.0
const LIFE := 0.6

var _shown: Array[Label] = []
var _serial := 0


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
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, size + 10)
	label.pivot_offset = label.size * 0.5
	_serial += 1
	label.position = at - label.size * 0.5 + Vector2((_serial % 3 - 1) * 7, 0)
	add_child(label)
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
