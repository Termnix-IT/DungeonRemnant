extends SceneTree

# The hero's real-time rules (HeroMotor), stepped at a fixed 60 Hz with
# made-up input: walking, the dash and its untouchable time, the combo and
# its buffer, cancels, the charge, and falling.

const FRAME := 1.0 / 60.0
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func make_motor() -> HeroMotor:
	return HeroMotor.new(preload("res://data/hero/mio.tres"), preload("res://data/movesets/sword.tres"))


# Steps for `seconds` with `input`; a press in it counts on the first frame
# only, a hold on every frame. Returns how far motion() carried her.
func hold(motor: HeroMotor, input: HeroInput, seconds: float) -> Vector2:
	var travelled := Vector2.ZERO
	var frames := roundi(seconds / FRAME)
	for index in frames:
		var frame_input := input
		if index > 0:
			frame_input = HeroInput.make(input.move, input.aim, false, input.strike_held, false)
		motor.step(frame_input, FRAME)
		travelled += motor.motion() * FRAME
	return travelled


func idle() -> HeroInput:
	return HeroInput.new()


func run_tests() -> void:
	var tuning: HeroTuning = preload("res://data/hero/mio.tres")
	var moveset: Moveset = preload("res://data/movesets/sword.tres")
	check(moveset.combo.size() == 3 and moveset.charged != null, "The sword has a three-swing combo and a charged attack")

	# Walking has weight both ways but reaches full speed quickly.
	var motor := make_motor()
	hold(motor, HeroInput.make(Vector2.RIGHT), 0.05)
	check(motor.velocity.x > 0.0 and motor.velocity.x < tuning.max_speed, "Walking speeds up over a few frames")
	hold(motor, HeroInput.make(Vector2.RIGHT), 0.15)
	check(is_equal_approx(motor.velocity.x, tuning.max_speed), "Walking reaches full speed")
	check(motor.facing == Vector2.RIGHT, "Walking turns her the way she goes")
	hold(motor, idle(), 0.2)
	check(motor.velocity.is_zero_approx(), "Letting go stops her")
	hold(motor, HeroInput.make(Vector2(1, 1) * 3.0), 0.3)
	check(motor.velocity.length() <= tuning.max_speed + 0.01, "A stick pushed past its edge does not walk faster")

	# The dash: its distance, untouchable time and cooldown.
	motor = make_motor()
	motor.step(HeroInput.make(Vector2.UP, Vector2.ZERO, false, false, true), FRAME)
	check(motor.state == HeroMotor.State.DASH and motor.invulnerable(), "A dash starts at once and makes her untouchable")
	check(motor.dash_charges == 0, "A dash spends its charge")
	var dashed := motor.motion() * FRAME + hold(motor, HeroInput.make(Vector2.UP), tuning.dash_time)
	check(motor.state == HeroMotor.State.FREE, "The dash ends after its time")
	check(absf(dashed.length() - tuning.dash_distance) < 20.0 and dashed.y < 0.0, "The dash carries her its distance the way she pressed")
	hold(motor, idle(), tuning.dash_invulnerable - tuning.dash_time - FRAME * 2.0)
	check(motor.invulnerable(), "The untouchable time runs a little past the dash")
	hold(motor, idle(), FRAME * 4.0)
	check(not motor.invulnerable(), "The untouchable time ends")
	motor.step(HeroInput.make(Vector2.RIGHT, Vector2.ZERO, false, false, true), FRAME)
	check(motor.state != HeroMotor.State.DASH, "No dash while its charge is coming back")
	hold(motor, idle(), tuning.dash_cooldown)
	check(motor.dash_charges == 1, "The charge comes back after the cooldown")
	check(motor.state == HeroMotor.State.FREE, "A dash pressed too early is not kept past the buffer")
	motor = make_motor()
	hold(motor, idle(), 0.1)
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.ZERO, false, false, true), FRAME)
	check(motor.state == HeroMotor.State.DASH and motor.motion().x > 0.0, "Standing still, she dashes the way she faces")

	# The combo: a press starts a swing, a press during it is kept and starts
	# the next one at combo_after.
	motor = make_motor()
	var swings := []
	motor.swing_started.connect(func(attack: AttackData): swings.append(attack))
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.UP, true), FRAME)
	check(motor.state == HeroMotor.State.ATTACK and motor.combo_index == 0 and swings.size() == 1, "A strike starts the first swing at once")
	check(motor.facing == Vector2.UP, "The swing faces the aim")
	var first: AttackData = moveset.combo[0]
	check(not motor.hitting(), "The swing does not hit during its wind-up")
	hold(motor, idle(), first.windup)
	check(motor.hitting(), "The swing hits once its wind-up is over")
	hold(motor, idle(), first.active + FRAME)
	check(not motor.hitting(), "The swing stops hitting after its active time")
	motor = make_motor()
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.RIGHT, true), FRAME)
	hold(motor, idle(), 0.03)
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.LEFT, true), FRAME)
	check(motor.combo_index == 0, "A press early in a swing waits")
	hold(motor, idle(), first.combo_after)
	check(motor.combo_index == 1 and motor.swing_serial == 2, "The waiting press starts the second swing")
	check(motor.facing == Vector2.LEFT or motor.facing == Vector2.RIGHT, "The second swing keeps a facing")
	var second: AttackData = moveset.combo[1]
	hold(motor, idle(), second.combo_after)
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.ZERO, true), FRAME)
	check(motor.combo_index == 2, "A press after combo_after starts the third swing at once")
	var third: AttackData = moveset.combo[2]
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.ZERO, true), FRAME)
	hold(motor, idle(), third.duration() + 0.05)
	check(motor.state == HeroMotor.State.FREE and motor.swing_serial == 3, "A press after the last swing is dropped once the buffer runs out")
	hold(motor, idle(), moveset.combo_grace)
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.ZERO, true), FRAME)
	check(motor.combo_index == 0, "Once the grace has passed, the combo starts over")
	hold(motor, idle(), first.duration())
	hold(motor, idle(), moveset.combo_grace * 0.5)
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.ZERO, true), FRAME)
	check(motor.combo_index == 1, "A press within the grace after a swing continues the combo")

	# Walking slows while swinging, and the swing lunges forward.
	motor = make_motor()
	motor.step(HeroInput.make(Vector2.DOWN, Vector2.RIGHT, true), FRAME)
	var lunge := hold(motor, HeroInput.make(Vector2.DOWN), first.windup + first.active)
	check(lunge.x > first.lunge * 0.5, "The swing carries her forward")
	check(motor.velocity.length() <= tuning.max_speed * first.move_scale + 0.01, "She walks slowly while swinging")

	# A dash cuts a swing short only from dash_after on.
	motor = make_motor()
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.RIGHT, true), FRAME)
	motor.step(HeroInput.make(Vector2.UP, Vector2.ZERO, false, false, true), FRAME)
	check(motor.state == HeroMotor.State.ATTACK, "A dash early in a swing waits")
	hold(motor, HeroInput.make(Vector2.UP), first.dash_after)
	check(motor.state == HeroMotor.State.DASH, "The waiting dash cuts the swing short")

	# A strike pressed during a dash comes out when it ends.
	motor = make_motor()
	motor.step(HeroInput.make(Vector2.RIGHT, Vector2.ZERO, false, false, true), FRAME)
	hold(motor, idle(), 0.08)
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.ZERO, true), FRAME)
	check(motor.state == HeroMotor.State.DASH, "A strike does not cut a dash")
	hold(motor, idle(), tuning.dash_time)
	check(motor.state == HeroMotor.State.ATTACK and motor.combo_index == 0, "The strike pressed during the dash comes out after it")
	check(motor.since_dash < 0.2, "The time since the dash is counted")

	# The charge: held past the swing it charges; released early it ends,
	# released after charge_time it lets loose the charged attack.
	motor = make_motor()
	var ready := [false]
	motor.charge_ready.connect(func(): ready[0] = true)
	hold(motor, HeroInput.make(Vector2.ZERO, Vector2.RIGHT, true, true), first.duration() + FRAME * 2.0)
	check(motor.state == HeroMotor.State.CHARGE, "Holding the strike past the swing starts a charge")
	check(motor.charge_progress() > 0.3 and motor.charge_progress() < 1.0, "The charge is counted from the press")
	motor.step(idle(), FRAME)
	check(motor.state == HeroMotor.State.FREE and motor.swing_serial == 1 and not ready[0], "Released early, the charge ends with nothing")
	motor = make_motor()
	motor.charge_ready.connect(func(): ready[0] = true)
	hold(motor, HeroInput.make(Vector2.ZERO, Vector2.RIGHT, true, true), moveset.charge_time + FRAME * 2.0)
	check(ready[0] and motor.charge_progress() == 1.0, "A full charge is announced")
	hold(motor, HeroInput.make(Vector2.RIGHT, Vector2.ZERO, false, true), 0.1)
	check(motor.velocity.length() <= tuning.max_speed * tuning.charge_move_scale + 0.01, "She walks slowly while charging")
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.UP), FRAME)
	check(motor.state == HeroMotor.State.ATTACK and motor.attack == moveset.charged and motor.combo_index == -1, "Released when full, the charged attack comes out")
	check(motor.facing == Vector2.UP, "The charged attack faces the aim")
	motor = make_motor()
	hold(motor, HeroInput.make(Vector2.ZERO, Vector2.RIGHT, true, true), first.duration() + 0.1)
	motor.step(HeroInput.make(Vector2.LEFT, Vector2.ZERO, false, true, true), FRAME)
	check(motor.state == HeroMotor.State.DASH and motor.charge_progress() == 0.0, "A dash drops a charge at once")

	# A push from a blow carries her and dies away; a fallen hero stays down.
	motor = make_motor()
	motor.push(Vector2(400, 0))
	check(motor.motion().x > 300.0, "A push moves her")
	hold(motor, idle(), 1.0)
	check(motor.motion().is_zero_approx(), "A push dies away")
	motor.fall()
	hold(motor, HeroInput.make(Vector2.RIGHT, Vector2.RIGHT, true, false, true), 0.3)
	check(motor.state == HeroMotor.State.DOWN and motor.motion().is_zero_approx() and motor.swing_serial == 0, "A fallen hero does not move, swing or dash")

	# Two skill slots: each answers its own key and rests on its own.
	motor = make_motor()
	var slam: SkillData = load("res://data/skills/slam.tres")
	check(motor.skill_attacks[0] == motor.moveset.skill and motor.skill_attacks[1] == null, "Unset, the moveset's skill fills the first slot")
	motor.equip_skills([null, slam])
	var first_key := HeroInput.make()
	first_key.skill_pressed = true
	hold(motor, first_key, 0.1)
	check(motor.swing_serial == 0, "An empty slot's key does nothing")
	var other := HeroInput.make()
	other.skill_2_pressed = true
	hold(motor, other, 0.1)
	check(motor.swing_serial == 1 and motor.combo_index == HeroMotor.SKILL and absf(motor.skill_cooldowns_left[1] - (slam.cooldown - 0.1)) < 0.05 and motor.skill_cooldown_left == 0.0, "The second slot's key lets its skill loose, and only it rests")
	check(motor.skill_emblems[1] == slam.emblem, "The slot keeps its skill's emblem for the HUD")

	print("Hero motor tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
