class_name ItemTooltipList
extends ItemList


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null
	var label := Label.new()
	label.theme = HubTheme.create()
	label.theme_type_variation = &"BodyLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = get_theme_constant(&"tooltip_width", &"ItemList")
	label.text = for_text
	return label


static func description(item: ItemData) -> String:
	return item.label() + "\n" + item.description()
