class_name ChoicePrompt
extends CanvasLayer

# A yes-or-no question, asked as many action games ask one: the screen dims
# and softly blurs, every click behind it stops, and a low band across the
# whole screen (PromptBand) holds the question, what follows from it, and
# two answers side by side (going back on the left, going ahead on the
# right), with the keys under the band. The band leaves the world it asks
# about in view above and below it, rather than covering it with a window.
# A question whose answer cannot be undone (ending the game, leaving the
# run) marks the way ahead in red and waits on the way back, so a second
# Enter never confirms it; any other waits on the way ahead. Esc (B) goes
# back. The words are the asker's (ask()); the look is this one's.
#
# Answered, it is hidden at once (the asker goes on with what follows, and
# whatever waits on `visible` sees it gone), while what was seen fades out a
# moment longer on a layer of its own (`_view`), taking no input as it goes.

signal confirmed
signal canceled

const SHADE := Color(0.01, 0.012, 0.02, 0.72)
# The blur the shade adds, as the screen texture's mipmap level.
const BLUR := 1.6
const SHADE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 shade : source_color;
uniform float blur = 0.0;
void fragment() {
	vec3 behind = textureLod(screen, SCREEN_UV, blur).rgb;
	COLOR = vec4(mix(behind, shade.rgb, shade.a), 1.0);
}
"""
const CONTENT_WIDTH := 760.0
const BUTTON_WIDTH := 248.0
const BUTTON_HEIGHT := 50.0
const ACTIONS_GAP := 4.0
# The band draws its lines out and its words come up this long.
const OPEN_TIME := 0.26
# What was seen fades out this long once the question is answered.
const CLOSE_TIME := 0.16

var root: Control
var shade: ColorRect
var band: PromptBand
var caption_label: Label
var title_label: Label
var body_label: Label
var accept_button: BandButton
var cancel_button: BandButton
var key_guide: KeyGuide
var _contents: Control
var _open_tween: Tween
# The layer the band is drawn on: a child layer, so it can stay to fade out
# after the question itself is hidden.
var _view: CanvasLayer


func _ready() -> void:
	layer = 11
	root = Control.new()
	root.theme = preload("res://ui/theme/dungeon_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view = CanvasLayer.new()
	_view.layer = layer
	_view.hide()
	add_child(_view)
	_view.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade = ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SHADE_SHADER
	material.set_shader_parameter(&"shade", SHADE)
	shade.material = material
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The band across the screen's middle, the keys just under it.
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"PromptStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band = PromptBand.new()
	stack.add_child(band)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(center)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"PromptColumn"
	column.custom_minimum_size.x = CONTENT_WIDTH
	center.add_child(column)
	_contents = column
	caption_label = _centered(column, &"MutedLabel")
	title_label = _centered(column, &"TitleLabel")
	body_label = HubUI.label(column, "", &"DescriptionLabel")
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.y = ACTIONS_GAP
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var actions := HBoxContainer.new()
	actions.theme_type_variation = &"PromptActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)
	cancel_button = _answer(actions, func(): canceled.emit())
	accept_button = _answer(actions, func(): confirmed.emit())
	for button: Button in [cancel_button, accept_button]:
		button.focus_neighbor_left = cancel_button.get_path()
		button.focus_neighbor_right = accept_button.get_path()
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	# Keys show as caps under the band instead of "(Esc)" in the answers.
	key_guide = KeyGuide.new()
	key_guide.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(key_guide)
	key_guide.add_hint("← / →", "◀ / ▶", tr("選ぶ"))
	key_guide.add_hint("Enter", "A", tr("決定"))
	key_guide.add_hint("Esc", "B", tr("戻る"))
	hide()
	visibility_changed.connect(func():
		if not visible:
			_close())


func _centered(parent: Node, role: StringName) -> Label:
	var label := HubUI.label(parent, "", role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _answer(parent: Node, action: Callable) -> BandButton:
	var button := BandButton.new()
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.pressed.connect(action)
	# The pointer moving over an answer chooses it; one only resting where
	# the band appears chooses nothing by itself.
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length_squared() > 0.0 and not button.has_focus():
			button.grab_focus())
	parent.add_child(button)
	return button


# `danger`: the answer cannot be undone; the way ahead is red and the focus
# waits on the way back.
func ask(caption: String, title: String, body: String, accept_text: String, cancel_text: String, danger: bool = false) -> void:
	caption_label.text = caption
	caption_label.visible = not caption.is_empty()
	title_label.text = title
	body_label.text = body
	body_label.visible = not body.is_empty()
	accept_button.text = accept_text
	cancel_button.text = cancel_text
	accept_button.theme_type_variation = &"BandDangerButton" if danger else &"BandButton"
	# The asker may have set this question's layer after it was made.
	_view.layer = layer
	_view.show()
	_take_input(true)
	show()
	var focused := cancel_button if danger else accept_button
	# The answer waiting for Enter is lit at once; the other is not.
	for button: BandButton in [cancel_button, accept_button]:
		if button.has_focus() and button != focused:
			button.release_focus()
		button.stand = 1.0 if button == focused else 0.0
	focused.grab_focus()
	_open()


# The shade darkens and blurs, the band's lines draw out from its middle and
# its words come up. Nothing waits for it: the answers work at once.
func _open() -> void:
	if _open_tween != null:
		_open_tween.kill()
	var material := shade.material as ShaderMaterial
	shade.modulate.a = 0.0
	material.set_shader_parameter(&"blur", 0.0)
	band.reveal = 0.0
	band.modulate.a = 0.0
	_contents.modulate.a = 0.0
	key_guide.modulate.a = 0.0
	_open_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(shade, "modulate:a", 1.0, UIMotion.WINDOW_TIME)
	_open_tween.tween_method(func(value: float): material.set_shader_parameter(&"blur", value), 0.0, BLUR, OPEN_TIME)
	_open_tween.tween_property(band, "modulate:a", 1.0, UIMotion.WINDOW_TIME)
	_open_tween.tween_property(band, "reveal", 1.0, OPEN_TIME)
	_open_tween.tween_property(_contents, "modulate:a", 1.0, UIMotion.WINDOW_TIME).set_delay(0.06)
	_open_tween.tween_property(key_guide, "modulate:a", 1.0, UIMotion.WINDOW_TIME).set_delay(0.1)


# What was seen fades out: the shade lightens and clears, the band and its
# words go. The answers take no focus or clicks meanwhile, so a second Enter
# or click lands on what follows, not on a fading answer.
func _close() -> void:
	if _view == null or not _view.visible:
		return
	_take_input(false)
	if _open_tween != null:
		_open_tween.kill()
	var material := shade.material as ShaderMaterial
	var blur: float = material.get_shader_parameter(&"blur")
	_open_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_open_tween.tween_property(shade, "modulate:a", 0.0, CLOSE_TIME)
	_open_tween.tween_method(func(value: float): material.set_shader_parameter(&"blur", value), blur, 0.0, CLOSE_TIME)
	for part: Control in [band, _contents, key_guide]:
		_open_tween.tween_property(part, "modulate:a", 0.0, CLOSE_TIME)
	_open_tween.chain().tween_callback(_view.hide)


func _take_input(live: bool) -> void:
	shade.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	for button: BandButton in [cancel_button, accept_button]:
		if not live:
			button.release_focus()
		button.focus_mode = Control.FOCUS_ALL if live else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
