class_name HubTheme
extends RefCounted

const GOLD := Color("e5bd75")
const INK := Color("101519")
const MUTED := Color("b8b0a1")


static func box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", Color("f1e9da"))
	theme.set_stylebox("panel", "Panel", box(Color(0.045, 0.055, 0.065, 0.94), Color("79684d")))
	theme.set_stylebox("panel", "PanelContainer", box(Color(0.045, 0.055, 0.065, 0.94), Color("79684d")))
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, box(Color(0.065, 0.073, 0.08, 0.96), Color("8b7755")))
		theme.set_stylebox("hover", type, box(Color("302b20"), GOLD, 2))
		theme.set_stylebox("pressed", type, box(Color("443822"), GOLD, 2))
		theme.set_stylebox("disabled", type, box(Color("14181b"), Color("424242")))
		theme.set_stylebox("focus", type, box(Color(0, 0, 0, 0), GOLD, 2))
		theme.set_color("font_color", type, Color("f1e9da"))
		theme.set_color("font_disabled_color", type, Color("77766f"))
	theme.set_stylebox("panel", "ItemList", box(Color("11171b"), Color("79684d")))
	theme.set_stylebox("selected", "ItemList", box(Color("3b3222"), GOLD))
	theme.set_stylebox("selected_focus", "ItemList", box(Color("3b3222"), GOLD, 2))
	theme.set_stylebox("focus", "ItemList", box(Color(0, 0, 0, 0), GOLD))
	theme.set_color("font_color", "ItemList", Color("f1e9da"))
	theme.set_constant("v_separation", "ItemList", 16)
	return theme


static func place(control: Control, parent: Node, position: Vector2, extent: Vector2) -> void:
	parent.add_child(control)
	control.position = position
	control.size = extent


static func label(parent: Node, text: String, position: Vector2, extent: Vector2, font_size: int = 19) -> Label:
	var control := Label.new()
	control.text = text
	control.add_theme_font_size_override("font_size", font_size)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(control, parent, position, extent)
	return control


static func button(parent: Node, text: String, position: Vector2, extent: Vector2, action: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.pressed.connect(action)
	place(control, parent, position, extent)
	return control


static func panel(parent: Node, position: Vector2, extent: Vector2) -> Panel:
	var control := Panel.new()
	place(control, parent, position, extent)
	return control


static func equipment_text(state: RunCarryover) -> String:
	var lines := PackedStringArray()
	for index in state.equipment.slots.size():
		var item := state.equipment.slots[index]
		lines.append("%s： %s" % [Equipment.SLOT_NAMES[index], item.label() if item != null else "なし"])
	return "\n\n".join(lines)


static func fill_inventory(list: ItemList, inventory: Inventory) -> void:
	list.clear()
	for entry in inventory.entries:
		list.add_item("%s  ×%d" % [entry.item.label(), entry.count])
		list.set_item_tooltip(list.item_count - 1, entry.item.description())
