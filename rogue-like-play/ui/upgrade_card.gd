extends Button

var caption: Label
var rank_label: Label
var benefit: Label
var cost_label: Label
var progress: ProgressBar
var effect: StringName = &"hp"


func _ready() -> void:
	theme_type_variation = &"ItemButton"
	toggle_mode = true
	custom_minimum_size.y = 90
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"CompactMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size.x = 44
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	icon.draw.connect(func(): _draw_icon(icon))
	var content := VBoxContainer.new()
	content.theme_type_variation = &"CompactStack"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	caption = HubUI.label(heading, "", &"ItemNameLabel")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_label = HubUI.label(heading, "", &"MutedLabel")
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 5
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(progress)
	var foot := HBoxContainer.new()
	content.add_child(foot)
	benefit = HubUI.label(foot, "", &"MutedLabel")
	benefit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label = HubUI.label(foot, "", &"GoldLabel")
	_ignore_children(self)


func _ignore_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if child is Label:
			child.autowrap_mode = TextServer.AUTOWRAP_OFF
		_ignore_children(child)


func _draw() -> void:
	var selected := button_pressed
	var style: StringName = &"card_selected" if selected else (&"card_hover" if is_hovered() else &"card")
	draw_style_box(get_theme_stylebox(style, &"ItemCardList"), Rect2(Vector2.ZERO, size))


func _draw_icon(icon: Control) -> void:
	var color := get_theme_color(&"font_color", &"GoldLabel")
	var rect := Rect2(Vector2(2, (icon.size.y - 40) / 2), Vector2(40, 40))
	if effect == &"hp":
		ItemGlyph.paint_ability(icon, rect, AbilityData.Effect.MAX_HP, color)
	else:
		var item := ItemCatalog.floor_item(6 if effect == &"attack" else 1)
		if effect == &"mp":
			item = preload("res://data/items/bolt_scroll.tres")
		ItemGlyph.paint(icon, rect, item, color)
