class_name UIMotion
extends Node

# Only temporal values live here. Colors, borders and typography stay in Theme.
const HOVER_TIME := 0.10
const PRESS_TIME := 0.07
const SELECT_TIME := 0.14
const WINDOW_TIME := 0.18
const GOLD_TIME := 0.22
const EQUIP_TIME := 0.16
const META := &"ui_motion"

var control: Control
var scale_tween: Tween
var alpha_tween: Tween
var selection_tween: Tween
var _base_scale := Vector2.ONE
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
	target.set_meta(META, motion)
	target.add_child(motion)
	return motion


static func bind_buttons(root: Node) -> void:
	if root is Button and root.theme_type_variation in [&"PrimaryButton", &"GoldButton", &"ItemButton", &"SecondaryButton"]:
		of(root)
	for child in root.get_children():
		bind_buttons(child)


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
	if selection_tween != null:
		selection_tween.kill()
	if control is ItemCardList:
		control.selection_strength = 1.0
	if alpha_tween != null:
		alpha_tween.kill()
	control.modulate.a = _base_alpha
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
