class_name HeroMotor
extends RefCounted

# The hero's body in real time, as rules: walking with weight, the dash and
# its untouchable moment, the combo, the charge and the buffer that keeps a
# press made while busy. It knows nothing of nodes or drawing; Hero feeds it
# a HeroInput every physics frame and moves by motion(), and tests step it
# with any delta they like.
#
# A strike starts a swing at once. Held past the swing's end it becomes a
# charge, counted from the press, let loose as the charged attack when
# released after charge_time; released sooner, nothing more happens. A
# strike pressed during a swing continues the combo from combo_after on; a
# dash cuts a swing short from dash_after on, and a charge at any time.

signal swing_started(attack: AttackData)
signal dashed(direction: Vector2)
signal charge_ready

enum State { FREE, ATTACK, CHARGE, DASH, DOWN }
enum Press { NONE, STRIKE, DASH }

var tuning: HeroTuning
var moveset: Moveset
var state := State.FREE
# Seconds since the current state began (into the swing, for an attack).
var state_time := 0.0
# The walking part of the motion; motion() adds the lunge and any push.
var velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var attack: AttackData
# Counts swings, so a target is hit once per swing (Hero keeps who was hit).
var swing_serial := 0
# The swing of the combo now playing, or -1 for the charged attack.
var combo_index := -1
var dash_charges := 1
# Seconds since the last dash ended (Phase 3's after-dash effects read it).
var since_dash := INF

var _buffered := Press.NONE
var _buffer_left := 0.0
var _holding := false
var _hold_time := 0.0
var _charge_announced := false
var _combo_grace_left := 0.0
var _recharge_left := 0.0
var _invulnerable_left := 0.0
var _dash_direction := Vector2.ZERO
var _lunge := Vector2.ZERO
var _push := Vector2.ZERO


func _init(hero_tuning: HeroTuning, hero_moveset: Moveset) -> void:
	tuning = hero_tuning
	moveset = hero_moveset
	dash_charges = tuning.dash_charges


func step(input: HeroInput, delta: float) -> void:
	_push = _push * exp(-tuning.push_decay * delta)
	if _push.length() < 1.0:
		_push = Vector2.ZERO
	_lunge = Vector2.ZERO
	if state == State.DOWN:
		velocity = velocity.move_toward(Vector2.ZERO, tuning.deceleration * delta)
		return
	_tick(delta)
	_read(input, delta)
	match state:
		State.FREE:
			_free(input, delta)
		State.ATTACK:
			_attacking(input, delta)
		State.CHARGE:
			_charging(input, delta)
		State.DASH:
			_dashing(delta)


# Where she goes this frame, in world px per second.
func motion() -> Vector2:
	return velocity + _lunge + _push


func invulnerable() -> bool:
	return _invulnerable_left > 0.0


# Whether the swing now playing can hit this frame.
func hitting() -> bool:
	return state == State.ATTACK and attack != null and attack.hitting(state_time)


# How full the charge is, 0 to 1, while the strike is held.
func charge_progress() -> float:
	if not _holding or moveset.charge_time <= 0.0:
		return 0.0
	return clampf(_hold_time / moveset.charge_time, 0.0, 1.0)


func charging() -> bool:
	return state == State.CHARGE


func push(impulse: Vector2) -> void:
	_push += impulse


func fall() -> void:
	state = State.DOWN
	state_time = 0.0
	_holding = false
	_buffered = Press.NONE


func _tick(delta: float) -> void:
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	_combo_grace_left = maxf(0.0, _combo_grace_left - delta)
	# A press made during a dash waits for its end.
	if state != State.DASH and _buffer_left > 0.0:
		_buffer_left -= delta
		if _buffer_left <= 0.0:
			_buffered = Press.NONE
	if state != State.DASH:
		since_dash += delta
		if dash_charges < tuning.dash_charges:
			_recharge_left -= delta
			if _recharge_left <= 0.0:
				dash_charges += 1
				_recharge_left = tuning.dash_cooldown if dash_charges < tuning.dash_charges else 0.0


func _read(input: HeroInput, delta: float) -> void:
	if input.strike_pressed:
		_press(Press.STRIKE)
		_holding = true
		_hold_time = 0.0
		_charge_announced = false
	elif _holding:
		if input.strike_held:
			_hold_time += delta
		else:
			_holding = false
	if input.dash_pressed:
		_press(Press.DASH)


func _press(kind: Press) -> void:
	_buffered = kind
	_buffer_left = tuning.input_buffer


func _take(kind: Press) -> bool:
	if _buffered != kind:
		return false
	_buffered = Press.NONE
	_buffer_left = 0.0
	return true


func _free(input: HeroInput, delta: float) -> void:
	if _buffered == Press.DASH and dash_charges > 0:
		_take(Press.DASH)
		_start_dash(input, delta)
		return
	if _take(Press.STRIKE):
		var index := (combo_index + 1) % moveset.combo.size() if _combo_grace_left > 0.0 and combo_index >= 0 else 0
		_start_swing(moveset.combo[index], index, input.aim)
		return
	_walk(input.move, tuning.max_speed, delta)
	if input.move.length() > 0.1:
		facing = input.move.normalized()


func _attacking(input: HeroInput, delta: float) -> void:
	state_time += delta
	if _buffered == Press.DASH and state_time >= attack.dash_after and dash_charges > 0:
		_take(Press.DASH)
		_start_dash(input, delta)
		return
	var next := combo_index + 1
	if _buffered == Press.STRIKE and combo_index >= 0 and next < moveset.combo.size() and state_time >= attack.combo_after:
		_take(Press.STRIKE)
		_start_swing(moveset.combo[next], next, input.aim)
		return
	_walk(input.move, tuning.max_speed * attack.move_scale, delta)
	if attack.hitting(state_time) and attack.active > 0.0:
		_lunge = facing * attack.lunge / attack.active
	if state_time >= attack.duration():
		_combo_grace_left = moveset.combo_grace if combo_index >= 0 else 0.0
		state_time = 0.0
		state = State.CHARGE if _holding and combo_index >= 0 and moveset.charged != null else State.FREE


func _charging(input: HeroInput, delta: float) -> void:
	state_time += delta
	if _buffered == Press.DASH and dash_charges > 0:
		_take(Press.DASH)
		_holding = false
		_start_dash(input, delta)
		return
	_walk(input.move, tuning.max_speed * tuning.charge_move_scale, delta)
	if input.aim.length() > 0.1:
		facing = input.aim.normalized()
	elif input.move.length() > 0.1:
		facing = input.move.normalized()
	if not _charge_announced and _hold_time >= moveset.charge_time:
		_charge_announced = true
		charge_ready.emit()
	if _holding:
		return
	if _hold_time >= moveset.charge_time:
		_start_swing(moveset.charged, -1, input.aim)
	else:
		state = State.FREE
		state_time = 0.0


func _dashing(delta: float) -> void:
	state_time += delta
	velocity = _dash_direction * tuning.dash_distance / tuning.dash_time
	if state_time >= tuning.dash_time:
		state = State.FREE
		state_time = 0.0
		since_dash = 0.0
		# She comes out of it running, not stopped dead.
		velocity = _dash_direction * tuning.max_speed


func _start_swing(next: AttackData, index: int, aim: Vector2) -> void:
	attack = next
	combo_index = index
	if aim.length() > 0.1:
		facing = aim.normalized()
	state = State.ATTACK
	state_time = 0.0
	swing_serial += 1
	swing_started.emit(attack)


func _start_dash(input: HeroInput, delta: float) -> void:
	_dash_direction = input.move.normalized() if input.move.length() > 0.1 else facing
	facing = _dash_direction
	dash_charges -= 1
	if _recharge_left <= 0.0:
		_recharge_left = tuning.dash_cooldown
	_invulnerable_left = tuning.dash_invulnerable
	_holding = false
	combo_index = -1
	state = State.DASH
	# The frame it starts on already carries her, so it counts.
	state_time = delta
	velocity = _dash_direction * tuning.dash_distance / tuning.dash_time
	dashed.emit(_dash_direction)


func _walk(move: Vector2, speed: float, delta: float) -> void:
	var target := move.limit_length(1.0) * speed
	var rate := tuning.acceleration if target.length() > 0.0 else tuning.deceleration
	velocity = velocity.move_toward(target, rate * delta)
