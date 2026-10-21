class_name ChoicePrompt
extends CanvasLayer

# A yes-or-no question, as games commonly ask one: a framed window in the
# middle of the screen over a dimmed backdrop that stops every click behind
# it, with its subject, the question, what follows from it, and two buttons
# (going back on the left, going ahead on the right). A question whose
# answer cannot be undone (ending the game, leaving the run) marks the way
# ahead in red and waits on the way back, so a second Enter never confirms
# it; any other waits on the way ahead. Esc (B) goes back.

signal confirmed
signal canceled

const SHADE := Color(0.01, 0.015, 0.025, 0.66)
const WIDTH := 600.0
const BUTTON_WIDTH := 220.0

var panel: PanelContainer
var caption_label: Label
var title_label: Label
var body_label: Label
var accept_button: Button
var cancel_button: Button
var key_guide: KeyGuide


func _ready() -> void:
	layer = 11
	var root := Control.new()
	root.theme = preload("res://ui/theme/dungeon_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"MainPanel"
	panel.custom_minimum_size.x = WIDTH
	center.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"DetailStack"
	margin.add_child(column)
	caption_label = _centered(column, &"MutedLabel")
	title_label = _centered(column, &"TitleLabel")
	HubUI.rule(column)
	body_label = HubUI.label(column, "", &"DescriptionLabel")
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	column.add_child(gap)
	var actions := HBoxContainer.new()
	actions.theme_type_variation = &"ListRow"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)
	cancel_button = HubUI.button(actions, "", func(): canceled.emit())
	accept_button = HubUI.button(actions, "", func(): confirmed.emit(), &"PrimaryButton")
	for button: Button in [cancel_button, accept_button]:
		button.custom_minimum_size = Vector2(BUTTON_WIDTH, HubUI.PRIMARY_ACTION_HEIGHT)
		button.focus_neighbor_left = cancel_button.get_path()
		button.focus_neighbor_right = accept_button.get_path()
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	# Keys show as caps under the buttons instead of "(Esc)" in their labels.
	key_guide = KeyGuide.new()
	key_guide.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(key_guide)
	key_guide.add_hint("← / →", "◀ / ▶", "選ぶ")
	key_guide.add_hint("Enter", "A", "決定")
	key_guide.add_hint("Esc", "B", "戻る")
	UIMotion.bind_buttons(actions)
	hide()


func _centered(parent: Node, role: StringName) -> Label:
	var label := HubUI.label(parent, "", role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


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
	accept_button.theme_type_variation = &"DangerButton" if danger else &"PrimaryButton"
	show()
	UIMotion.of(panel).appear(0.0, UIMotion.WINDOW_TIME)
	(cancel_button if danger else accept_button).grab_focus()


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
