class_name HintMark
extends Button

# A small "?" beside a caption, for a rule the player needs on the spot: its
# tooltip says the rule in a line, and a press opens the settings' help at
# the matching topic (the hub connects every mark in GROUP). Longer rules
# belong in the help, not on the screens (docs/MVP_SPEC.md, 説明の置き場所).

const GROUP := &"hint_marks"

# A HubSettings.HELP index.
var topic := 0


static func make(parent: Node, line: String, help_topic: int) -> HintMark:
	var mark := HintMark.new()
	mark.tooltip_text = line
	mark.topic = help_topic
	parent.add_child(mark)
	return mark


func _init() -> void:
	theme_type_variation = &"HintMark"
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_HELP
	custom_minimum_size = Vector2(22, 22)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_to_group(GROUP)
	pressed.connect(func():
		var hub := get_tree().get_first_node_in_group(&"hub")
		if hub != null:
			hub.call(&"open_help", topic))


func _draw() -> void:
	var middle := size * 0.5
	var tone := get_theme_color(&"font_hover_color" if is_hovered() else &"font_color")
	draw_arc(middle, minf(size.x, size.y) * 0.5 - 1.5, 0, TAU, 32, tone, 1.2, true)
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	draw_string(font, Vector2(0, middle.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, tone)
