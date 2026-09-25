class_name UIMotion
extends Node

# Only temporal values live here. Colors, borders and typography stay in Theme.
const HOVER_TIME := 0.10
const PRESS_TIME := 0.07
const SELECT_TIME := 0.14
const WINDOW_TIME := 0.18
const GOLD_TIME := 0.22
const EQUIP_TIME := 0.16
const VITAL_HOLD_TIME := 0.12
const VITAL_DRAIN_TIME := 0.28
const VITAL_PULSE_TIME := 0.22
# Display-layer motion. Only for Controls that no Container positions.
const ENTER_TIME := 0.24
const STAGGER_TIME := 0.06
const ENTER_DISTANCE := 24.0
const PAGE_DISTANCE := 16.0
const LIFT_DISTANCE := 6.0
const EXIT_TIME := 0.12
# A chosen moment rises, holds briefly, then leaves; 0.40s in total.
const MOMENT_RISE_TIME := 0.21
const MOMENT_HOLD_TIME := 0.07
const MOMENT_TIME := MOMENT_RISE_TIME + MOMENT_HOLD_TIME + EXIT_TIME
# Result rows appear one after another; numbers count for at most COUNT_MAX_TIME.
const SEQUENCE_STEP_TIME := 0.12
const COUNT_MIN_TIME := 0.25
const COUNT_MAX_TIME := 0.6
const TRAVEL_TIME := 0.38
const META := &"ui_motion"

var control: Control
var scale_tween: Tween
var alpha_tween: Tween
var selection_tween: Tween
var vital_tween: Tween
var position_tween: Tween
var glow_tween: Tween
var count_tween: Tween
var flash_tween: Tween
var _base_color := Color.WHITE
var _count_text := ""
var _vital_initialized := false
var _vital_value := 0.0
var _vital_maximum := 1.0
var _base_scale := Vector2.ONE
var _base_position := Vector2.ZERO
var _base_alpha := 1.0
var _hovered := false
var _down := false
var _press_animating := false
var _pulsing := false
var _disabled := false


static func of(target: Control) -> UIMotion:
	if target.has_meta(META):
		return target.get_meta(META) as UIMotion
	var motion := UIMotion.new()
	motion.control = target
	motion._base_scale = target.scale
	motion._base_alpha = target.modulate.a
	motion._base_position = target.position
	motion._base_color = target.modulate
	target.set_meta(META, motion)
	target.add_child(motion)
	return motion


static func bind_buttons(root: Node) -> void:
	if root is Button and root.theme_type_variation in [&"PrimaryButton", &"GoldButton", &"ItemButton", &"SecondaryButton"]:
		of(root)
	for child in root.get_children():
		bind_buttons(child)


# Call after all selected content is updated, never during ordinary refresh.
static func reveal_selection(targets: Array[Control]) -> void:
	for target in targets:
		of(target).reveal(SELECT_TIME)


func _ready() -> void:
	control.resized.connect(_center)
	control.visibility_changed.connect(_visibility_changed)
	_center()
	if control is Button:
		var button := control as Button
		_disabled = button.disabled
		button.mouse_entered.connect(_hover.bind(true))
		button.mouse_exited.connect(_hover.bind(false))
		button.focus_entered.connect(_update_button)
		button.focus_exited.connect(_update_button)
		button.button_down.connect(_press)
		button.button_up.connect(_release)
		# BaseButton has no disabled_changed signal. Check only on redraw;
		# there is no per-frame polling and no new tween unless it changed.
		button.draw.connect(_check_disabled)


func _center() -> void:
	control.pivot_offset = control.size * 0.5


func _hover(value: bool) -> void:
	_hovered = value
	_update_button()


func _rest_scale() -> Vector2:
	if control is Button:
		var button := control as Button
		if not button.disabled and (_hovered or button.has_focus()):
			match button.theme_type_variation:
				&"PrimaryButton", &"GoldButton": return _base_scale * 1.015
				&"ItemButton": return _base_scale * 1.01
	return _base_scale


func _update_button() -> void:
	if not control.is_visible_in_tree() or (control is Button and control.disabled):
		reset()
		return
	if _down or _press_animating or _pulsing:
		return
	var tween := _scale_animation()
	tween.tween_property(control, "scale", _rest_scale(), HOVER_TIME)


func _check_disabled() -> void:
	var button := control as Button
	if button.disabled != _disabled:
		_disabled = button.disabled
		_update_button()


func _press() -> void:
	if not control.is_visible_in_tree() or (control as Button).disabled:
		return
	_down = true
	_press_animating = true
	_pulsing = false
	var tween := _scale_animation()
	tween.tween_property(control, "scale", _base_scale * 0.98, PRESS_TIME)
	tween.tween_callback(_finish_press)


func _finish_press() -> void:
	_press_animating = false
	_update_button()


func _release() -> void:
	_down = false
	_update_button()


func pulse(factor: float = 1.04, duration: float = EQUIP_TIME) -> void:
	if not control.is_visible_in_tree():
		return
	_center()
	_down = false
	_press_animating = false
	_pulsing = true
	var tween := _scale_animation()
	tween.tween_property(control, "scale", _base_scale * factor, duration * 0.4)
	tween.tween_property(control, "scale", _rest_scale(), duration * 0.6)
	tween.tween_callback(_finish_pulse)


func _finish_pulse() -> void:
	_pulsing = false
	if control is Button:
		_update_button()
	else:
		reset_scale()


func reveal(duration: float = SELECT_TIME) -> void:
	if not control.is_visible_in_tree():
		return
	if alpha_tween != null:
		alpha_tween.kill()
	# Never blank text or block input while a new selection is already usable.
	control.modulate.a = _base_alpha * 0.65
	alpha_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	alpha_tween.tween_property(control, "modulate:a", _base_alpha, duration)


func select_card() -> void:
	if not control is ItemCardList or not control.is_visible_in_tree():
		return
	if selection_tween != null:
		selection_tween.kill()
	control.selection_strength = 0.0
	selection_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	selection_tween.tween_property(control, "selection_strength", 1.0, SELECT_TIME)


# Display layers only: the Control must not be positioned by a Container.
# Input and selection stay usable while the layer is still arriving.
func enter(delay: float = 0.0, offset := Vector2(0, ENTER_DISTANCE), duration: float = ENTER_TIME) -> void:
	if not control.is_visible_in_tree():
		return
	_stop(position_tween)
	_stop(alpha_tween)
	control.position = _base_position + offset
	control.modulate.a = 0.0
	position_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	position_tween.tween_interval(delay)
	position_tween.tween_property(control, "position", _base_position, duration)
	alpha_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	alpha_tween.tween_interval(delay)
	alpha_tween.tween_property(control, "modulate:a", _base_alpha, duration)


func lift(value: bool) -> void:
	if not control.is_visible_in_tree():
		return
	_stop(position_tween)
	position_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	position_tween.tween_property(control, "position", _base_position - Vector2(0, LIFT_DISTANCE if value else 0.0), HOVER_TIME)


# The chosen moment: rises with a small overshoot and fills its optional glow.
func emphasize() -> void:
	if not control.is_visible_in_tree():
		return
	_center()
	_stop(position_tween)
	_stop(alpha_tween)
	control.modulate.a = _base_alpha
	scale_tween = _scale_animation().set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(control, "scale", _base_scale * 1.05, MOMENT_RISE_TIME)
	position_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	position_tween.tween_property(control, "position", _base_position - Vector2(0, LIFT_DISTANCE * 2), MOMENT_RISE_TIME)
	if &"glow" in control:
		_stop(glow_tween)
		glow_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		glow_tween.tween_property(control, "glow", 1.0, MOMENT_RISE_TIME)


func recede() -> void:
	if not control.is_visible_in_tree():
		return
	_center()
	_stop(position_tween)
	_stop(alpha_tween)
	scale_tween = _scale_animation().set_ease(Tween.EASE_IN)
	scale_tween.tween_property(control, "scale", _base_scale * 0.94, EXIT_TIME * 1.5)
	position_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	position_tween.tween_property(control, "position", control.position + Vector2(0, ENTER_DISTANCE * 0.5), EXIT_TIME * 1.5)
	alpha_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	alpha_tween.tween_property(control, "modulate:a", 0.0, EXIT_TIME * 1.5)


# Alpha only, so it is safe for Controls positioned by a Container.
func appear(delay: float = 0.0, duration: float = ENTER_TIME) -> void:
	if not control.is_visible_in_tree():
		return
	_stop(alpha_tween)
	control.modulate.a = 0.0
	alpha_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	alpha_tween.tween_interval(delay)
	alpha_tween.tween_property(control, "modulate:a", _base_alpha, duration)


# Shows a number counting toward an already settled value. The caller has
# written the final text first; this only replays the change for the eye.
func count(from: int, to: int, format: Callable, delay: float = 0.0) -> void:
	if not control is Label or not control.is_visible_in_tree() or from == to:
		return
	_stop(count_tween)
	var label := control as Label
	var duration := clampf(COUNT_MIN_TIME + absi(to - from) * 0.004, COUNT_MIN_TIME, COUNT_MAX_TIME)
	_count_text = format.call(to)
	label.text = format.call(from)
	count_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	count_tween.tween_interval(delay)
	count_tween.tween_method(func(value: float): label.text = format.call(roundi(value)), float(from), float(to), duration)


# Success moment for a trade or move: the item's glyph flies from one Control
# to another on a pointer-transparent copy owned by host, then frees itself.
# Connect to the returned tween's finished signal to acknowledge the landing.
static func fly_glyph(host: Control, item: ItemData, from: Control, to: Control) -> Tween:
	return fly_glyph_at(host, item, from, to.get_global_rect().get_center())


# Same as fly_glyph, landing on a global point such as one list row.
static func fly_glyph_at(host: Control, item: ItemData, from: Control, point: Vector2) -> Tween:
	var ghost := Control.new()
	ghost.top_level = true
	# Top-level copies do not inherit a raised parent z (the warehouse uses
	# one), so draw above any panel explicitly.
	ghost.z_as_relative = false
	ghost.z_index = 100
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = from.size
	# A top-level copy may not inherit the host's Theme; resolve colour first.
	var color := from.get_theme_color(&"font_color", &"GoldLabel")
	ghost.draw.connect(func():
		var extent := minf(ghost.size.x, ghost.size.y) * 0.68
		ItemGlyph.paint(ghost, Rect2((ghost.size - Vector2.ONE * extent) / 2, Vector2.ONE * extent), item, color))
	host.add_child(ghost)
	ghost.global_position = from.global_position
	var tween := of(ghost).travel(point - ghost.size * 0.5)
	tween.finished.connect(ghost.queue_free)
	return tween


# A brief brightening that returns to the base colour; alpha is untouched.
func flash(strength: float = 1.35, duration: float = GOLD_TIME) -> void:
	if not control.is_visible_in_tree():
		return
	_stop(flash_tween)
	control.modulate = Color(_base_color.r * strength, _base_color.g * strength, _base_color.b * strength, control.modulate.a)
	flash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(control, "modulate", Color(_base_color, control.modulate.a), duration)


# A transient copy flies to a global point, shrinking and fading on arrival.
# The caller frees the copy when the returned tween finishes.
func travel(to: Vector2, duration: float = TRAVEL_TIME) -> Tween:
	_center()
	_stop(position_tween)
	position_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	position_tween.tween_property(control, "global_position", to, duration)
	position_tween.tween_property(control, "scale", _base_scale * 0.45, duration)
	position_tween.tween_property(control, "modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	return position_tween


func fade_out(delay: float = 0.0, duration: float = EXIT_TIME) -> Tween:
	_stop(alpha_tween)
	alpha_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	alpha_tween.tween_interval(delay)
	alpha_tween.tween_property(control, "modulate:a", 0.0, duration)
	return alpha_tween


func _stop(tween: Tween) -> void:
	if tween != null:
		tween.kill()


# The foreground bar and text are updated by HUD synchronously. Only the
# trailing bar animates, so combat never waits for presentation.
func update_vital(value: float, maximum: float, label: Label) -> void:
	var trail := control as ProgressBar
	var limit := maxf(maximum, 1.0)
	var current := clampf(value, 0.0, limit)
	var immediate := not _vital_initialized or not control.is_visible_in_tree() or limit != _vital_maximum
	var previous := _vital_value
	_vital_value = current
	_vital_maximum = limit
	trail.max_value = limit
	if immediate:
		reset_vital()
		_vital_initialized = control.is_visible_in_tree()
		UIMotion.of(label).reset()
		return
	if current == previous:
		return
	if vital_tween != null:
		vital_tween.kill()
	UIMotion.of(label).pulse(1.06, VITAL_PULSE_TIME)
	if current < previous:
		trail.value = maxf(trail.value, previous)
		vital_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		vital_tween.tween_interval(VITAL_HOLD_TIME)
		vital_tween.tween_property(trail, "value", current, VITAL_DRAIN_TIME)
	else:
		trail.value = current


func reset_vital() -> void:
	if vital_tween != null:
		vital_tween.kill()
	if control is ProgressBar:
		control.value = _vital_value
	_vital_initialized = false


func _scale_animation() -> Tween:
	if scale_tween != null:
		scale_tween.kill()
	_center()
	scale_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return scale_tween


func reset_scale() -> void:
	if scale_tween != null:
		scale_tween.kill()
	control.scale = _base_scale


func reset() -> void:
	reset_scale()
	reset_vital()
	if selection_tween != null:
		selection_tween.kill()
	if control is ItemCardList:
		control.selection_strength = 1.0
	if alpha_tween != null:
		alpha_tween.kill()
	control.modulate.a = _base_alpha
	if position_tween != null:
		position_tween.kill()
		control.position = _base_position
	if glow_tween != null:
		glow_tween.kill()
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
		control.modulate = Color(_base_color, control.modulate.a)
	if count_tween != null and count_tween.is_valid():
		count_tween.kill()
		(control as Label).text = _count_text
	_down = false
	_press_animating = false
	_pulsing = false


func _visibility_changed() -> void:
	if not control.is_visible_in_tree():
		_hovered = false
		reset()
	elif control is Button:
		_update_button.call_deferred()


func _exit_tree() -> void:
	reset()
