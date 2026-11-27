class_name SceneTransition
extends CanvasLayer

# Cover-and-reveal only. Callers switch scenes and settle state first, then
# play; nothing waits for it to finish. While covering, it swallows input so
# the player cannot act on a scene they cannot see yet.
#
# Setting out (play_departure) is the one cover that is a passage: the
# chapter's painting, as the departure showed it, is gone into toward its
# way in, whose light swells as the dark closes on it from the screen's
# edges (departure.gdshader); in the dark the chapter's number and name
# stand a moment; then the dark opens from the screen's middle on the hall
# of gates, which is told to open at that moment (`arrive`). Enter (A) or a
# click hurries it.
const HOLD_TIME := 0.45
const REVEAL_TIME := 0.35
# The heading leaves just before the cover so it never overlaps the scene.
const HEADING_EXIT_LEAD := 0.1
# Floor changes: the last frame darkens, holds briefly in black, then the new
# floor is revealed. Rules have already moved to the new floor underneath.
const DESCENT_FADE_TIME := 0.22
const DESCENT_HOLD_TIME := 0.34
const DESCENT_REVEAL_DELAY := DESCENT_HOLD_TIME + REVEAL_TIME * 0.5
# Setting out: how long going into the painting takes, how long the name
# stands in the dark, and how long the dark takes to open on the gates.
const PUSH_TIME := 0.95
const NAME_TIME := 0.62
const OPEN_TIME := 0.45
# Within the going in (as shares of it): the hair it first draws back, how
# long the departure's words take to leave, and when the dark begins to close.
const DRAW_BACK := 0.03
const DRAW_BACK_SHARE := 0.24
const WORDS_SHARE := 0.2
const CLOSE_FROM := 0.46
# How close the view comes, and how the name comes and goes in its time.
const PUSH_REACH := 2.7
const NAME_IN := 0.16
const NAME_OUT := 0.18
# How much faster the rest of it runs once hurried.
const HURRY := 4.0
const RULE_WIDTH := 360.0
const STAGE := preload("res://ui/vista/departure.gdshader")
const OPENING := preload("res://ui/route_map/route_curtain.gdshader")

var root: Control
var still: TextureRect
# The painting gone into, as setting out begins.
var stage: ColorRect
var veil: ColorRect
var heading: Control
var column: VBoxContainer
var art: TextureRect
# The chapter's number over its name, on setting out, a star between them.
var kicker: Label
var rule: Control
var title: Label
var subtitle: Label
var covering := false
# Setting out is playing; how far through it is (seconds), and how fast.
var departing := false
var _time := 0.0
var _speed := 1.0
var _arrive := Callable()
var _arrived := false
# The painting set out from had the departure's words over it.
var _worded := false
var _look: ShaderMaterial
var _opening: ShaderMaterial


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
	_look = ShaderMaterial.new()
	_look.shader = STAGE
	_opening = ShaderMaterial.new()
	_opening.shader = OPENING
	stage = ColorRect.new()
	stage.material = _look
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.hide()
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
	kicker = HubUI.label(column, "", &"GoldLabel")
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A star between the chapter's number and its name, a line running out
	# from it either way.
	rule = Control.new()
	rule.custom_minimum_size = Vector2(RULE_WIDTH, 18.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func():
		var gold := rule.get_theme_color(&"font_color", &"GoldLabel")
		var middle := rule.size * 0.5
		HubUI.trail(rule, middle - Vector2(14.0, 0.0), middle - Vector2(RULE_WIDTH * 0.5, 0.0), gold)
		HubUI.trail(rule, middle + Vector2(14.0, 0.0), middle + Vector2(RULE_WIDTH * 0.5, 0.0), gold)
		HubUI.mark(rule, middle, 6.0, gold))
	column.add_child(rule)
	title = HubUI.label(column, "", &"VictoryTitle")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = HubUI.label(column, "", &"MutedLabel")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide()


# Setting out for a chapter. `outlook` is what the departure showed as it
# set out (HubSortie.outlook(): the part of the painting on the screen, its
# way in and that light's colour); without one the painting is taken whole.
# `frame` is the screen's last picture, whose words fade off the painting as
# it begins to move (none headless). `arrive` is called as the dark opens.
func play_departure(chapter: ChapterData, outlook: Dictionary = {}, frame: Texture2D = null, arrive := Callable(), from_dark: bool = false) -> void:
	clear()
	art.texture = null
	art.visible = false
	title.theme_type_variation = &"DepartureTitle"
	kicker.text = Chapters.short_name(chapter)
	kicker.visible = kicker.text != Chapters.title(chapter)
	rule.visible = kicker.visible
	title.text = Chapters.title(chapter)
	subtitle.text = tr("%d層とボス") % chapter.layers
	subtitle.visible = true
	_look.set_shader_parameter(&"place", chapter.illustration)
	_look.set_shader_parameter(&"window", outlook.get(&"window", Vector4(0.0, 0.0, 1.0, 1.0)))
	_look.set_shader_parameter(&"way", outlook.get(&"way", Vector2(0.5, 0.45)))
	_look.set_shader_parameter(&"way_light", outlook.get(&"light", Color(1.0, 0.74, 0.4)))
	_look.set_shader_parameter(&"shade", root.get_theme_color(&"shade", &"Vista"))
	_look.set_shader_parameter(&"night", veil.color)
	_look.set_shader_parameter(&"reach", PUSH_REACH)
	_worded = not outlook.is_empty()
	_arrive = arrive
	_arrived = false
	# Out of a dark screen (the result of a run lost or left), there is no way
	# in to walk: it begins at the chapter's name in the dark.
	_time = PUSH_TIME - 0.001 if from_dark else 0.0
	_speed = 1.0
	departing = true
	covering = true
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.visible = chapter.illustration != null
	veil.visible = not stage.visible
	veil.material = null
	veil.modulate.a = 1.0
	still.texture = frame
	still.visible = frame != null and stage.visible
	still.modulate.a = 1.0
	heading.show()
	heading.modulate.a = 0.0
	show()
	_depart(0.0)
	if not from_dark:
		GameAudio.play(self, &"set_out", -9.0)


# Setting out, on its own clock so it can be hurried: going in, the name in
# the dark, the dark opening.
func _process(delta: float) -> void:
	if departing:
		_depart(delta * _speed)


func _depart(delta: float) -> void:
	var before := _time
	_time += delta
	_look.set_shader_parameter(&"aspect", root.size.aspect() if root.size.y > 0.0 else 1.777)
	if _time < PUSH_TIME:
		var share := _time / PUSH_TIME
		# A hair back, then in, faster and faster.
		_look.set_shader_parameter(&"push", pow(share, 2.6) - DRAW_BACK * sin(clampf(share / DRAW_BACK_SHARE, 0.0, 1.0) * PI))
		_look.set_shader_parameter(&"close", smoothstep(CLOSE_FROM, 1.0, share))
		var words := 1.0 - smoothstep(0.0, WORDS_SHARE, share)
		_look.set_shader_parameter(&"falls", words if _worded else 0.0)
		still.modulate.a = words
		return
	still.hide()
	var named := _time - PUSH_TIME
	if named < NAME_TIME:
		if before < PUSH_TIME:
			_look.set_shader_parameter(&"close", 1.0)
			GameAudio.play(self, &"chapter_toll", -11.0)
		heading.modulate.a = minf(smoothstep(0.0, NAME_IN, named), 1.0 - smoothstep(NAME_TIME - NAME_OUT, NAME_TIME, named))
		return
	# The dark opens from the screen's middle on the hall of gates.
	if not _arrived:
		_arrived = true
		heading.hide()
		stage.hide()
		veil.show()
		veil.material = _opening
		_opening.set_shader_parameter(&"centre", Vector2(0.5, 0.5))
		if _arrive.is_valid():
			_arrive.call()
	_opening.set_shader_parameter(&"extent", root.size)
	var open := (named - NAME_TIME) / OPEN_TIME
	veil.modulate.a = 1.0 - smoothstep(0.0, 1.0, open)
	if open >= 1.0:
		clear()


func play_return(heading: String, detail: String = "") -> void:
	title.theme_type_variation = &"VictoryTitle"
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
	departing = false
	_arrive = Callable()
	stage.hide()
	veil.show()
	veil.material = null
	veil.modulate.a = 1.0
	heading.modulate.a = 1.0
	kicker.hide()
	rule.hide()
	still.modulate.a = 1.0
	still.texture = null
	still.hide()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hiding the layer resets every UIMotion under it to its base state.
	hide()


# _input runs before GUI and _unhandled_input, so neither Hub buttons nor the
# run's movement see keys pressed while the cover is up.
func _input(event: InputEvent) -> void:
	if covering:
		# Setting out can be hurried, not acted through.
		if departing and (event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and event.pressed)):
			_speed = HURRY
		get_viewport().set_input_as_handled()
