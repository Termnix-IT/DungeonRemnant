class_name HubUI
extends RefCounted

# Structure only: appearance and spacing are owned by dungeon_theme.tres.
const PRIMARY_ACTION_HEIGHT := 60.0
static func columns(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return row


static func section(parent: Node, ratio: float = 1.0, role: StringName = &"MainPanel") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = role
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	parent.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	return stack


static func label(parent: Node, text: String, role: StringName = &"BodyLabel") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = role
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func button(parent: Node, text: String, action: Callable, role: StringName = &"SecondaryButton") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = role
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


# The screen's one primary action (docs/MVP_SPEC.md, 個別画面のUI文法): the
# same plate as the lobby's decide button, full width at the foot of the
# right panel. Other actions are SecondaryButton above it.
static func primary_action(parent: Node, text: String, action: Callable) -> Button:
	var button := button(parent, text, action, &"PrimaryAction")
	button.custom_minimum_size.y = PRIMARY_ACTION_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


# A column laid on the hall without a framed box: a dark slab whose right
# edge melts into the background, like the lobby menu (SlabColumn), or only
# a soft shade behind the text (ShadeColumn).
static func open_column(parent: Node, ratio: float, role: StringName) -> VBoxContainer:
	var column := PanelContainer.new()
	column.theme_type_variation = role
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = ratio
	parent.add_child(column)
	var stack := VBoxContainer.new()
	column.add_child(stack)
	return stack


# A gilt hairline fading at both ends with a diamond in the middle, to part
# what a box used to.
static func rule(parent: Node) -> Control:
	var rule := Control.new()
	rule.custom_minimum_size.y = 12
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func():
		var rail := rule.get_theme_color(&"rail", &"HubLobby")
		var y := rule.size.y * 0.5
		var w := rule.size.x
		rule.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.55), Color(rail, 0.0)]), 1.0, true)
		var c := Vector2(w * 0.5, y)
		rule.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), Color(rail, 0.85)))
	parent.add_child(rule)
	return rule


static func space(parent: Node) -> Control:
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(space)
	return space
