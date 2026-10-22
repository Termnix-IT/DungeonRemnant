class_name AbilityCard
extends Control

# Display layer of one level-up offer. The owning Button keeps input and
# layout; this Control only draws, so UIMotion may move it freely.
# The card is the shared card face (the theme's AbilityCard styles): a blue
# band along its top for a new boon, an amber one for a rank being raised,
# and a gold frame fading in over it on hover and on the chosen moment.
# Ranks are bronze sockets, the owned ones holding an amber gem. It shows a
# BoonData: its emblem, and its words for the rank on offer.
var ability: BoonData
var level := 0
var hovered := false:
	set(value):
		hovered = value
		_show_status()
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
var _chosen: StyleBoxFlat


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
	# The 192px painted emblem at half its size, from its mipmaps.
	symbol = _canvas(stack, Vector2(96, 96), _draw_symbol)
	symbol.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label = HubUI.label(stack, "", &"HeadingLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pips = _canvas(stack, Vector2(0, 12), _draw_pips)
	effect_label = HubUI.label(stack, "", &"DescriptionLabel")
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


# A rank being raised says so; a new boon says it is new, and names its
# families only while it is pointed at or focused (the card's detail).
func _show_status() -> void:
	if status_label == null or ability == null:
		return
	if level > 0:
		status_label.text = "Lv %d → %d" % [level, level + 1]
	else:
		status_label.text = ability.families_text() if hovered else "新規"


func setup(data: BoonData, current_level: int, shortcut: int) -> void:
	ability = data
	level = current_level
	glow = 0.0
	hovered = false
	key_label.text = str(shortcut)
	_show_status()
	name_label.text = data.display_name
	name_label.tooltip_text = data.display_name
	TextWrap.set_text(effect_label, data.effect_description(level + 1))
	symbol.queue_redraw()


func _canvas(parent: Node, minimum: Vector2, painter: Callable) -> Control:
	var canvas := Control.new()
	canvas.custom_minimum_size = minimum
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(painter)
	parent.add_child(canvas)
	return canvas


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox(&"new" if level == 0 else &"raise", &"AbilityCard"), rect)
	var lit := maxf(glow, 0.55 if hovered else 0.0)
	if lit > 0.0:
		var base := get_theme_stylebox(&"chosen", &"AbilityCard") as StyleBoxFlat
		if _chosen == null:
			_chosen = base.duplicate() as StyleBoxFlat
		_chosen.border_color = Color(base.border_color, base.border_color.a * lit)
		_chosen.bg_color = Color(base.bg_color, base.bg_color.a * lit)
		draw_style_box(_chosen, rect)


func _draw_symbol() -> void:
	if ability == null:
		return
	var extent := minf(symbol.size.x, symbol.size.y)
	EmblemIcons.paint(symbol, Rect2((symbol.size - Vector2.ONE * extent) / 2, Vector2.ONE * extent), ability.emblem_key())


# One socket per rank: owned ranks hold a gem, the offered rank's gem fades
# in on choice.
func _draw_pips() -> void:
	if ability == null:
		return
	var empty := get_theme_icon(&"pip_empty", &"AbilityCard")
	var full := get_theme_icon(&"pip_full", &"AbilityCard")
	var count: int = ability.max_level
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
