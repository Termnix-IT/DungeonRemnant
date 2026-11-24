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

# The clock the stops are measured on (microseconds): the real one. A film
# of the fight is recorded slower than it plays, so its script puts the
# film's own clock here, and a stop lasts in the film what it lasts in play
# (tests/capture_combat_movie.gd), and puts the real one back before it
# quits (a script's function left here crashes the engine as it exits).
static var clock: Callable = Time.get_ticks_usec

# A stop that holds only these nodes (their processing is switched off for
# its length) and leaves the engine's clock alone: a fight shown inside
# another screen (StageArea) stops itself, not the screen. Empty: the stop
# is the whole world's, by the engine's time scale.
var scope: Array[Node] = []

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
	var now: int = clock.call()
	if not active():
		_started_usec = now
	var cap := _started_usec + int(MAX_HOLD * 1000000.0)
	_end_usec = mini(maxi(_end_usec, now + int(duration * 1000000.0)), cap)
	_slow_to(SLOW)


func _process(_delta: float) -> void:
	if active() and clock.call() >= _end_usec:
		release()


# The world at `scale` for `duration` real seconds.
func hold(duration: float, scale: float) -> void:
	_holding = true
	_started_usec = clock.call()
	_end_usec = _started_usec + int(duration * 1000000.0)
	_slow_to(scale)


func release() -> void:
	_started_usec = -1
	_end_usec = -1
	_holding = false
	_slow_to(1.0)


# The world (or, with a scope, only its nodes) at this pace. A scope is
# either held still or let go: it has no slow motion of its own.
func _slow_to(scale: float) -> void:
	if scope.is_empty():
		Engine.time_scale = scale
		return
	for part in scope:
		if is_instance_valid(part):
			part.process_mode = Node.PROCESS_MODE_ALWAYS if scale >= 1.0 else Node.PROCESS_MODE_DISABLED


func _exit_tree() -> void:
	if active():
		release()
