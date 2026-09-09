class_name RapidMoveController
extends Node

signal step_requested(direction: Vector2i)

const DIRECTION_ACTIONS := {
	Vector2i.UP: &"move_n",
	Vector2i(1, -1): &"move_ne",
	Vector2i.RIGHT: &"move_e",
	Vector2i(1, 1): &"move_se",
	Vector2i.DOWN: &"move_s",
	Vector2i(-1, 1): &"move_sw",
	Vector2i.LEFT: &"move_w",
	Vector2i(-1, -1): &"move_nw",
}

@export_range(0.05, 1.0, 0.01) var initial_delay := 0.25
@export_range(0.03, 0.5, 0.01) var repeat_interval := 0.08

var direction := Vector2i.ZERO
var action := StringName()
var armed := false
var timer := Timer.new()


func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)
	set_process(false)


func arm(next_direction: Vector2i) -> bool:
	stop()
	if not DIRECTION_ACTIONS.has(next_direction):
		return false
	var next_action: StringName = DIRECTION_ACTIONS[next_direction]
	if not Input.is_action_pressed(next_action):
		return false
	direction = next_direction
	action = next_action
	armed = true
	set_process(true)
	timer.start(initial_delay)
	return true


func stop() -> void:
	timer.stop()
	direction = Vector2i.ZERO
	action = StringName()
	armed = false
	set_process(false)


func _process(_delta: float) -> void:
	if armed and not Input.is_action_pressed(action):
		stop()


func _on_timeout() -> void:
	if not armed or not Input.is_action_pressed(action):
		stop()
		return
	step_requested.emit(direction)
	# The receiver may synchronously stop acceleration after checking the new state.
	if armed:
		timer.start(repeat_interval)
