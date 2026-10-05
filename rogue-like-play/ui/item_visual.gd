class_name ItemVisual
extends Control

# Off where a box round the goods would be one more panel: the art stands on
# a soft glow instead (the shop).
var framed := true:
	set(value):
		framed = value
		queue_redraw()
static var _glow: GradientTexture2D

var item: ItemData:
	set(value):
		item = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 120)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if framed:
		draw_style_box(get_theme_stylebox(&"panel", &"VisualPanel"), rect)
	elif item != null:
		if _glow == null:
			var fade := Gradient.new()
			fade.set_color(0, Color.WHITE)
			fade.set_color(1, Color(1, 1, 1, 0))
			_glow = GradientTexture2D.new()
			_glow.gradient = fade
			_glow.fill = GradientTexture2D.FILL_RADIAL
			_glow.fill_from = Vector2(0.5, 0.5)
			_glow.fill_to = Vector2(1.0, 0.5)
			_glow.changed.connect(queue_redraw)
		draw_texture_rect(_glow, rect.grow(rect.size.x * 0.1), false, get_theme_color(&"glow", &"ItemVisual"))
	if item != null:
		var extent := minf(size.x, size.y) * 0.68
		if ItemIcons.icon(item) != null:
			# Whole multiples of the 48px icon keep every pixel square.
			extent = maxf(48.0, floorf(minf(size.x, size.y) * 0.84 / 48.0) * 48.0)
		ItemGlyph.paint(self, Rect2(((size - Vector2.ONE * extent) / 2).floor(), Vector2.ONE * extent), item, get_theme_color(&"font_color", &"GoldLabel"))
