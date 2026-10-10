class_name ChoicePrompt
extends CanvasLayer

# In-world yes/no prompt for stairs and exits. It sits in the lower third so
# the hero and the surrounding room stay readable while the player decides.
# A painted picture of the passage it asks about (the theme's ChoicePrompt
# icons: stairs, guardian, exit) stands beside the words.
signal confirmed
signal canceled

var panel: PanelContainer
var caption_label: Label
var title_label: Label
var body_label: Label
var emblem: TextureRect
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
	shade.color = Color(0.01, 0.02, 0.04, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Containers place the panel: centred, lifted clear of the log panel.
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	HubUI.space(layout)
	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(row)
	var clearance := Control.new()
	clearance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clearance.custom_minimum_size.y = 140
	layout.add_child(clearance)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"MainPanel"
	panel.custom_minimum_size.x = 540
	row.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"DetailStack"
	margin.add_child(column)
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"DetailStack"
	column.add_child(heading)
	emblem = TextureRect.new()
	emblem.custom_minimum_size = Vector2(96, 96)
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(emblem)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_child(words)
	caption_label = HubUI.label(words, "", &"MutedLabel")
	title_label = HubUI.label(words, "", &"TitleLabel")
	body_label = HubUI.label(column, "", &"DescriptionLabel")
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	cancel_button = HubUI.button(actions, "", func(): canceled.emit())
	cancel_button.custom_minimum_size.x = 180
	accept_button = HubUI.button(actions, "", func(): confirmed.emit(), &"PrimaryButton")
	accept_button.custom_minimum_size.x = 200
	for button: Button in [cancel_button, accept_button]:
		button.focus_neighbor_left = cancel_button.get_path()
		button.focus_neighbor_right = accept_button.get_path()
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	# Keys show as caps under the buttons instead of "(Esc)" in their labels.
	key_guide = KeyGuide.new()
	key_guide.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(key_guide)
	key_guide.add_hint("Enter", "A", "決定")
	key_guide.add_hint("Esc", "B", "戻る")
	UIMotion.bind_buttons(actions)
	hide()


func ask(caption: String, title: String, body: String, accept_text: String, cancel_text: String, passage: StringName = &"") -> void:
	emblem.texture = emblem.get_theme_icon(passage, &"ChoicePrompt") if not passage.is_empty() else null
	emblem.visible = emblem.texture != null
	caption_label.text = caption
	caption_label.visible = not caption.is_empty()
	title_label.text = title
	body_label.text = body
	accept_button.text = accept_text
	cancel_button.text = cancel_text
	show()
	UIMotion.of(panel).appear(0.0, UIMotion.WINDOW_TIME)
	accept_button.grab_focus()


# Escape and the gamepad cancel button decline, matching the old dialog.
func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	# Standalone runs (rule captures) have no gameplay bindings registered.
	var cancel := InputMap.has_action("cancel_attack") and event.is_action_pressed("cancel_attack")
	if cancel or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
