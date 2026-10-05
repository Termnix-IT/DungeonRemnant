class_name StageMapNode
extends Button

# One stage on the stage-select map: its diorama (the dungeon on an oval
# island) standing on a soft shadow, its name and floors under it. The chosen
# stage floats a little on a warm glow with its name in gold; the others rest
# a step darker; a stage not yet open is dark and says how to open it. The
# Button keeps focus and input; the map draws the road between stages.

const ART_SHARE := 0.82
var stage: StageData
var unlocked := true
var hint := ""
var _phase := 0.0
static var _glow: GradientTexture2D


func _init() -> void:
	theme_type_variation = &"StageNode"
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL


func show_stage(value: StageData, open: bool, unlock_hint: String) -> void:
	stage = value
	unlocked = open
	hint = unlock_hint
	tooltip_text = stage.display_name
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta / UIMotion.IDLE_PERIOD, 1.0)
	queue_redraw()


# The square the diorama takes, at the top of the node.
func art_rect() -> Rect2:
	var extent := minf(size.x, size.y * ART_SHARE)
	return Rect2(Vector2((size.x - extent) * 0.5, 0), Vector2.ONE * extent)


# Only the island and its name take the pointer, so neighbouring stages,
# whose squares overlap, never take each other's clicks.
func _has_point(point: Vector2) -> bool:
	var art := art_rect()
	var middle := art.get_center()
	var reach := (point - middle) / (art.size * Vector2(0.46, 0.42))
	return reach.length() <= 1.0 or (point.y > art.end.y - art.size.y * 0.06 and point.y < size.y and absf(point.x - middle.x) < art.size.x * 0.3)


# Where the island's foot rests, which the map's road reaches.
func foot() -> Vector2:
	var art := art_rect()
	return art.position + Vector2(art.size.x * 0.5, art.size.y * 0.86)


func _draw() -> void:
	if stage == null:
		return
	var art := art_rect()
	var base := foot()
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
	var chosen := button_pressed
	# A soft shadow on the ground, an ellipse wider than tall.
	var shadow := Rect2(base - Vector2(art.size.x * 0.4, art.size.y * 0.07), Vector2(art.size.x * 0.8, art.size.y * 0.14))
	draw_texture_rect(_glow, shadow, false, get_theme_color(&"shadow"))
	if chosen:
		var band := get_theme_color(&"band", &"HubLobby")
		draw_texture_rect(_glow, Rect2(base - Vector2(art.size.x * 0.62, art.size.y * 0.5), Vector2(art.size.x * 1.24, art.size.y * 0.7)), false, Color(band, band.a * 5.0))
	# The chosen island floats; whole pixels keep the painting crisp.
	var lift := roundf((sin(_phase * TAU) * 0.5 + 0.5) * UIMotion.IDLE_RISE * 2.0) if chosen else 0.0
	var tone := get_theme_color(&"locked") if not unlocked else (Color.WHITE if chosen or is_hovered() else get_theme_color(&"resting"))
	var picture: Texture2D = stage.diorama if stage.diorama != null else stage.illustration
	if picture != null:
		draw_texture_rect(picture, Rect2(art.position - Vector2(0, lift), art.size), false, tone)
	# Focus on a stage that is not the chosen one (the mouse chose another)
	# shows as a thin ring on the ground.
	if has_focus() and not chosen:
		var ring := PackedVector2Array()
		for step in 65:
			var angle := TAU * step / 64.0
			ring.append(base + Vector2(cos(angle) * art.size.x * 0.4, sin(angle) * art.size.y * 0.08))
		draw_polyline(ring, get_theme_color(&"focus_ring"), 1.5, true)
	var font := get_theme_font(&"font")
	var name_size := get_theme_font_size(&"font_size")
	var note_size := get_theme_font_size(&"note_font_size")
	var top := art.end.y + font.get_ascent(name_size) - art.size.y * 0.04
	var name_tone := get_theme_color(&"font_color", &"GoldLabel") if chosen else get_theme_color(&"font_color", &"Label" if unlocked else &"MutedLabel")
	draw_string(font, Vector2(0, top), stage.display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, name_size, name_tone)
	var note := "全%d階　%s" % [stage.floor_count, stage.difficulty] if unlocked else (hint if not hint.is_empty() else "まだ道は開いていない")
	if not stage.available:
		note = "まだ道は開いていない"
	draw_string(font, Vector2(0, top + font.get_descent(name_size) + font.get_ascent(note_size) + 4.0), note, HORIZONTAL_ALIGNMENT_CENTER, size.x, note_size, get_theme_color(&"font_color", &"MutedLabel"))
