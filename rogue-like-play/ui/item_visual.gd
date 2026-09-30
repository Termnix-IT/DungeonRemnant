class_name ItemVisual
extends Control

var item: ItemData:
	set(value):
		item = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 120)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox(&"panel", &"VisualPanel"), rect)
	if item != null:
		var extent := minf(size.x, size.y) * 0.68
		if ItemIcons.icon(item) != null:
			# Whole multiples of the 48px icon keep every pixel square.
			extent = maxf(48.0, floorf(minf(size.x, size.y) * 0.84 / 48.0) * 48.0)
		ItemGlyph.paint(self, Rect2(((size - Vector2.ONE * extent) / 2).floor(), Vector2.ONE * extent), item, get_theme_color(&"font_color", &"GoldLabel"))
