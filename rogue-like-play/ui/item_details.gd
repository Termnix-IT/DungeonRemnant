class_name ItemDetails
extends RichTextLabel


func _init() -> void:
	theme_type_variation = &"ItemDetails"
	focus_mode = Control.FOCUS_ALL
	selection_enabled = true
	context_menu_enabled = false


func reset() -> void:
	clear()
	get_v_scroll_bar().value = 0


func line(value: String, role: StringName = &"BodyLabel") -> void:
	var color_role := role if has_theme_color(&"font_color", role) else &"Label"
	push_color(get_theme_color(&"font_color", color_role))
	push_font_size(get_theme_font_size(&"font_size", role))
	# Item names/descriptions are plain text, never executable BBCode.
	add_text(value + "\n")
	pop()
	pop()


func delta(caption: String, before: int, after: int) -> void:
	var difference := after - before
	var color := get_theme_color(&"font_color", &"MutedLabel")
	if difference > 0:
		color = get_theme_color(&"font_color", &"PositiveLabel")
	elif difference < 0:
		color = get_theme_color(&"decrease_color")
	push_color(color)
	add_text("%s  %d → %d (%+d)\n" % [caption, before, after, difference])
	pop()
