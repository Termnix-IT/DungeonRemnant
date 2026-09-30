class_name BossCutIn
extends CanvasLayer

# The moment a floor's boss first comes into view: a dark band across the
# upper screen, the boss's idle frames sliding in from the left and its name
# from the right, then the whole band fades. It never takes input and the turn
# never waits for it, so the player may act while it plays.
const HOLD_TIME := 1.35
const FADE_TIME := 0.3
const BAND_TOP := 104.0
const BAND_HEIGHT := 188.0
# Boss strips are 176px frames; 1.5x lets the body rise above the band.
const SPRITE_SCALE := 1.5
const IDLE_FPS := 6.0
const SLIDE := 72.0

var root: Control
var band: PanelContainer
# Holders take the layout; the portrait and text inside them only move for
# the motion, so UIMotion's rest position stays (0, 0) at any window size.
var portrait_holder: Control
var text_holder: Control
var portrait: Control
var text: VBoxContainer
var caption_label: Label
var name_label: Label
var sheet: Texture2D
var lifetime: Timer
var _frame_clock := 0.0


func _ready() -> void:
	layer = 7
	root = Control.new()
	root.name = "CutIn"
	root.theme = preload("res://ui/theme/dungeon_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band = PanelContainer.new()
	band.theme_type_variation = &"BossBand"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.offset_top = BAND_TOP
	band.offset_bottom = BAND_TOP + BAND_HEIGHT
	portrait_holder = _holder()
	portrait = Control.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.draw.connect(_draw_portrait)
	portrait_holder.add_child(portrait)
	text_holder = _holder()
	text = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text_holder.add_child(text)
	caption_label = HubUI.label(text, "", &"MutedLabel")
	name_label = HubUI.label(text, "", &"BossCutInTitle")
	for label: Label in [caption_label, name_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lifetime = Timer.new()
	lifetime.one_shot = true
	lifetime.timeout.connect(_fade)
	add_child(lifetime)
	root.resized.connect(_layout)
	_layout()
	clear()


func present(stats: EnemyStats, caption: String) -> void:
	# A second boss replaces the first at once; the old fade never finishes.
	clear()
	sheet = EnemySprites.sheet_for(stats)
	caption_label.text = caption
	name_label.text = stats.display_name
	_frame_clock = 0.0
	_layout()
	show()
	portrait.visible = sheet != null
	UIMotion.of(band).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(portrait).enter(0.0, Vector2(-SLIDE, 0))
	UIMotion.of(text).enter(UIMotion.STAGGER_TIME, Vector2(SLIDE, 0))
	UIMotion.of(name_label).pulse(1.04, UIMotion.GOLD_TIME)
	lifetime.start(HOLD_TIME)
	set_process(true)


func clear() -> void:
	lifetime.stop()
	set_process(false)
	for control: Control in [root, band, portrait, text, name_label]:
		UIMotion.of(control).reset()
	root.modulate.a = 1.0
	hide()


func _fade() -> void:
	UIMotion.of(root).fade_out(0.0, FADE_TIME).finished.connect(clear)


func _process(delta: float) -> void:
	_frame_clock += delta
	portrait.queue_redraw()


# The portrait stands on the band's lower edge left of centre, facing the name.
func _layout() -> void:
	if root == null:
		return
	var center := root.size.x / 2.0
	var side := 176.0 * SPRITE_SCALE
	portrait_holder.position = Vector2(center - 70.0 - side, BAND_TOP + BAND_HEIGHT - side)
	portrait_holder.size = Vector2.ONE * side
	portrait.size = portrait_holder.size
	# Without a strip (the shared drawn boss) the name stands centred alone.
	var width := minf(560.0, root.size.x - center + 24.0)
	text_holder.position = Vector2(center - 40.0 if sheet != null else center - width / 2.0, BAND_TOP)
	text_holder.size = Vector2(width, BAND_HEIGHT)
	text.size = text_holder.size
	for label: Label in [caption_label, name_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if sheet != null else HORIZONTAL_ALIGNMENT_CENTER


func _holder() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	return holder


func _draw_portrait() -> void:
	if sheet == null:
		return
	var frame := float(sheet.get_height())
	var index := int(_frame_clock * IDLE_FPS) % mini(EnemySprites.IDLE_FRAMES, EnemySprites.frame_count(sheet))
	portrait.draw_texture_rect_region(sheet, Rect2(Vector2.ZERO, portrait.size), Rect2(index * frame, 0, frame, frame))
