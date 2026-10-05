class_name KeyGuide
extends HBoxContainer

# The footer's key guide: each hint is a key cap and what it does
# ("Esc 戻る"), shown as text rather than a boxed button. A hint with an
# action can also be clicked. While a gamepad is in use the caps show its
# buttons (B, A) instead of the keys.

var _hints: Array[Button] = []
var pad := false


func _init() -> void:
	theme_type_variation = &"KeyGuide"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# keys and buttons name the cap on keyboard and on a gamepad. Without an
# action the hint only tells; it takes no pointer or focus.
func add_hint(keys: String, buttons: String, text: String, action: Callable = Callable()) -> Button:
	var hint := Button.new()
	hint.theme_type_variation = &"KeyGuideButton"
	hint.text = text
	hint.set_meta(&"keys", keys)
	hint.set_meta(&"buttons", buttons)
	hint.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if action.is_valid():
		hint.pressed.connect(action)
		hint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.focus_mode = Control.FOCUS_NONE
	hint.draw.connect(_draw_cap.bind(hint))
	add_child(hint)
	_hints.append(hint)
	_fit(hint)
	return hint


# Drops the hints after the first keep, for a screen to add its own.
func clear_hints(keep: int = 1) -> void:
	while _hints.size() > keep:
		var hint: Button = _hints.pop_back()
		remove_child(hint)
		hint.queue_free()


func _input(event: InputEvent) -> void:
	var now_pad := pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		now_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		now_pad = false
	if now_pad != pad:
		pad = now_pad
		for hint in _hints:
			_fit(hint)
			hint.queue_redraw()


func cap_text(hint: Button) -> String:
	return hint.get_meta(&"buttons" if pad else &"keys")


# The cap's width, for drawing it in the hint's left padding.
func _fit(hint: Button) -> void:
	var font := hint.get_theme_font(&"font")
	var size := hint.get_theme_font_size(&"cap_font_size")
	hint.set_meta(&"cap_width", font.get_string_size(cap_text(hint), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + hint.get_theme_constant(&"cap_padding") * 2.0)


func _draw_cap(hint: Button) -> void:
	var width: float = hint.get_meta(&"cap_width", 0.0)
	var font := hint.get_theme_font(&"font")
	var size := hint.get_theme_font_size(&"cap_font_size")
	var height := font.get_height(size) + 6.0
	# The theme's left padding holds the widest cap; each cap ends the same
	# gap before the text, so the words line up whatever the key.
	var right := hint.get_theme_stylebox(&"normal").content_margin_left - hint.get_theme_constant(&"cap_gap")
	var rect := Rect2(Vector2(right - width, (hint.size.y - height) * 0.5), Vector2(width, height))
	var active := hint.is_hovered() or hint.has_focus()
	var rim := hint.get_theme_color(&"cap_rim_active" if active else &"cap_rim")
	hint.draw_rect(rect, hint.get_theme_color(&"cap_fill"))
	hint.draw_rect(rect, rim, false, 1.0)
	var baseline := rect.position.y + (height + font.get_ascent(size) - font.get_descent(size)) * 0.5
	hint.draw_string(font, Vector2(rect.position.x, baseline), cap_text(hint), HORIZONTAL_ALIGNMENT_CENTER, width, size, rim)
