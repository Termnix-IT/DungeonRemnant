class_name CrestButton
extends Button

# The departure's one action (HubSortie), drawn as this game marks its things,
# with a crest: the chapter seals, the upgrade tree's nodes and the lobby's
# menu are all crests. A round crest stands at the left with the lobby's
# crossed blades in it, and from it a bronze plate runs right with the words.
# Chosen (the focus on it, or the pointer resting on it), the crest kindles:
# the plate brightens, its edge turns gold, a glow spreads round the crest and
# a gold ring runs round it until it closes. A press darkens the plate. While
# the chapter is sealed (disabled) crest and plate stay dark.
#
# Setting out never waits for the ring: the ring closes as the button is
# chosen, and a press departs at once (SceneTransition covers the cut).
#
# The plate and crest are drawn on a layer behind the button's words
# (show_behind_parent); the button's styles only make room for the crest
# (SortieAction).

const CREST_RADIUS := 38.0
const PLATE_HEIGHT := 54.0
# Room between the crest and the button's left edge, for the ring and edge.
const CREST_INSET := 4.0
const INNER_RING := 8.0
const RING_WIDTH := 4.0
const ARC_POINTS := 64
const GLOW_RADII := [20.0, 17.0, 14.0, 11.0, 8.0, 5.0, 2.0]
const PRESS_SHADE := 0.82
# How much of the bronze edge a sealed chapter's button keeps.
const SEALED_EDGE := 0.45

# 0 rests, 1 kindled as the chosen action (UIMotion.stand()).
var stand := 0.0:
	set(value):
		stand = value
		if _back != null:
			_back.queue_redraw()
var _back: Control
var _icon: NavigationIcon
var _pointed := false


func _init() -> void:
	theme_type_variation = &"SortieAction"
	custom_minimum_size.y = (CREST_RADIUS + CREST_INSET) * 2.0
	_back = Control.new()
	_back.name = "Plate"
	_back.show_behind_parent = true
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.draw.connect(_draw_back)
	_icon = NavigationIcon.new()
	_icon.kind = "出撃"
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


func _draw_back() -> void:
	var weight := 0.0 if disabled else clampf(stand, 0.0, 1.0)
	var centre := _crest_centre()
	var shade := PRESS_SHADE if get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else 1.0
	var gold := get_theme_color(&"chosen_edge", &"SortieAction")
	var edge := get_theme_color(&"edge", &"SortieAction").lerp(gold, weight)
	if disabled:
		edge.a *= SEALED_EDGE
	# The glow spreads round the crest once it kindles.
	if weight > 0.0:
		var glow := get_theme_color(&"glow", &"SortieAction")
		for extra: float in GLOW_RADII:
			_back.draw_circle(centre, CREST_RADIUS + extra, Color(glow, glow.a * weight))
	# The plate, from the crest's middle to the button's right end.
	var plate := Rect2(centre.x, centre.y - PLATE_HEIGHT * 0.5, _back.size.x - centre.x, PLATE_HEIGHT)
	var top: Color
	var bottom: Color
	if disabled:
		top = get_theme_color(&"plate_off", &"SortieAction")
		bottom = top.darkened(0.3)
	else:
		top = get_theme_color(&"plate_top", &"SortieAction").lerp(get_theme_color(&"plate_lit_top", &"SortieAction"), weight)
		bottom = get_theme_color(&"plate_bottom", &"SortieAction").lerp(get_theme_color(&"plate_lit_bottom", &"SortieAction"), weight)
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
	var ground := get_theme_color(ground_key, &"SortieAction").lerp(get_theme_color(&"crest_lit", &"SortieAction"), weight)
	_back.draw_circle(centre, CREST_RADIUS, ground)
	_back.draw_arc(centre, CREST_RADIUS, 0.0, TAU, ARC_POINTS, edge, lerpf(1.5, 2.0, weight), true)
	_back.draw_arc(centre, CREST_RADIUS - INNER_RING, 0.0, TAU, ARC_POINTS, Color(edge, edge.a * 0.6), 1.0, true)
	if weight > 0.0:
		var ring := get_theme_color(&"ring", &"SortieAction")
		_back.draw_arc(centre, CREST_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * weight, ARC_POINTS, ring, RING_WIDTH, true)
	var emblem := &"emblem_off" if disabled else &"emblem_rest"
	_icon.modulate = get_theme_color(emblem, &"SortieAction").lerp(Color.WHITE, weight)
