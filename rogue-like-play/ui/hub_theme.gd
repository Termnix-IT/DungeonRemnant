class_name HubTheme
extends RefCounted


static func create() -> Theme:
	return preload("res://ui/theme/dungeon_theme.tres")


static func place(control: Control, parent: Node, position: Vector2, extent: Vector2) -> void:
	parent.add_child(control)
	control.position = position
	control.size = extent


static func label(parent: Node, text: String, position: Vector2, extent: Vector2, role: StringName = &"BodyLabel") -> Label:
	var control := Label.new()
	control.text = text
	control.theme_type_variation = role
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(control, parent, position, extent)
	return control


static func button(parent: Node, text: String, position: Vector2, extent: Vector2, action: Callable, role: StringName = &"PrimaryButton") -> Button:
	var control := Button.new()
	control.theme_type_variation = role
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
		list.set_item_tooltip(list.item_count - 1, ItemTooltipList.description(entry.item))
