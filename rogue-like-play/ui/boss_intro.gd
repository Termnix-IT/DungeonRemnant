class_name BossIntro
extends CanvasLayer

# A boss's arrival told the way action games name their bosses: black bars
# slide in at the screen's top and bottom, its epithet and then its name
# rise in the lower third over a crimson rule that runs out from the middle,
# and after a hold it all fades. The fight does not wait for it: it only
# frames the moment, takes no input and frees itself.

const BAR_HEIGHT := 78.0
const BAR_TIME := 0.25
const NAME_DELAY := 0.18
const NAME_TIME := 0.42
const RULE_WIDTH := 560.0
const HOLD_TIME := 1.6
const OUT_TIME := 0.35
# The name sits this share of the way down the screen.
const NAME_PLACE := 0.74

var _root: Control
var _top: ColorRect
var _bottom: ColorRect
var _rule: Control
var _rule_reach := 0.0
var _epithet: Label
var _name: Label


func present(foe: FoeData, theme: Theme) -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar_color := _root.get_theme_color(&"bar", &"BossIntro")
	_top = _bar(bar_color, true)
	_bottom = _bar(bar_color, false)
	_rule = Control.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.draw.connect(_draw_rule)
	_root.add_child(_rule)
	_rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_epithet = _label(foe.epithet, &"BossEpithet")
	_name = _label(foe.display_name, &"BossName")
	var screen := _root.get_viewport_rect().size
	_name.position.y = screen.y * NAME_PLACE - _name.get_combined_minimum_size().y * 0.5
	_epithet.position.y = _name.position.y - _epithet.get_combined_minimum_size().y - 2.0
	var opening := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	opening.tween_property(_top, "position:y", 0.0, BAR_TIME)
	opening.tween_property(_bottom, "position:y", screen.y - BAR_HEIGHT, BAR_TIME)
	opening.tween_method(_reach, 0.0, 1.0, NAME_TIME).set_delay(NAME_DELAY)
	for label: Label in [_epithet, _name]:
		var rest := label.position.y
		label.position.y = rest + 18.0
		label.modulate.a = 0.0
		var delay := NAME_DELAY + (0.0 if label == _epithet else 0.1)
		opening.tween_property(label, "position:y", rest, NAME_TIME).set_delay(delay)
		opening.tween_property(label, "modulate:a", 1.0, NAME_TIME).set_delay(delay)
	var closing := create_tween().set_parallel()
	closing.tween_interval(BAR_TIME + NAME_TIME + HOLD_TIME)
	closing.chain().tween_property(_root, "modulate:a", 0.0, OUT_TIME)
	closing.tween_property(_top, "position:y", -BAR_HEIGHT, OUT_TIME)
	closing.tween_property(_bottom, "position:y", screen.y, OUT_TIME)
	closing.chain().tween_callback(queue_free)


func _bar(color: Color, top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	var screen := _root.get_viewport_rect().size
	bar.size = Vector2(screen.x, BAR_HEIGHT)
	bar.position = Vector2(0, -BAR_HEIGHT if top else screen.y)
	return bar


func _label(text: String, role: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = role
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	label.size.x = _root.get_viewport_rect().size.x
	return label


func _reach(value: float) -> void:
	_rule_reach = value
	_rule.queue_redraw()


# A crimson line under the name, out from the middle both ways, fading at its ends.
func _draw_rule() -> void:
	var color := _root.get_theme_color(&"rule", &"BossIntro")
	var middle := Vector2(_rule.size.x * 0.5, _name.position.y + _name.size.y + 6.0)
	var half := RULE_WIDTH * 0.5 * _rule_reach
	_rule.draw_polyline_colors(PackedVector2Array([middle - Vector2(half, 0), middle, middle + Vector2(half, 0)]), PackedColorArray([Color(color, 0.0), color, Color(color, 0.0)]), 2.0, true)
	_rule.draw_colored_polygon(PackedVector2Array([middle + Vector2(0, -5), middle + Vector2(5, 0), middle + Vector2(0, 5), middle + Vector2(-5, 0)]), Color(color, _rule_reach))
