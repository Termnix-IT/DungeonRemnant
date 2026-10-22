class_name SpecialCutIn
extends CanvasLayer

# A special move's cut-in, staged as action games stage one while the world
# all but stops (the area holds it for total_time): a dark band opens across
# the middle of the screen with light racing through it, her portrait slides
# in from the left and the move's name from the right under a gold "必殺技",
# and the band closes again. It never takes input, runs on the real clock,
# and frees itself when done.

const PORTRAIT := preload("res://art/characters/mio_lobby.png")
# The part of the lobby illustration shown: her face and shoulders.
const PORTRAIT_REGION := Rect2(150, 70, 560, 380)
const BAND_HEIGHT := 230.0
const EDGE_WIDTH := 3.0
# Her portrait fades into the band over this share of its width at each side.
const PORTRAIT_FADE := 0.22
# Where her portrait and the name come to rest, as shares of the width.
const PORTRAIT_PLACE := 0.14
const NAME_PLACE := 0.52
const OPEN_TIME := 0.1
const SLIDE_TIME := 0.2
const HOLD_TIME := 0.34
const CLOSE_TIME := 0.16
# The light racing through the band: how many streaks and how fast (px a second).
const STREAKS := 16
const STREAK_SPEED := 2600.0

var band: Control
var portrait: TextureRect
var caption: Label
var name_label: Label
var _started := 0


static func total_time() -> float:
	return OPEN_TIME + SLIDE_TIME + HOLD_TIME + CLOSE_TIME


func present(move: SpecialData) -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started = Time.get_ticks_msec()
	var root := Control.new()
	root.theme = HubTheme.create()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen := root.get_viewport_rect().size
	band = Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.clip_contents = true
	band.position = Vector2(0.0, (screen.y - BAND_HEIGHT) * 0.5)
	band.size = Vector2(screen.x, BAND_HEIGHT)
	band.pivot_offset = band.size * 0.5
	band.scale.y = 0.0
	band.draw.connect(_draw_band)
	root.add_child(band)
	var region := AtlasTexture.new()
	region.atlas = PORTRAIT
	region.region = PORTRAIT_REGION
	portrait = TextureRect.new()
	portrait.texture = region
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.size = Vector2(BAND_HEIGHT * PORTRAIT_REGION.size.aspect(), BAND_HEIGHT)
	portrait.position.x = -portrait.size.x
	portrait.draw.connect(_fade_portrait)
	band.add_child(portrait)
	caption = _label(band, "必殺技", &"SpecialCaption")
	name_label = _label(band, move.display_name, &"SpecialName")
	# The gold edges over everything in the band, her portrait too.
	var edges := Control.new()
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edges.size = band.size
	edges.draw.connect(_draw_edges.bind(edges))
	band.add_child(edges)
	var name_size := name_label.get_combined_minimum_size()
	var caption_size := caption.get_combined_minimum_size()
	var top := (BAND_HEIGHT - name_size.y - caption_size.y) * 0.5
	caption.position = Vector2(screen.x, top)
	name_label.position = Vector2(screen.x + 60.0, top + caption_size.y)
	var stage := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	stage.tween_property(band, "scale:y", 1.0, OPEN_TIME)
	stage.tween_property(portrait, "position:x", screen.x * PORTRAIT_PLACE, SLIDE_TIME)
	stage.parallel().tween_property(caption, "position:x", screen.x * NAME_PLACE, SLIDE_TIME)
	stage.parallel().tween_property(name_label, "position:x", screen.x * NAME_PLACE, SLIDE_TIME)
	stage.tween_interval(HOLD_TIME)
	stage.tween_property(band, "scale:y", 0.0, CLOSE_TIME).set_ease(Tween.EASE_IN)
	stage.parallel().tween_property(band, "modulate:a", 0.0, CLOSE_TIME)
	stage.tween_callback(queue_free)


func _label(parent: Control, text: String, role: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.size = label.get_combined_minimum_size()
	return label


# The portrait's sides melt into the band, so no hard edge cuts the picture.
func _fade_portrait() -> void:
	var color := band.get_theme_color(&"band", &"SpecialCutIn")
	var clear := Color(color, 0.0)
	var extent := portrait.size
	var fade := extent.x * PORTRAIT_FADE
	portrait.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(fade, 0.0), Vector2(fade, extent.y), Vector2(0.0, extent.y)]), PackedColorArray([color, clear, clear, color]))
	portrait.draw_polygon(PackedVector2Array([Vector2(extent.x - fade, 0.0), Vector2(extent.x, 0.0), extent, Vector2(extent.x - fade, extent.y)]), PackedColorArray([clear, color, color, clear]))


func _process(_delta: float) -> void:
	if band != null:
		band.queue_redraw()


func _draw_band() -> void:
	var extent := band.size
	band.draw_rect(Rect2(Vector2.ZERO, extent), band.get_theme_color(&"band", &"SpecialCutIn"))
	# Streaks of light racing right to left, each at its own height and pace.
	var streak := band.get_theme_color(&"streak", &"SpecialCutIn")
	var elapsed := (Time.get_ticks_msec() - _started) / 1000.0
	for index in STREAKS:
		var y := extent.y * fposmod(index * 0.618, 1.0)
		var length := 120.0 + 260.0 * fposmod(index * 0.37, 1.0)
		var pace := STREAK_SPEED * (0.6 + 0.8 * fposmod(index * 0.29, 1.0))
		var x := fposmod(extent.x - elapsed * pace + index * 211.0, extent.x + length) - length
		band.draw_line(Vector2(x, y), Vector2(x + length, y), streak, 2.0)


func _draw_edges(edges: Control) -> void:
	var edge := band.get_theme_color(&"edge", &"SpecialCutIn")
	edges.draw_rect(Rect2(0.0, 0.0, edges.size.x, EDGE_WIDTH), edge)
	edges.draw_rect(Rect2(0.0, edges.size.y - EDGE_WIDTH, edges.size.x, EDGE_WIDTH), edge)
