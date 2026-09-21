class_name ItemVisual
extends Control

var item: ItemData:
	set(value):
		item = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(112, 112)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox(&"panel", &"VisualPanel"), rect)
	if item != null:
		var extent := minf(size.x, size.y) * 0.68
		ItemGlyph.paint(self, Rect2((size - Vector2.ONE * extent) / 2, Vector2.ONE * extent), item, get_theme_color(&"font_color", &"GoldLabel"))
