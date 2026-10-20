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
# An item not found yet: its dark outline alone, still (the encyclopedia).
var unknown := false:
	set(value):
		unknown = value
		_sync_idle()
		queue_redraw()
static var _glow: GradientTexture2D
var _phase := 0.0

var item: ItemData:
	set(value):
		item = value
		_sync_idle()
		queue_redraw()


func _init() -> void:
	texture_filter = ItemIcons.filter()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 120)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_sync_idle()


func _sync_idle() -> void:
	set_process(idle and item != null and not unknown and is_visible_in_tree())


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta / UIMotion.IDLE_PERIOD, 1.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var wave := sin(_phase * TAU) if idle else 0.0
	if framed:
		draw_style_box(get_theme_stylebox(&"panel", &"VisualPanel"), rect)
	elif item != null and not unknown:
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
		var painted := ItemIcons.icon(item)
		var extent := minf(size.x, size.y) * (0.84 if painted != null else 0.68)
		# The painted icon is shrunk smoothly from its mipmaps, so the drift
		# moves it by fractions of a pixel instead of stepping a pixel at a time.
		var lift := Vector2(0, -wave * UIMotion.IDLE_RISE)
		var art := ItemIcons.silhouette(item) if unknown else null
		if unknown:
			var area := Rect2(((size - Vector2.ONE * extent) / 2).floor(), Vector2.ONE * extent)
			if art != null:
				draw_texture_rect(art, area, false)
			else:
				ItemGlyph.paint(self, area, item, ItemCell.UNKNOWN_SHADE)
			return
		var area := Rect2((size - Vector2.ONE * extent) / 2 + lift, Vector2.ONE * extent)
		if painted != null:
			draw_texture_rect(painted, area, false, ItemIcons.tint(get_theme_color(&"font_color", &"GoldLabel")))
		else:
			ItemGlyph.paint(self, area, item, get_theme_color(&"font_color", &"GoldLabel"))
