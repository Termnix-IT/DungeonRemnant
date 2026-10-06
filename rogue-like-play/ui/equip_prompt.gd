class_name EquipPrompt
extends CanvasLayer

# The question before gear is worn, put as a picture: what the slot holds now
# on the left, the gear on the right large and lit, an arrow between, and
# under them how each of her stats would move. Accepting wears it; Esc or the
# cancel button declines. Appearance belongs to the shared Theme.

signal confirmed
signal canceled

const BIG_CELL := 136.0
const BIG_ICON := 96.0

var panel: PanelContainer
var caption_label: Label
var title_label: Label
var kind_label: Label
var note_label: Label
var stat_box: VBoxContainer
var from_cell: ItemCell
var to_cell: ItemCell
var accept_button: Button
var cancel_button: Button


func _ready() -> void:
	layer = 11
	var root := Control.new()
	root.theme = preload("res://ui/theme/dungeon_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.01, 0.02, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"PromptPanel"
	panel.custom_minimum_size.x = 900
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"DetailStack"
	panel.add_child(column)
	caption_label = HubUI.label(column, "", &"SectionLabel")
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Now, an arrow, then the gear.
	var pictures := HBoxContainer.new()
	pictures.alignment = BoxContainer.ALIGNMENT_CENTER
	pictures.theme_type_variation = &"PromptPictures"
	column.add_child(pictures)
	from_cell = _display_cell(pictures)
	var arrow := HubUI.label(pictures, "▶", &"PromptArrow")
	arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	to_cell = _display_cell(pictures)
	to_cell.set_pressed_no_signal(true)
	title_label = HubUI.label(column, "", &"TitleLabel")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_label = HubUI.label(column, "", &"PlaqueNote")
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(column)
	stat_box = VBoxContainer.new()
	stat_box.theme_type_variation = &"CompactStack"
	column.add_child(stat_box)
	note_label = HubUI.label(column, "", &"NoteLabel")
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)
	cancel_button = HubUI.button(actions, "", func(): canceled.emit())
	cancel_button.custom_minimum_size.x = 200
	accept_button = HubUI.button(actions, "", func(): confirmed.emit(), &"PrimaryButton")
	accept_button.custom_minimum_size.x = 240
	for button: Button in [cancel_button, accept_button]:
		button.focus_neighbor_left = cancel_button.get_path()
		button.focus_neighbor_right = accept_button.get_path()
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	UIMotion.bind_buttons(actions)
	hide()


# A cell that only shows: it takes no pointer and no focus.
func _display_cell(parent: Control) -> ItemCell:
	var cell := ItemCell.new()
	cell.theme_type_variation = &"SlotCell"
	cell.custom_minimum_size = Vector2.ONE * BIG_CELL
	cell.icon_size = BIG_ICON
	cell.draggable = false
	cell.focus_mode = Control.FOCUS_NONE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cell)
	return cell


# current is what the slot holds (null when empty; symbol then stands in for
# the slot), item the gear; changes are [caption, before, after] rows.
func ask(caption: String, current: ItemData, symbol: ItemData, item: ItemData, changes: Array, note: String, title: String, accept_text: String, cancel_text: String) -> void:
	caption_label.text = caption
	from_cell.symbol = symbol
	from_cell.show_item(current)
	to_cell.show_item(item)
	title_label.text = title
	kind_label.text = "%s　◆　%s" % [ItemGlyph.category(item), ItemGlyph.main_effect(item)]
	for row in stat_box.get_children():
		stat_box.remove_child(row)
		row.queue_free()
	for change: Array in changes:
		_stat_row(change[0], change[1], change[2])
	note_label.text = note
	note_label.visible = not note.is_empty()
	accept_button.text = accept_text
	cancel_button.text = cancel_text
	show()
	UIMotion.of(panel).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(to_cell).pulse(1.12, UIMotion.GOLD_TIME)
	accept_button.grab_focus()


func _stat_row(caption: String, before: int, after: int) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"PromptStat"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_box.add_child(row)
	var name_label := HubUI.label(row, caption, &"BodyLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.custom_minimum_size.x = 150
	var from_label := HubUI.label(row, str(before), &"MutedLabel")
	from_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	from_label.custom_minimum_size.x = 60
	from_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var arrow := HubUI.label(row, "→", &"MutedLabel")
	arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	var to_label := HubUI.label(row, str(after), &"ValueLabel")
	to_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	to_label.custom_minimum_size.x = 70
	var delta := after - before
	var change := HubUI.label(row, "▲ +%d" % delta if delta > 0 else "▼ %d" % delta, &"PositiveLabel" if delta > 0 else &"NegativeLabel")
	change.autowrap_mode = TextServer.AUTOWRAP_OFF


# Escape and the gamepad cancel button decline.
func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	var cancel := InputMap.has_action("cancel_attack") and event.is_action_pressed("cancel_attack")
	if cancel or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
