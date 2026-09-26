class_name SceneTransition
extends CanvasLayer

# Cover-and-reveal only. Callers switch scenes and settle state first, then
# play; nothing waits for it to finish. While covering, it swallows input so
# the player cannot act on a scene they cannot see yet.
const HOLD_TIME := 0.45
const REVEAL_TIME := 0.35
# The heading leaves just before the cover so it never overlaps the scene.
const HEADING_EXIT_LEAD := 0.1
# Floor changes: the last frame darkens, holds briefly in black, then the new
# floor is revealed. Rules have already moved to the new floor underneath.
const DESCENT_FADE_TIME := 0.22
const DESCENT_HOLD_TIME := 0.34
const DESCENT_REVEAL_DELAY := DESCENT_HOLD_TIME + REVEAL_TIME * 0.5

var root: Control
var still: TextureRect
var veil: ColorRect
var heading: Control
var column: VBoxContainer
var art: TextureRect
var title: Label
var subtitle: Label
var covering := false


func _ready() -> void:
	layer = 60
	root = Control.new()
	root.theme = preload("res://ui/theme/dungeon_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	still = TextureRect.new()
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_SCALE
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(still)
	still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil = ColorRect.new()
	veil.color = Color(0.01, 0.012, 0.016, 1)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


# frame is the last picture of the old floor; without one (headless) the
# cover simply starts black.
func play_descent(frame: Texture2D) -> void:
	art.texture = null
	art.visible = false
	title.text = ""
	subtitle.text = ""
	_play(DESCENT_HOLD_TIME)
	heading.hide()
	still.texture = frame
	still.visible = frame != null
	if still.visible:
		UIMotion.of(veil).appear(0.0, DESCENT_FADE_TIME)
		# Drop the old frame once black, or it ghosts through the reveal.
		UIMotion.of(still).fade_out(DESCENT_FADE_TIME, 0.01)


func _play(hold: float = HOLD_TIME) -> void:
	clear()
	heading.show()
	subtitle.visible = not subtitle.text.is_empty()
	covering = true
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	UIMotion.of(column).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(heading).fade_out(hold - HEADING_EXIT_LEAD, UIMotion.WINDOW_TIME)
	UIMotion.of(root).fade_out(hold, REVEAL_TIME).finished.connect(clear)


func clear() -> void:
	covering = false
	still.texture = null
	still.hide()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hiding the layer resets every UIMotion under it to its base state.
	hide()


# _input runs before GUI and _unhandled_input, so neither Hub buttons nor the
# run's movement see keys pressed while the cover is up.
func _input(event: InputEvent) -> void:
	if covering:
		get_viewport().set_input_as_handled()
