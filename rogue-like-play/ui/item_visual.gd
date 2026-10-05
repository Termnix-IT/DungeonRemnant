class_name ItemVisual
extends Control

# Off where a box round the goods would be one more panel: the art stands on
# a soft glow instead (the shop).
var framed := true:
	set(value):
		framed = value
		queue_redraw()
# On for the goods on display: the art drifts up and down over its glow,
# which breathes with it (UIMotion.IDLE_PERIOD). Runs only while shown.
var idle := false:
	set(value):
		idle = value
		_sync_idle()
static var _glow: GradientTexture2D
var _phase := 0.0

var item: ItemData:
	set(value):
		item = value
		_sync_idle()
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 120)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_sync_idle()


func _sync_idle() -> void:
	set_process(idle and item != null and is_visible_in_tree())


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta / UIMotion.IDLE_PERIOD, 1.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var wave := sin(_phase * TAU) if idle else 0.0
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
		var glow := get_theme_color(&"glow", &"ItemVisual")
		glow.a *= 0.88 + 0.12 * wave
		draw_texture_rect(_glow, rect.grow(rect.size.x * 0.1), false, glow)
	if item != null:
		var extent := minf(size.x, size.y) * 0.68
		if ItemIcons.icon(item) != null:
			# Whole multiples of the 48px icon keep every pixel square.
			extent = maxf(48.0, floorf(minf(size.x, size.y) * 0.84 / 48.0) * 48.0)
		# Whole pixels, so the drift never blurs the icon.
		var lift := Vector2(0, roundf(-wave * UIMotion.IDLE_RISE))
		ItemGlyph.paint(self, Rect2(((size - Vector2.ONE * extent) / 2).floor() + lift, Vector2.ONE * extent), item, get_theme_color(&"font_color", &"GoldLabel"))
