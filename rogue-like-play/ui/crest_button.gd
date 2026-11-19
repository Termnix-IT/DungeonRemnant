class_name CrestButton
extends Button

# The one action of a screen that is a moment of its own (setting out on the
# departure, HubSortie; buying on the upgrade tree, MetaUpgradePage), drawn
# as this game marks its things, with a crest: the chapter seals, the upgrade
# tree's nodes and the lobby's menu are all crests. A round crest stands at
# the left with the lobby's menu mark for the screen in it (`kind`, a
# NavigationIcon: the crossed blades, the open book of upgrades), and from it
# a bronze plate runs right with the words. Chosen (the focus on it, or the
# pointer resting on it), the crest kindles: the plate brightens, its edge
# turns gold, a glow spreads round the crest and a gold ring runs round it
# until it closes. A press darkens the plate. While it cannot be pressed
# (disabled) crest and plate stay dark.
#
# The action never waits for the ring: the ring closes as the button is
# chosen, and a press acts at once.
#
# The plate and crest are drawn on a layer behind the button's words
# (show_behind_parent); the button's styles only make room for the crest
# (CrestAction).
#
# Given a medallion (`medal`, a painted bronze one: the lobby's menu
# medallions), the button is painted instead of drawn: the medallion stands
# at the left over a forged gold plate (button_gold.png and its lit and
# pressed states). Chosen, the plate turns to its lit state, the medallion
# brightens and swells a little and a warm light spreads behind it; a press
# sets both down; sealed, both go dark.

const CREST_RADIUS := 38.0
const PLATE_HEIGHT := 54.0
# Room between the crest and the button's left edge, for the ring and edge.
const CREST_INSET := 4.0
const INNER_RING := 8.0
const RING_WIDTH := 4.0
const ARC_POINTS := 64
const GLOW_RADII := [20.0, 17.0, 14.0, 11.0, 8.0, 5.0, 2.0]
const PRESS_SHADE := 0.82
# Painted: the plate's three states, how much of each end is kept whole as
# its middle stretches, how tall it stands, the medallion's size and how
# much it swells when chosen, and how wide the light behind it spreads.
const PLATES := {
	&"rest": preload("res://art/ui/button_gold.png"),
	&"lit": preload("res://art/ui/button_gold_hover.png"),
	&"pressed": preload("res://art/ui/button_gold_pressed.png"),
}
const PLATE_ENDS := Vector2(19.0, 21.0)
const PAINTED_PLATE_HEIGHT := 60.0
const MEDAL_RADIUS := 42.0
const MEDAL_SWELL := 0.08
const MEDAL_PRESS := 0.95
const MEDAL_LIGHT := 170.0
# How much of the bronze edge the button keeps while it cannot be pressed.
const SEALED_EDGE := 0.45

# 0 rests, 1 kindled as the chosen action (UIMotion.stand()).
var stand := 0.0:
	set(value):
		stand = value
		if _back != null:
			_back.queue_redraw()
# The lobby's menu mark drawn in the crest (NavigationIcon.kind).
var kind := &"departure":
	set(value):
		kind = value
		if _icon != null:
			_icon.kind = value
			_icon.queue_redraw()
# The painted medallion; none: the crest is drawn, with its mark.
var medal: Texture2D:
	set(value):
		medal = value
		if _icon != null:
			_icon.visible = medal == null
		if _back != null:
			_back.queue_redraw()
var _back: Control
var _icon: NavigationIcon
var _boxes := {}
var _light: GradientTexture2D
var _pointed := false


func _init() -> void:
	theme_type_variation = &"CrestAction"
	custom_minimum_size.y = (CREST_RADIUS + CREST_INSET) * 2.0
	_back = Control.new()
	_back.name = "Plate"
	_back.show_behind_parent = true
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.draw.connect(_draw_back)
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon = NavigationIcon.new()
	_icon.kind = kind
	_icon.visible = medal == null
	_back.add_child(_icon)
	_back.resized.connect(_place_icon)
	focus_entered.connect(_kindle)
	focus_exited.connect(_kindle)
	mouse_entered.connect(func():
		_pointed = true
		_kindle())
	mouse_exited.connect(func():
		_pointed = false
		_kindle())
	# The button redraws on every change of state (pressed, disabled); its
	# plate follows.
	draw.connect(_back.queue_redraw)


func _kindle() -> void:
	UIMotion.of(self).stand(has_focus() or _pointed)


func _crest_centre() -> Vector2:
	return Vector2(CREST_INSET + CREST_RADIUS, _back.size.y * 0.5)


func _place_icon() -> void:
	_icon.size = _icon.custom_minimum_size
	_icon.position = _crest_centre() - _icon.size * 0.5


# One of the painted plate's states as a box whose ends keep their size.
func _plate_box(state: StringName) -> StyleBoxTexture:
	if not _boxes.has(state):
		var box := StyleBoxTexture.new()
		box.texture = PLATES[state]
		box.texture_margin_left = PLATE_ENDS.x
		box.texture_margin_right = PLATE_ENDS.x
		box.texture_margin_top = PLATE_ENDS.y
		box.texture_margin_bottom = PLATE_ENDS.y
		_boxes[state] = box
	return _boxes[state]


func _draw_painted() -> void:
	var weight := 0.0 if disabled else clampf(stand, 0.0, 1.0)
	var centre := _crest_centre()
	var pressed := get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED]
	var off := get_theme_color(&"emblem_off")
	var plate := Rect2(centre.x - 4.0, centre.y - PAINTED_PLATE_HEIGHT * 0.5, _back.size.x - centre.x + 4.0, PAINTED_PLATE_HEIGHT)
	# The plate at rest, its lit state coming over it as it is chosen.
	var rest := _plate_box(&"pressed" if pressed else &"rest")
	rest.modulate_color = off if disabled else Color.WHITE
	_back.draw_style_box(rest, plate)
	if weight > 0.0 and not pressed:
		var lit := _plate_box(&"lit")
		lit.modulate_color = Color(1.0, 1.0, 1.0, weight)
		_back.draw_style_box(lit, plate)
	# The light behind the medallion, and the medallion.
	if _light == null:
		var fall := Gradient.new()
		fall.set_color(0, Color.WHITE)
		fall.set_color(1, Color(1, 1, 1, 0))
		fall.add_point(0.5, Color(1, 1, 1, 0.3))
		_light = GradientTexture2D.new()
		_light.gradient = fall
		_light.fill = GradientTexture2D.FILL_RADIAL
		_light.fill_from = Vector2(0.5, 0.5)
		_light.fill_to = Vector2(1.0, 0.5)
		_light.changed.connect(_back.queue_redraw)
	if weight > 0.0:
		_back.draw_texture_rect(_light, Rect2(centre - Vector2.ONE * MEDAL_LIGHT * 0.5, Vector2.ONE * MEDAL_LIGHT), false, Color(get_theme_color(&"ring"), 0.55 * weight))
	var radius := MEDAL_RADIUS * (1.0 + MEDAL_SWELL * weight) * (MEDAL_PRESS if pressed else 1.0)
	var tint := off if disabled else get_theme_color(&"emblem_rest").lerp(get_theme_color(&"medal_lit"), weight)
	_back.draw_texture_rect(medal, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)


func _draw_back() -> void:
	if medal != null:
		_draw_painted()
		return
	var weight := 0.0 if disabled else clampf(stand, 0.0, 1.0)
	var centre := _crest_centre()
	var shade := PRESS_SHADE if get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else 1.0
	var gold := get_theme_color(&"chosen_edge")
	var edge := get_theme_color(&"edge").lerp(gold, weight)
	if disabled:
		edge.a *= SEALED_EDGE
	# The glow spreads round the crest once it kindles.
	if weight > 0.0:
		var glow := get_theme_color(&"glow")
		for extra: float in GLOW_RADII:
			_back.draw_circle(centre, CREST_RADIUS + extra, Color(glow, glow.a * weight))
	# The plate, from the crest's middle to the button's right end.
	var plate := Rect2(centre.x, centre.y - PLATE_HEIGHT * 0.5, _back.size.x - centre.x, PLATE_HEIGHT)
	var top: Color
	var bottom: Color
	if disabled:
		top = get_theme_color(&"plate_off")
		bottom = top.darkened(0.3)
	else:
		top = get_theme_color(&"plate_top").lerp(get_theme_color(&"plate_lit_top"), weight)
		bottom = get_theme_color(&"plate_bottom").lerp(get_theme_color(&"plate_lit_bottom"), weight)
	top = Color(top.r * shade, top.g * shade, top.b * shade, top.a)
	bottom = Color(bottom.r * shade, bottom.g * shade, bottom.b * shade, bottom.a)
	_back.draw_polygon(
		PackedVector2Array([plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	_back.draw_rect(plate, edge, false, lerpf(1.0, 1.5, weight))
	if weight > 0.0:
		_back.draw_rect(plate.grow(-5.0), Color(gold, 0.3 * weight), false, 1.0)
	# The crest over the plate's left end: its ground, its rim and a finer
	# ring inside, then the gold ring running round as it kindles.
	var ground_key := &"crest_off" if disabled else &"crest_ground"
	var ground := get_theme_color(ground_key).lerp(get_theme_color(&"crest_lit"), weight)
	_back.draw_circle(centre, CREST_RADIUS, ground)
	_back.draw_arc(centre, CREST_RADIUS, 0.0, TAU, ARC_POINTS, edge, lerpf(1.5, 2.0, weight), true)
	_back.draw_arc(centre, CREST_RADIUS - INNER_RING, 0.0, TAU, ARC_POINTS, Color(edge, edge.a * 0.6), 1.0, true)
	if weight > 0.0:
		var ring := get_theme_color(&"ring")
		_back.draw_arc(centre, CREST_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * weight, ARC_POINTS, ring, RING_WIDTH, true)
	var emblem := &"emblem_off" if disabled else &"emblem_rest"
	_icon.modulate = get_theme_color(emblem).lerp(Color.WHITE, weight)
