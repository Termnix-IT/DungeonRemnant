class_name HitStop
extends Node

# The moment the world holds still when a blow lands. Engine.time_scale
# drops for a few real hundredths of a second, measured on the real clock so
# the stop ends however slow the world runs. Blows landing together share
# one stop; a stop already running can stretch only up to MAX_HOLD, so a
# crowd hit in a row never freezes the fight. A hold (a level-up's lead-in)
# slows the world for longer and more gently, and blows landing meanwhile
# neither deepen nor cut it short.

const SLOW := 0.05
const MAX_HOLD := 0.12

var _started_usec := -1
var _end_usec := -1
var _holding := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func active() -> bool:
	return _end_usec >= 0


func request(duration: float) -> void:
	if duration <= 0.0 or _holding:
		return
	var now := Time.get_ticks_usec()
	if not active():
		_started_usec = now
	var cap := _started_usec + int(MAX_HOLD * 1000000.0)
	_end_usec = mini(maxi(_end_usec, now + int(duration * 1000000.0)), cap)
	Engine.time_scale = SLOW


func _process(_delta: float) -> void:
	if active() and Time.get_ticks_usec() >= _end_usec:
		release()


# The world at `scale` for `duration` real seconds.
func hold(duration: float, scale: float) -> void:
	_holding = true
	_started_usec = Time.get_ticks_usec()
	_end_usec = _started_usec + int(duration * 1000000.0)
	Engine.time_scale = scale


func release() -> void:
	_started_usec = -1
	_end_usec = -1
	_holding = false
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	if active():
		release()
