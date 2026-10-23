class_name Hero
extends CharacterBody2D

# The hero in a CombatArea: reads the devices, steps her HeroMotor, moves by
# it, lands each swing on the foes its AttackData shape touches and sends
# off its wave, if it has one. With the run's BuildState she swings as the
# build shapes her swings, and her dashes, swings and skill are told to the
# area's CombatEvents for its triggers. Her special move's gauge fills from
# the fight (charge_special), and a full one lets it loose (the area stages
# it). What she looks like is HeroView's;
# what a hit looks like is the area's.

signal hurt(lost: int)
signal fell

# Physics layers shared by the real-time actors.
const WALLS := 1
const HEROES := 2
const FOES := 4
# The point aimed from: her middle, above the feet.
const AIM_ORIGIN := Vector2(0, -26)

# Set in hero.tscn, not preloaded here (see Foe.data).
@export var tuning: HeroTuning
@export var moveset: Moveset
# Off in tests, which step her with made-up HeroInput instead.
@export var controlled := true
var motor: HeroMotor
var health: Combatant
var hit_radius := 14.0
# The CombatArea she fights in: its foes, effects and hit stop.
var area: CombatArea
var view: HeroView
# The run's build; null fights as the data is written.
var build: BuildState
# The special move set (null: none) and how full its gauge is; the run's
# lasting rules fill the gauge faster (special_gain) and strike harder with
# it (special_power, added to its damage).
var special: SpecialData
var special_charge := 0.0
var special_gain := 1.0
var special_power := 0.0
var _impact_serial := -1
# Where she stood as the last physics frame began; her picture is drawn
# between it and where she stands (TickSmoothing).
var _tick_from := Vector2.ZERO
var _spent := {}
var _spent_serial := -1
var _launched_serial := -1
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
	motor.skill_used.connect(_on_skill_used)
	motor.special_used.connect(_on_special_used)
	motor.dashed.connect(_on_dashed)
	motor.dash_ended.connect(_on_dash_ended)
	motor.charge_ready.connect(_on_charge_ready)
	_tick_from = global_position


# Fights with the run's build from now on.
func use_build(run_build: BuildState) -> void:
	build = run_build
	motor.shaper = build.shape
	if area != null:
		build.bind(area, self)


func equip_special(move: SpecialData) -> void:
	special = move
	motor.special_attack = move.attack if move != null else null
	special_charge = minf(special_charge, move.charge) if move != null else 0.0


# How full the gauge is, 0 to 1.
func special_share() -> float:
	return clampf(special_charge / special.charge, 0.0, 1.0) if special != null else 0.0


func special_ready() -> bool:
	return special != null and special_charge >= special.charge


# The fight fills the gauge, never the special move's own blows.
func charge_special(amount: float) -> void:
	if special == null or amount <= 0.0 or using_special():
		return
	special_charge = minf(special.charge, special_charge + amount * special_gain)


func using_special() -> bool:
	return motor.combo_index == HeroMotor.SPECIAL and motor.state == HeroMotor.State.ATTACK


# Her strength before an attack's damage_scale: the build's damage stat adds
# to it.
func power() -> float:
	return tuning.power * (1.0 + (build.stat(&"damage") if build != null else 0.0))


func _physics_process(delta: float) -> void:
	if controlled:
		step(read_input(), delta)


# One physics frame: tests call it with their own input.
func step(input: HeroInput, delta: float) -> void:
	health.step(delta)
	if build != null:
		build.step(delta)
		motor.charge_scale = maxf(0.3, 1.0 + build.stat(&"charge_time"))
		motor.speed_scale = 1.0 + build.stat(&"move_speed")
		motor.cooldown_scale = maxf(0.3, 1.0 + build.stat(&"skill_cooldown"))
	motor.special_ready = special_ready()
	motor.step(input, delta)
	# She slips through foes while dashing, and is stopped by them otherwise.
	collision_mask = WALLS if motor.state == HeroMotor.State.DASH else WALLS | FOES
	velocity = motor.motion()
	_tick_from = global_position
	move_and_slide()
	_land_hits()


func _process(_delta: float) -> void:
	if view != null:
		view.position = TickSmoothing.lag(_tick_from, global_position)


# Where her picture stands this drawn frame (the camera follows it; worked
# out here, as the camera may move before her picture does).
func drawn_position() -> Vector2:
	return global_position + TickSmoothing.lag(_tick_from, global_position)


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
	input.skill_pressed = Input.is_action_just_pressed(&"skill_1")
	input.skill_2_pressed = Input.is_action_just_pressed(&"skill_2")
	input.special_pressed = Input.is_action_just_pressed(&"special")
	return input


# The mouse aims until a pad is touched, and the pad until the mouse moves.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_pad = false
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		_using_pad = true


# Whether she is being played on a gamepad now (the HUD shows its buttons).
func using_pad() -> bool:
	return _using_pad


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
	charge_special(lost * tuning.special_per_hurt)
	view.hurt()
	if area != null:
		area.report_hero_hurt(self, lost, info)
		area.events.damage_taken.emit(lost)
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
		area.events.swing_started.emit(attack)


func _on_skill_used(attack: AttackData) -> void:
	view.swing(attack)
	if area != null:
		area.report_swing(self, attack, motor.facing)
		area.events.skill_used.emit(attack)


func _on_special_used(attack: AttackData) -> void:
	special_charge = 0.0
	view.swing(attack)
	if area != null:
		area.report_special(self, special)
		area.report_swing(self, attack, motor.facing)
		area.events.special_used.emit(attack)


func _on_charge_ready() -> void:
	view.charge_ready()
	if area != null:
		area.report_charge_ready(self)


func _on_dashed(direction: Vector2) -> void:
	view.dash(direction)
	if area != null:
		area.report_dash(self, direction)
		area.events.dash_started.emit(direction)


func _on_dash_ended(direction: Vector2) -> void:
	if area != null:
		area.events.dash_ended.emit(direction)


func _land_hits() -> void:
	if area == null or not motor.hitting():
		return
	if motor.swing_serial != _spent_serial:
		_spent_serial = motor.swing_serial
		_spent.clear()
	var attack := motor.attack
	if attack.projectile != null and _launched_serial != motor.swing_serial:
		_launched_serial = motor.swing_serial
		area.launch(attack.projectile, global_position + AIM_ORIGIN * 0.5, motor.facing, power())
	var damage_scale := attack.damage_scale
	# The special move lands with a jolt of its own, once.
	if motor.combo_index == HeroMotor.SPECIAL:
		damage_scale *= 1.0 + special_power
		if _impact_serial != motor.swing_serial:
			_impact_serial = motor.swing_serial
			area.report_special_impact(self, attack)
	var found := HitQuery.targets(attack, global_position, motor.facing, area.foes, _spent)
	if found.is_empty():
		return
	for target: Node2D in found:
		_spent[target] = true
		var info := DamageInfo.make(power() * damage_scale, target.global_position - global_position, attack.knockback, self)
		info.hit_stop = attack.hit_stop
		info.element = attack.element
		info.inflicts = attack.inflicts
		area.deal(target, info)
	area.hit_stop.request(attack.hit_stop)
