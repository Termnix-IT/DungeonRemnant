class_name FoeRow
extends Button

# One foe in the encyclopedia's list: its round icon (FoeIcon) on a dark
# disc at the left, its name beside it, a faint hairline under it. The row
# shown on the right (`chosen`) is lit: a warm face fading to the right, a
# thin gold edge, a gold ring round its icon and bright words; the change
# glides (`stand`, tweened by UIMotion.stand()). Pointing at a row warms it
# a little. A foe not met shows its shade and no name.
#
# The face, the icon and the lines are drawn on a layer behind the words
# (show_behind_parent); the theme's styles (CodexRow) keep the room for the
# icon at the left.

const ICON_DIAMETER := 52.0
const ICON_INSET := 14.0

var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if _back != null:
			_back.queue_redraw()
var unknown := false
var chosen := false:
	set(value):
		chosen = value
		set_pressed_no_signal(value)
		UIMotion.of(self).stand(value)
# 0 rests, 1 lit as the row shown.
var stand := 0.0:
	set(value):
		stand = value
		if _back != null:
			_back.queue_redraw()
var _back: Control


func _init() -> void:
	theme_type_variation = &"CodexRow"
	toggle_mode = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_back = Control.new()
	_back.name = "Face"
	_back.show_behind_parent = true
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.draw.connect(_draw_back)
	draw.connect(_back.queue_redraw)
	# A click on the row already shown keeps it shown.
	toggled.connect(func(on: bool):
		if not on and chosen:
			set_pressed_no_signal(true))


func _draw_back() -> void:
	var weight := clampf(stand, 0.0, 1.0)
	var rect := Rect2(Vector2.ZERO, _back.size)
	var pointed := get_draw_mode() in [DRAW_HOVER, DRAW_HOVER_PRESSED]
	# The face: warm at the left, fading out to the right.
	var face := get_theme_color(&"lit_face")
	var hover := get_theme_color(&"hover_face")
	var left := Color(face, face.a * weight)
	if pointed and weight < 1.0:
		left = left.blend(Color(hover, hover.a * (1.0 - weight)))
	if left.a > 0.0:
		var right := Color(left, left.a * 0.25)
		_back.draw_polygon(
			PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
			PackedColorArray([left, right, right, left]))
	# The hairline under every row, and the gold edge round the one shown.
	var line := get_theme_color(&"separator")
	_back.draw_line(Vector2(ICON_INSET, rect.end.y - 0.5), Vector2(rect.end.x - ICON_INSET, rect.end.y - 0.5), line, -1.0)
	if weight > 0.0:
		var edge := get_theme_color(&"lit_edge")
		_back.draw_rect(rect.grow(-0.5), Color(edge, edge.a * weight), false, -1.0)
	# The icon on its disc, ringed.
	var centre := Vector2(ICON_INSET + ICON_DIAMETER * 0.5, rect.size.y * 0.5)
	var radius := ICON_DIAMETER * 0.5
	_back.draw_circle(centre, radius, get_theme_color(&"disc"))
	if icon_texture != null:
		_back.draw_texture_rect(icon_texture, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * ICON_DIAMETER), false)
	var ring := get_theme_color(&"ring").lerp(get_theme_color(&"lit_ring"), weight)
	_back.draw_arc(centre, radius, 0.0, TAU, 48, ring, 1.5, true)
