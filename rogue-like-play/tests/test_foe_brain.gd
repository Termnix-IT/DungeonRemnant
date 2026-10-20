extends SceneTree

# Foes' attacks and minds, stepped by hand at 60 Hz (their own physics is
# off): the dashing rat's pounce with its warning on the floor, a hit
# breaking off its wind-up, a dash making the pounce miss for good; the
# raging charger choosing its slam up close and its charge from afar,
# chasing beyond both, and holding its wind-up through hits (super
# armour); a plain sentinel that never attacks; and thinking less often
# off screen.

const FRAME := 1.0 / 60.0
var failures := 0
var checks := 0
var area: CombatArea
var hero: Hero


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func spawn(data: FoeData, offset: Vector2) -> Foe:
	var foe := area.spawn_foe(data, hero.global_position + offset)
	foe.set_physics_process(false)
	foe.brain.cooldown = 0.0
	return foe


# Steps inside physics frames, where its moves take effect.
func run(foe: Foe, seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		await physics_frame
		foe.step(FRAME)


# Steps until it starts an attack (a crowd's foes think on staggered
# frames), at most a few frames.
func until_attack(foe: Foe) -> void:
	for index in Foe.FAR_THINK_FRAMES + 1:
		await physics_frame
		foe.step(FRAME)
		if foe.attack != null:
			return


# Whole again and out of any dash (she is not stepped here, so a dash's
# untouchable time would never run out).
func fresh_hero() -> void:
	hero.health = Combatant.new(100, 0, 0.8)
	hero.motor = HeroMotor.new(hero.motor.tuning, hero.motor.moveset)


func run_tests() -> void:
	var rat: FoeData = load("res://data/foes/dashing_rat.tres")
	var charger: FoeData = load("res://data/foes/raging_charger.tres")
	var sentinel: FoeData = load("res://data/foes/wandering_sentinel.tres")
	area = CombatArea.new()
	root.add_child(area)
	area.ground.build(Vector2i(40, 30), {})
	hero = area.spawn_hero(Vector2(20, 15) * AreaGround.CELL)
	hero.controlled = false
	await process_frame

	# The rat's pounce: chosen in its range, warned of, then a leap that lands once.
	var pounce: AttackData = rat.attacks[0]
	var foe := spawn(rat, Vector2(120, 0))
	await until_attack(foe)
	check(foe.attack == pounce and foe.telegraph != null and foe.telegraph.get_parent() == area.marks, "In range, the rat starts its pounce and its warning goes down")
	var start := foe.global_position
	await run(foe, pounce.windup * 0.5)
	check(foe.telegraph.progress > 0.3 and foe.telegraph.progress < 0.7, "The warning fills as the wind-up runs")
	check(foe.global_position.distance_to(start) < 4.0, "It holds still while winding up")
	var warning := foe.telegraph
	var hp := hero.health.hp
	await run(foe, pounce.windup * 0.5 + pounce.active)
	check(foe.telegraph == null and is_instance_valid(warning) and warning._struck, "The warning flashes when the blow comes")
	check(foe.global_position.distance_to(hero.global_position) < 120.0 - 40.0, "The pounce carries it at her")
	check(hero.health.hp == hp - roundi(rat.power * pounce.damage_scale), "The pounce lands once, for its damage")
	await run(foe, pounce.recovery + FRAME * 2.0)
	check(foe.attack == null and foe.brain.cooldown > rat.attack_cooldown - 0.1, "After the attack, the cooldown starts")
	foe.receive(DamageInfo.make(1000.0, Vector2.RIGHT))

	# A hit during the wind-up breaks it off.
	fresh_hero()
	foe = spawn(rat, Vector2(-130, 0))
	await until_attack(foe)
	warning = foe.telegraph
	await run(foe, 0.1)
	foe.receive(DamageInfo.make(1.0, Vector2.LEFT, 100.0))
	check(foe.attack == null and foe.telegraph == null and warning.is_queued_for_deletion(), "A hit breaks off the wind-up and its warning")
	hp = hero.health.hp
	await run(foe, 0.6)
	check(hero.health.hp == hp, "A broken-off pounce does no harm")
	foe.receive(DamageInfo.make(1000.0, Vector2.RIGHT))

	# A dash through the pounce makes it miss for good.
	fresh_hero()
	foe = spawn(rat, Vector2(0, 120))
	await until_attack(foe)
	await run(foe, pounce.windup - FRAME * 2.0)
	hero.motor.step(HeroInput.make(Vector2.ZERO, Vector2.ZERO, false, false, true), FRAME)
	hp = hero.health.hp
	await run(foe, pounce.active + pounce.recovery)
	check(hero.health.hp == hp, "A pounce met by a dash misses")
	foe.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await process_frame

	# The charger: its slam up close, its charge from afar, a chase beyond.
	fresh_hero()
	var slam: AttackData = charger.attacks[0]
	var charge: AttackData = charger.attacks[1]
	foe = spawn(charger, Vector2(80, 0))
	await until_attack(foe)
	check(foe.attack == slam, "Up close the charger slams")
	await run(foe, slam.windup * 0.5)
	foe.receive(DamageInfo.make(30.0, Vector2.RIGHT, 100.0))
	check(foe.attack == slam and foe.telegraph != null, "Its super armour holds the wind-up through a hit")
	hp = hero.health.hp
	await run(foe, slam.windup * 0.5 + slam.active)
	check(hero.health.hp == hp - roundi(charger.power * slam.damage_scale), "The slam lands on her within its circle")
	foe.receive(DamageInfo.make(10000.0, Vector2.RIGHT))
	fresh_hero()
	foe = spawn(charger, Vector2(-300, 0))
	await until_attack(foe)
	check(foe.attack == charge and foe.telegraph.attack.shape == AttackData.Shape.LINE, "From afar the charger charges, warned by a lane")
	start = foe.global_position
	hp = hero.health.hp
	await run(foe, charge.windup + charge.active)
	check(foe.global_position.x > start.x + 150.0, "The charge carries it at her")
	check(hero.health.hp == hp - roundi(charger.power * charge.damage_scale), "The charge runs her down once")
	foe.receive(DamageInfo.make(10000.0, Vector2.RIGHT))
	foe = spawn(charger, Vector2(0, -600))
	start = foe.global_position
	await run(foe, 0.5)
	check(foe.attack == null and foe.global_position.y > start.y + 15.0, "Beyond both ranges it walks towards her")
	foe.receive(DamageInfo.make(10000.0, Vector2.RIGHT))

	# A sentinel only chases.
	foe = spawn(sentinel, Vector2(100, 0))
	await run(foe, 1.0)
	check(foe.attack == null and area.marks.get_child_count() == 0 or foe.attack == null, "A sentinel never attacks")

	# Off screen, a foe thinks every few frames but loses no time over it.
	foe.brain.cooldown = 1.0
	foe.on_screen = false
	await run(foe, 0.5)
	check(absf(foe.brain.cooldown - 0.5) <= Foe.FAR_THINK_FRAMES * FRAME + 0.001, "Thinking less often off screen still counts all the time passed")
	foe.receive(DamageInfo.make(10000.0, Vector2.RIGHT))

	area.hit_stop.release()
	await process_frame
	area.free()
	await process_frame
	print("Foe brain tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
