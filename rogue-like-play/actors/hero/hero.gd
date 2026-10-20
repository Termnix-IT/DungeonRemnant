class_name Hero
extends CharacterBody2D

# The hero in a CombatArea: reads the devices, steps her HeroMotor, moves by
# it, and lands each swing on the foes its AttackData shape touches. What she
# looks like is HeroView's; what a hit looks like is the area's.

signal hurt(lost: int)
signal fell

# Physics layers shared by the real-time actors.
const WALLS := 1
const HEROES := 2
const FOES := 4
# The point aimed from: her middle, above the feet.
const AIM_ORIGIN := Vector2(0, -26)

@export var tuning: HeroTuning = preload("res://data/hero/mio.tres")
@export var moveset: Moveset = preload("res://data/movesets/sword.tres")
# Off in tests, which step her with made-up HeroInput instead.
@export var controlled := true
var motor: HeroMotor
var health: Combatant
var hit_radius := 14.0
# The CombatArea she fights in: its foes, effects and hit stop.
var area: CombatArea
var view: HeroView
var _spent := {}
var _spent_serial := -1
var _using_pad := false


func _ready() -> void:
	motor = HeroMotor.new(tuning, moveset)
	health = Combatant.new(tuning.max_hp, tuning.defense, tuning.hurt_mercy)
	hit_radius = tuning.hit_radius
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = HEROES
	collision_mask = WALLS | FOES
	# Drawn over the foes' y-sort, so a crowd around her never hides her.
	z_index = 1
	view = HeroView.new()
	view.name = "View"
	add_child(view)
	view.setup(self)
	motor.swing_started.connect(_on_swing_started)
	motor.dashed.connect(func(_direction: Vector2): view.dash())
	motor.charge_ready.connect(view.charge_ready)


func _physics_process(delta: float) -> void:
	if controlled:
		step(read_input(), delta)


# One physics frame: tests call it with their own input.
func step(input: HeroInput, delta: float) -> void:
	health.step(delta)
	motor.step(input, delta)
	# She slips through foes while dashing, and is stopped by them otherwise.
	collision_mask = WALLS if motor.state == HeroMotor.State.DASH else WALLS | FOES
	velocity = motor.motion()
	move_and_slide()
	_land_hits()


func read_input() -> HeroInput:
	var input := HeroInput.new()
	input.move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick.length() > 0.3:
		_using_pad = true
		input.aim = stick.normalized()
	elif _using_pad:
		input.aim = input.move.normalized()
	else:
		input.aim = (get_global_mouse_position() - (global_position + AIM_ORIGIN)).normalized()
	input.strike_pressed = Input.is_action_just_pressed(&"strike")
	input.strike_held = Input.is_action_pressed(&"strike")
	input.dash_pressed = Input.is_action_just_pressed(&"dash")
	return input


# The mouse aims until a pad is touched, and the pad until the mouse moves.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_pad = false
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		_using_pad = true


func invulnerable() -> bool:
	return motor.invulnerable() or health.protected()


# A blow from a foe; the health lost (0 if dodged or still protected).
func receive(info: DamageInfo) -> int:
	if not health.alive() or invulnerable():
		return 0
	var lost := health.take(info)
	if lost <= 0:
		return 0
	motor.push(info.direction * info.knockback)
	view.hurt()
	if area != null:
		area.report_hero_hurt(self, lost, info)
	hurt.emit(lost)
	if not health.alive():
		motor.fall()
		view.fall()
		fell.emit()
	return lost


func _on_swing_started(attack: AttackData) -> void:
	view.swing(attack)
	if area != null:
		area.report_swing(self, attack, motor.facing)


func _land_hits() -> void:
	if area == null or not motor.hitting():
		return
	if motor.swing_serial != _spent_serial:
		_spent_serial = motor.swing_serial
		_spent.clear()
	var attack := motor.attack
	var found := HitQuery.targets(attack, global_position, motor.facing, area.foes, _spent)
	if found.is_empty():
		return
	for target: Node2D in found:
		_spent[target] = true
		var info := DamageInfo.make(tuning.power * attack.damage_scale, target.global_position - global_position, attack.knockback, self)
		info.hit_stop = attack.hit_stop
		info.element = attack.element
		var lost: int = target.receive(info)
		area.report_hit(target, lost, info)
	area.hit_stop.request(attack.hit_stop)
