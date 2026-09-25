extends Button

var caption: Label
var rank_label: Label
var benefit: Label
var cost_label: Label
var progress: ProgressBar
var effect: StringName = &"hp"
var pips: Control
# 0..1 brightness of the most recently gained rank pip; 1 when settled.
var glow := 1.0:
	set(value):
		glow = value
		if pips != null:
			pips.queue_redraw()


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
	# The ProgressBar keeps value and maximum; ranks are drawn as pips.
	progress = ProgressBar.new()
	progress.visible = false
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(progress)
	pips = Control.new()
	pips.custom_minimum_size.y = 6
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(_draw_pips)
	content.add_child(pips)
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


# One pip per rank up to the maximum; the newest owned pip fades in on gain.
func _draw_pips() -> void:
	var count := int(progress.max_value)
	if count <= 0:
		return
	var owned := int(progress.value)
	var gap := 3.0
	var width := minf(18.0, (pips.size.x - gap * (count - 1)) / count)
	var gold := get_theme_color(&"font_color", &"GoldLabel")
	var empty := get_theme_color(&"font_color", &"MutedLabel")
	empty.a = 0.25
	for index in count:
		var color := empty
		if index < owned:
			color = gold
			if index == owned - 1:
				color.a = lerpf(0.3, 1.0, glow)
		pips.draw_rect(Rect2(index * (width + gap), 0, width, pips.size.y), color)


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
