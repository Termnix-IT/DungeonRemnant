class_name AbilityCard
extends Control

# Display layer of one level-up offer. The owning Button keeps input and
# layout; this Control only draws, so UIMotion may move it freely.
# The card is a painted bronze frame (the theme's AbilityCard styles): a blue
# gem crowns a new ability, an amber one a rank being raised, and the chosen
# card turns gold, its frame fading in on hover and on the chosen moment.
# Ranks are bronze sockets, the owned ones holding an amber gem.
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
# The gold frame, faded in over the card by its own copy of the style.
var _chosen: StyleBoxTexture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inside the frame's corner ornaments.
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"AbilityCardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)
	# The shortcut and the status share one centred line under the gem, clear
	# of the corner ornaments.
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(top)
	key_label = HubUI.label(top, "", &"MutedLabel")
	key_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label = HubUI.label(top, "", &"MutedLabel")
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# 96px shows a 2x emblem at its stored size, one texture pixel per pixel.
	symbol = _canvas(stack, Vector2(96, 96), _draw_symbol)
	symbol.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label = HubUI.label(stack, "", &"HeadingLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pips = _canvas(stack, Vector2(0, 12), _draw_pips)
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
	TextWrap.set_text(effect_label, data.effect_description())
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
	draw_style_box(get_theme_stylebox(&"new" if level == 0 else &"raise", &"AbilityCard"), rect)
	var lit := maxf(glow, 0.55 if hovered else 0.0)
	if lit > 0.0:
		if _chosen == null:
			_chosen = get_theme_stylebox(&"chosen", &"AbilityCard").duplicate() as StyleBoxTexture
		_chosen.modulate_color = Color(1, 1, 1, lit)
		draw_style_box(_chosen, rect)


func _draw_symbol() -> void:
	if ability == null:
		return
	var color := _gold()
	var extent := minf(symbol.size.x, symbol.size.y)
	ItemGlyph.paint_ability(symbol, Rect2((symbol.size - Vector2.ONE * extent) / 2, Vector2.ONE * extent), ability.effect, color)


# One socket per rank: owned ranks hold a gem, the offered rank's gem fades
# in on choice.
func _draw_pips() -> void:
	if ability == null:
		return
	var empty := get_theme_icon(&"pip_empty", &"AbilityCard")
	var full := get_theme_icon(&"pip_full", &"AbilityCard")
	var count := ability.max_level
	var gap := 3.0
	var width := minf(full.get_width(), (pips.size.x - gap * (count - 1)) / count)
	var height := width * full.get_height() / full.get_width()
	var start := (pips.size.x - width * count - gap * (count - 1)) / 2
	for index in count:
		var rect := Rect2(start + index * (width + gap), (pips.size.y - height) / 2, width, height)
		pips.draw_texture_rect(empty, rect, false)
		if index < level:
			pips.draw_texture_rect(full, rect, false)
		elif index == level:
			pips.draw_texture_rect(full, rect, false, Color(1, 1, 1, lerpf(0.35, 1.0, glow)))
