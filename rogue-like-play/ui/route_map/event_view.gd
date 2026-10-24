class_name EventView
extends CanvasLayer

# A stop without a fight, told as games tell an event: over the dimmed map,
# a quiet window with its emblem, what kind of stop it is and its name, what
# happens there, what she has to pay with (echo, health, the curses she
# carries), and its choices as rows, each saying what it costs, offered but
# off (with the reason as a tooltip) when it cannot be taken. Leaving is the
# last row, and Esc (B). It only tells; RunDirector plays the choice.

signal chosen(id: StringName)

const LEAVE := &"leave"
const SHADE := Color(0.01, 0.015, 0.025, 0.66)
const WIDTH := 640.0
const EMBLEM_SIZE := 96.0

var panel: PanelContainer
var title_label: Label
var body_label: Label
var state_label: Label
var buttons: Array[Button] = []
var ids: Array[StringName] = []
var _emblem: TextureRect
var _rows: VBoxContainer


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"QuietWindow"
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"DetailStack"
	margin.add_child(stack)
	_emblem = TextureRect.new()
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.custom_minimum_size = Vector2.ONE * EMBLEM_SIZE
	_emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stack.add_child(_emblem)
	title_label = _centered(stack, &"TitleLabel")
	body_label = _centered(stack, &"BodyLabel")
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label = _centered(stack, &"MutedLabel")
	HubUI.rule(stack)
	_rows = VBoxContainer.new()
	_rows.theme_type_variation = &"DetailStack"
	stack.add_child(_rows)
	hide()


func _centered(parent: Node, role: StringName) -> Label:
	var label := HubUI.label(parent, "", role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


# `options`: [{id, text, enabled, reason}], leaving added last; `terms`:
# what this stop's bargain holds, under what it does.
func present(area: AreaData, state: String, options: Array, terms: String = "") -> void:
	_emblem.texture = EmblemIcons.texture(area.emblem)
	title_label.text = area.display_name
	body_label.text = "%s\n%s" % [area.foe_summary, area.condition]
	if not terms.is_empty():
		body_label.text += "\n" + terms
	state_label.text = state
	# Its rows are made anew; the one pressed may still be sending its signal.
	for button in buttons:
		_rows.remove_child(button)
		button.queue_free()
	buttons.clear()
	ids.clear()
	for option: Dictionary in options:
		_row(option.id, option.text, option.get("enabled", true), option.get("reason", ""))
	_row(LEAVE, "立ち去る", true, "")
	for index in buttons.size():
		buttons[index].focus_neighbor_top = buttons[posmod(index - 1, buttons.size())].get_path()
		buttons[index].focus_neighbor_bottom = buttons[posmod(index + 1, buttons.size())].get_path()
	var was_shown := visible
	show()
	UIMotion.bind_buttons(_rows)
	if not was_shown:
		UIMotion.of(panel).appear(0.0, UIMotion.WINDOW_TIME)
	for button in buttons:
		if not button.disabled:
			button.grab_focus()
			break


func _row(id: StringName, text: String, enabled: bool, reason: String) -> void:
	var button := HubUI.button(_rows, text, func(): chosen.emit(id))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = not enabled
	button.tooltip_text = reason if not enabled else ""
	buttons.append(button)
	ids.append(id)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		chosen.emit(LEAVE)
