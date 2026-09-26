class_name StickDirections
extends Node

# Turns the left stick into the eight move actions, so diagonals work on a
# gamepad and held-stick repeat reuses RapidMoveController, which polls
# Input.is_action_pressed(). The D-pad is bound to the cardinal actions.
const DEADZONE := 0.5
# Index 0 points right; indices advance clockwise because screen y is down.
const ACTIONS: Array[StringName] = [&"move_e", &"move_se", &"move_s", &"move_sw", &"move_w", &"move_nw", &"move_n", &"move_ne"]

var held := StringName()


func _process(_delta: float) -> void:
	var stick := Vector2.ZERO
	for device in Input.get_connected_joypads():
		var value := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if value.length() > stick.length():
			stick = value
	var next := direction_action(stick)
	if next == held:
		return
	if not held.is_empty():
		_send(held, false)
	held = next
	if not held.is_empty():
		_send(held, true)


static func direction_action(stick: Vector2) -> StringName:
	if stick.length() < DEADZONE:
		return StringName()
	return ACTIONS[posmod(roundi(stick.angle() / (PI / 4.0)), 8)]


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _exit_tree() -> void:
	if not held.is_empty():
		_send(held, false)
		held = StringName()
