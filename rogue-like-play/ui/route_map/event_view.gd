class_name EventView
extends CanvasLayer

# A stop without a fight, told as games tell an event: over the dimmed map,
# a quiet window with its emblem and its name, what kind of place it is
# (muted), what happens there, what she has to pay with (echo, health, the
# curses she carries), and its choices as rows, each saying what it costs,
# offered but off when it cannot be taken, the reason written at the row's
# right end, so it reads the same with a mouse, the keys or a gamepad.
# Leaving is the last row, and Esc (B); the keys stand under the rows, as in
# the other windows. It only tells; RunDirector plays the choice.

signal chosen(id: StringName)

const LEAVE := &"leave"
const SHADE := Color(0.01, 0.015, 0.025, 0.66)
const WIDTH := 640.0
const EMBLEM_SIZE := 96.0
# A row's reason stands this far in from its right end.
const REASON_INSET := 16.0

var panel: PanelContainer
var title_label: Label
var flavor_label: Label
var body_label: Label
var state_label: Label
var buttons: Array[Button] = []
# Each row's reason for being off (null for a row that can be taken).
var reasons: Array[Label] = []
var key_guide: KeyGuide
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
	flavor_label = _centered(stack, &"MutedLabel")
	body_label = _centered(stack, &"BodyLabel")
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label = _centered(stack, &"BodyLabel")
	HubUI.rule(stack)
	_rows = VBoxContainer.new()
	_rows.theme_type_variation = &"DetailStack"
	stack.add_child(_rows)
	key_guide = KeyGuide.new()
	key_guide.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(key_guide)
	key_guide.add_hint("↑ / ↓", "▲ / ▼", tr("選ぶ"))
	key_guide.add_hint("Enter", "A", tr("決定"))
	key_guide.add_hint("Esc", "B", tr("立ち去る"), func(): chosen.emit(LEAVE))
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
	title_label.text = tr(area.display_name)
	flavor_label.text = tr(area.foe_summary)
	body_label.text = tr(area.condition) if terms.is_empty() else "%s\n%s" % [tr(area.condition), terms]
	state_label.text = state
	# Its rows are made anew; the one pressed may still be sending its signal.
	for button in buttons:
		_rows.remove_child(button)
		button.queue_free()
	buttons.clear()
	reasons.clear()
	ids.clear()
	for option: Dictionary in options:
		_row(option.id, option.text, option.get("enabled", true), option.get("reason", ""))
	_row(LEAVE, tr("立ち去る"), true, "")
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
	# Why it is off, at the row's right end (a tooltip would show to the
	# mouse alone).
	var why: Label = null
	if not enabled and not reason.is_empty():
		why = HubUI.label(button, reason, &"NegativeLabel")
		why.autowrap_mode = TextServer.AUTOWRAP_OFF
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		why.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		why.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		why.offset_right = -REASON_INSET
	reasons.append(why)
	buttons.append(button)
	ids.append(id)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		chosen.emit(LEAVE)
