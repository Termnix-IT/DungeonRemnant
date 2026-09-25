class_name SceneTransition
extends CanvasLayer

# Cover-and-reveal only. Callers switch scenes and settle state first, then
# play; the cover never receives input and nothing waits for it to finish.
const HOLD_TIME := 0.45
const REVEAL_TIME := 0.35
# The heading leaves just before the cover so it never overlaps the scene.
const HEADING_EXIT_LEAD := 0.1

var root: Control
var heading: Control
var column: VBoxContainer
var art: TextureRect
var title: Label
var subtitle: Label


func _ready() -> void:
	layer = 60
	root = Control.new()
	root.theme = preload("res://ui/theme/dungeon_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0.01, 0.012, 0.016, 1)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading = center
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(560, 190)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art)
	title = HubUI.label(column, "", &"VictoryTitle")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = HubUI.label(column, "", &"MutedLabel")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide()


func play_departure(stage: StageData, entry_floor: int) -> void:
	art.texture = stage.illustration
	art.visible = art.texture != null
	title.text = stage.display_name
	var floors := "全%d階" % stage.floor_count
	subtitle.text = floors if entry_floor <= 1 else "%dFから  ·  %s" % [entry_floor, floors]
	_play()


func play_return(heading: String, detail: String = "") -> void:
	art.texture = null
	art.visible = false
	title.text = heading
	subtitle.text = detail
	_play()


func _play() -> void:
	clear()
	subtitle.visible = not subtitle.text.is_empty()
	show()
	UIMotion.of(column).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(heading).fade_out(HOLD_TIME - HEADING_EXIT_LEAD, UIMotion.WINDOW_TIME)
	UIMotion.of(root).fade_out(HOLD_TIME, REVEAL_TIME).finished.connect(clear)


func clear() -> void:
	# Hiding the layer resets every UIMotion under it to its base state.
	hide()
