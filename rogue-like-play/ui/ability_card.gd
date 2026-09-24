class_name AbilityCard
extends Control

# Display layer of one level-up offer. The owning Button keeps input and
# layout; this Control only draws, so UIMotion may move it freely.
var ability: AbilityData
var level := 0
var hovered := false:
	set(value):
		hovered = value
		queue_redraw()
# 0..1 strength of the chosen moment: gold accent and the gained rank pip.
var glow := 0.0:
	set(value):
		glow = value
		queue_redraw()
		pips.queue_redraw()

var key_label: Label
var status_label: Label
var name_label: Label
var effect_label: Label
var symbol: Control
var pips: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(top)
	key_label = HubUI.label(top, "", &"MutedLabel")
	key_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label = HubUI.label(top, "", &"MutedLabel")
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	symbol = _canvas(stack, Vector2(80, 80), _draw_symbol)
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label = HubUI.label(stack, "", &"HeadingLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pips = _canvas(stack, Vector2(0, 8), _draw_pips)
	effect_label = HubUI.label(stack, "", &"DescriptionLabel")
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func setup(data: AbilityData, current_level: int, shortcut: int) -> void:
	ability = data
	level = current_level
	glow = 0.0
	hovered = false
	key_label.text = str(shortcut)
	status_label.text = "新規習得" if level == 0 else "Lv %d → %d" % [level, level + 1]
	name_label.text = data.display_name
	name_label.tooltip_text = data.display_name
	effect_label.text = data.effect_description()
	symbol.queue_redraw()


func _canvas(parent: Node, minimum: Vector2, painter: Callable) -> Control:
	var canvas := Control.new()
	canvas.custom_minimum_size = minimum
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(painter)
	parent.add_child(canvas)
	return canvas


func _gold() -> Color:
	return get_theme_color(&"font_color", &"GoldLabel")


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style: StringName = &"card_selected" if glow > 0.0 else (&"card_hover" if hovered else &"card")
	draw_style_box(get_theme_stylebox(style, &"ItemCardList"), rect)
	var accent := _gold()
	accent.a = maxf(0.38 * glow, 0.22 if hovered else 0.0)
	if accent.a > 0.0:
		draw_rect(rect.grow(-3), accent, false, 1.0 + glow)


func _draw_symbol() -> void:
	if ability == null:
		return
	var color := _gold()
	var extent := minf(symbol.size.x, symbol.size.y)
	ItemGlyph.paint_ability(symbol, Rect2((symbol.size - Vector2.ONE * extent) / 2, Vector2.ONE * extent), ability.effect, color)


# One pip per rank: owned ranks are solid, the offered rank fills on choice.
func _draw_pips() -> void:
	if ability == null:
		return
	var count := ability.max_level
	var gap := 4.0
	var width := minf(24.0, (pips.size.x - gap * (count - 1)) / count)
	var start := (pips.size.x - width * count - gap * (count - 1)) / 2
	var gold := _gold()
	var empty := get_theme_color(&"font_color", &"MutedLabel")
	empty.a = 0.3
	for index in count:
		var rect := Rect2(start + index * (width + gap), 0, width, pips.size.y)
		var color := empty
		if index < level:
			color = gold
		elif index == level:
			color = gold
			color.a = lerpf(0.4, 1.0, glow)
		pips.draw_rect(rect, color)
