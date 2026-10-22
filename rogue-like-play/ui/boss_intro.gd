class_name BossIntro
extends CanvasLayer

# A boss's entrance, staged the way action games stage one, with the world
# stopped: black bars slide in at the screen's top and bottom, the camera
# leaves the hero and settles on the boss, the boss roars (it swells and
# flashes, a red ring bursts from it, the screen shakes and flushes red),
# its epithet and name rise in the lower third over a crimson rule, and after
# a hold the camera goes back to her, the bars leave and `finished` lets the
# area start the fight again. The area pauses the world and holds its
# camera; nothing moves and nothing is taken until then.

signal finished

const BAR_HEIGHT := 78.0
const BAR_TIME := 0.3
const PAN_TIME := 0.8
# The roar comes as the camera settles; the name rises with it.
const ROAR_AT := PAN_TIME + 0.1
const SWELL := 1.2
const SWELL_TIME := 0.14
const SETTLE_TIME := 0.32
const ROAR_RING := 260.0
const FLUSH := Color(0.7, 0.05, 0.03, 0.32)
const FLUSH_TIME := 0.45
const NAME_TIME := 0.42
const RULE_WIDTH := 560.0
const HOLD_TIME := 1.2
const RETURN_TIME := 0.6
const OUT_TIME := 0.35
# The name sits this share of the way down the screen.
const NAME_PLACE := 0.74

var _area: BattleArea
var _boss: Foe
var _root: Control
var _top: ColorRect
var _bottom: ColorRect
var _flush: ColorRect
var _rule: Control
var _rule_reach := 0.0
var _epithet: Label
var _name: Label


# From the boss coming in to the fight going on.
static func total_time() -> float:
	return ROAR_AT + NAME_TIME + HOLD_TIME + RETURN_TIME + OUT_TIME


func present(boss: Foe, area: BattleArea, theme: Theme) -> void:
	_area = area
	_boss = boss
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flush = ColorRect.new()
	_flush.color = Color(FLUSH, 0.0)
	_flush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flush)
	_flush.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar_color := _root.get_theme_color(&"bar", &"BossIntro")
	_top = _bar(bar_color, true)
	_bottom = _bar(bar_color, false)
	_rule = Control.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.draw.connect(_draw_rule)
	_root.add_child(_rule)
	_rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_epithet = _label(boss.data.epithet, &"BossEpithet")
	_name = _label(boss.data.display_name, &"BossName")
	var screen := _root.get_viewport_rect().size
	_name.position.y = screen.y * NAME_PLACE - _name.get_combined_minimum_size().y * 0.5
	_epithet.position.y = _name.position.y - _epithet.get_combined_minimum_size().y - 2.0
	for label: Label in [_epithet, _name]:
		label.modulate.a = 0.0
	var camera := area.camera
	camera.position_smoothing_enabled = false
	var stage := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
	stage.tween_property(_top, "position:y", 0.0, BAR_TIME).set_ease(Tween.EASE_OUT)
	stage.tween_property(_bottom, "position:y", screen.y - BAR_HEIGHT, BAR_TIME).set_ease(Tween.EASE_OUT)
	stage.tween_property(camera, "global_position", boss.global_position + CombatArea.CAMERA_LEAD, PAN_TIME).set_ease(Tween.EASE_IN_OUT)
	stage.tween_callback(_roar).set_delay(ROAR_AT)
	stage.tween_method(_reach, 0.0, 1.0, NAME_TIME).set_delay(ROAR_AT)
	for label: Label in [_epithet, _name]:
		var rest := label.position.y
		label.position.y = rest + 18.0
		var delay := ROAR_AT + (0.0 if label == _epithet else 0.1)
		stage.tween_property(label, "position:y", rest, NAME_TIME).set_delay(delay).set_ease(Tween.EASE_OUT)
		stage.tween_property(label, "modulate:a", 1.0, NAME_TIME).set_delay(delay)
	# Then back to her, and away.
	var back_at := ROAR_AT + NAME_TIME + HOLD_TIME
	stage.tween_method(_return_camera, 0.0, 1.0, RETURN_TIME).set_delay(back_at).set_ease(Tween.EASE_IN_OUT)
	for label: Label in [_epithet, _name]:
		stage.tween_property(label, "modulate:a", 0.0, RETURN_TIME).set_delay(back_at)
	stage.tween_method(_reach, 1.0, 0.0, RETURN_TIME).set_delay(back_at)
	stage.tween_property(_top, "position:y", -BAR_HEIGHT, OUT_TIME).set_delay(back_at + RETURN_TIME).set_ease(Tween.EASE_IN)
	stage.tween_property(_bottom, "position:y", screen.y, OUT_TIME).set_delay(back_at + RETURN_TIME).set_ease(Tween.EASE_IN)
	stage.chain().tween_callback(_end)


# The boss's roar: it swells and flashes, a red ring bursts from it, the
# screen shakes and flushes red.
func _roar() -> void:
	GameAudio.play(self, &"boss", -12.0)
	_area.shake(CombatArea.HEAVY_SHAKE * 1.6)
	var swell := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	swell.tween_property(_boss, "scale", Vector2.ONE * SWELL, SWELL_TIME)
	swell.tween_property(_boss, "scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_SINE)
	var glare := create_tween()
	_boss.modulate = Color(1.8, 1.25, 1.2)
	glare.tween_property(_boss, "modulate", Color.WHITE, SETTLE_TIME + SWELL_TIME)
	var ring := GroundRing.new()
	ring.process_mode = Node.PROCESS_MODE_ALWAYS
	_area.marks.add_child(ring)
	ring.start(_boss.global_position, ROAR_RING, &"roar")
	_flush.color = FLUSH
	create_tween().tween_property(_flush, "color", Color(FLUSH, 0.0), FLUSH_TIME)


func _return_camera(progress: float) -> void:
	var from := _boss.global_position + CombatArea.CAMERA_LEAD
	var to := _area.hero.global_position + CombatArea.CAMERA_LEAD
	_area.camera.global_position = from.lerp(to, progress)


func _end() -> void:
	_area.camera.position_smoothing_enabled = true
	_area.camera.reset_smoothing()
	finished.emit()
	queue_free()


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
