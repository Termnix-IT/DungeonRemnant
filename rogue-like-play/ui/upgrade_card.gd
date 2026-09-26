extends Button

var caption: Label
var rank_label: Label
var benefit: Label
var cost_label: Label
var progress: ProgressBar
var effect: StringName = &"hp"
# The tree root (基礎HP) and the 生命力 branch share the HP effect; the branch
# adds a small plus so the two cards do not read as duplicates.
var branch := false
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


# Short tracks (up to 10 ranks) draw one pip per rank. Long tracks read as a
# single gauge with a notch every 5 ranks instead of a row of tiny dashes.
# The newest owned rank fades in on gain either way.
const PIP_LIMIT := 10
const TRACK_WIDTH := 220.0


func _draw_pips() -> void:
	var count := int(progress.max_value)
	if count <= 0:
		return
	var owned := int(progress.value)
	var gold := get_theme_color(&"font_color", &"GoldLabel")
	var empty := get_theme_color(&"font_color", &"MutedLabel")
	empty.a = 0.25
	var height := pips.size.y
	if count > PIP_LIMIT:
		var width := minf(TRACK_WIDTH, pips.size.x)
		pips.draw_rect(Rect2(0, 0, width, height), empty)
		var step := width / count
		pips.draw_rect(Rect2(0, 0, step * maxi(owned - 1, 0), height), gold)
		if owned > 0:
			pips.draw_rect(Rect2(step * (owned - 1), 0, step, height), Color(gold, lerpf(0.3, 1.0, glow)))
		var notch := get_theme_color(&"font_color", &"Label")
		notch.a = 0.35
		for mark in range(5, count, 5):
			pips.draw_rect(Rect2(step * mark - 0.5, -2, 1, height + 4), notch)
		return
	var gap := 4.0
	var pip := minf(18.0, (pips.size.x - gap * (count - 1)) / count)
	for index in count:
		var color := empty
		if index < owned:
			color = gold
			if index == owned - 1:
				color.a = lerpf(0.3, 1.0, glow)
		pips.draw_rect(Rect2(index * (pip + gap), 0, pip, height), color)


func _draw_icon(icon: Control) -> void:
	var color := get_theme_color(&"font_color", &"GoldLabel")
	var rect := Rect2(Vector2(2, (icon.size.y - 40) / 2), Vector2(40, 40))
	if effect == &"hp":
		ItemGlyph.paint_ability(icon, rect, AbilityData.Effect.MAX_HP, color)
		if branch:
			var plus := rect.position + Vector2(33, 7)
			icon.draw_circle(plus, 7.5, get_theme_color(&"font_color", &"ItemNameLabel").darkened(0.8))
			icon.draw_line(plus - Vector2(4, 0), plus + Vector2(4, 0), color, 2.0)
			icon.draw_line(plus - Vector2(0, 4), plus + Vector2(0, 4), color, 2.0)
	else:
		var item := ItemCatalog.floor_item(6 if effect == &"attack" else 1)
		if effect == &"mp":
			item = preload("res://data/items/bolt_scroll.tres")
		ItemGlyph.paint(icon, rect, item, color)
