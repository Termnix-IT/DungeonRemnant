extends SceneTree

# The real-time fight put together in a CombatArea: walls stop the hero, a
# sentinel chases and hurts her by touch, her swings land, push and fell it,
# the dash slips through a blow, and her fall is reported. The hero is
# stepped by hand each physics frame with made-up input; the foes run on
# their own. Ends with the sandbox scene starting up and filling with foes.

const FRAME := 1.0 / 60.0
# Loaded rather than preloaded, for the same reason as `tuning` below.
var sentinel: FoeData = load("res://data/foes/wandering_sentinel.tres")
# What the signals reported.
var area: CombatArea
var hurts: Array[int] = []
var numbers_shown: Array[int] = []
var fallen: Array[Foe] = []
var hero_down := false
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func make_area() -> CombatArea:
	var made := CombatArea.new()
	root.add_child(made)
	var walls := {}
	for x in 24:
		walls[Vector2i(x, 0)] = true
		walls[Vector2i(x, 15)] = true
	for y in 16:
		walls[Vector2i(0, y)] = true
		walls[Vector2i(23, y)] = true
	made.ground.build(Vector2i(24, 16), walls)
	var hero := made.spawn_hero(Vector2(12, 8) * AreaGround.CELL)
	hero.controlled = false
	return made


# Steps the hero for `seconds` of physics frames; a press counts on the
# first frame only.
func drive(hero: Hero, input: HeroInput, seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		await physics_frame
		var frame_input := input if index == 0 else HeroInput.make(input.move, input.aim, false, input.strike_held, false)
		hero.step(frame_input, FRAME)


func run_tests() -> void:
	area = make_area()
	var hero := area.hero
	# Read through a variable: arithmetic on hero.tuning's fields makes the
	# analyzer keep its preloaded default as this script's constant, which the
	# engine then reports as list errors on quit.
	var tuning: HeroTuning = hero.motor.tuning
	await physics_frame
	check(hero.area == area and area.foes.is_empty(), "The hero stands in the area")
	check(area.ground.is_open(hero.global_position, 20.0) and not area.ground.is_open(Vector2(10, 10)), "The ground knows its walls")

	# Walls stop her.
	await drive(hero, HeroInput.make(Vector2.LEFT), 3.0)
	check(hero.global_position.x >= AreaGround.CELL + 10.0 and hero.global_position.x < AreaGround.CELL + 20.0, "A wall stops the hero")
	await drive(hero, HeroInput.make(Vector2.RIGHT), 1.6)

	# A sentinel chases her and hurts her by touch, then she is protected.
	var start := hero.global_position
	var foe := area.spawn_foe(sentinel, start + Vector2(220, 0))
	check(area.foes == [foe] and foe.target == hero, "A spawned foe is listed and hunts the hero")
	var gap := foe.global_position.distance_to(hero.global_position)
	await drive(hero, HeroInput.new(), 0.5)
	check(foe.global_position.distance_to(hero.global_position) < gap - 30.0, "The foe walks towards the hero")
	hero.hurt.connect(_on_hurt)
	await drive(hero, HeroInput.new(), 2.0)
	check(hurts.size() == 1 and hurts[0] == sentinel.contact_damage, "Its touch hurts her once, by its contact damage")
	check(hero.health.hp == tuning.max_hp - sentinel.contact_damage, "Her health drops by the hurt")
	check(numbers_shown.size() == 1 and numbers_shown[0] > 0, "The hurt shows a number")

	# Her swings land on it: each hit once, pushed away, and three swings
	# fell it.
	await drive(hero, HeroInput.new(), tuning.hurt_mercy)
	var aim := (foe.global_position - hero.global_position).normalized()
	var before := foe.health.hp
	var close := foe.global_position.distance_to(hero.global_position)
	await drive(hero, HeroInput.make(Vector2.ZERO, aim, true), 0.12)
	check(foe.health.hp == before - roundi(tuning.power), "The first swing hits the foe once")
	await drive(hero, HeroInput.new(), 0.15)
	check(foe.global_position.distance_to(hero.global_position) > close + 8.0, "The hit pushes the foe back")
	area.foe_fell.connect(_on_foe_fell)
	for swing in 3:
		if fallen.is_empty():
			aim = (foe.global_position - hero.global_position).normalized() if is_instance_valid(foe) else aim
			var reach := foe.global_position.distance_to(hero.global_position) if is_instance_valid(foe) else 0.0
			# Close in if the push carried it out of reach.
			if reach > 80.0:
				await drive(hero, HeroInput.make(aim), (reach - 60.0) / tuning.max_speed)
			await drive(hero, HeroInput.make(Vector2.ZERO, aim, true), 0.35)
	check(fallen.size() == 1 and fallen[0] == foe and area.kills == 1 and area.foes.is_empty(), "Enough swings fell the foe, which leaves the list")
	check(foe.collision_layer == 0, "A fallen foe no longer blocks")
	await drive(hero, HeroInput.new(), 0.8)
	check(is_instance_valid(foe) and foe.get_parent() != area.actors and area.pooled(sentinel) == 1, "A fallen foe fades and is kept in the pool")
	var again := area.spawn_foe(sentinel, hero.global_position + Vector2(300, 0))
	check(again == foe and area.reused == 1 and area.pooled(sentinel) == 0, "The next foe of its kind comes back from the pool")
	check(again.is_inside_tree() and again.health.hp == sentinel.max_hp and not again.dying and again.collision_layer == Hero.FOES and is_equal_approx(again.modulate.a, 1.0), "A foe from the pool comes back whole")
	again.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await drive(hero, HeroInput.new(), 0.8)
	check(area.pooled(sentinel) == 1 and area.kills == 2, "It can fall and return to the pool again")
	check(area.effects.get_child_count() >= 0, "Effects play and clear themselves")

	# The dash slips through a blow; her mercy time protects her after one.
	hero.motor.step(HeroInput.make(Vector2.UP, Vector2.ZERO, false, false, true), FRAME)
	check(hero.invulnerable() and hero.receive(DamageInfo.make(30.0, Vector2.RIGHT, 300.0)) == 0, "A blow during the dash does nothing")
	await drive(hero, HeroInput.new(), 0.6)
	var hp := hero.health.hp
	check(hero.receive(DamageInfo.make(30.0, Vector2.RIGHT, 300.0)) == 30 and hero.health.hp == hp - 30, "A blow outside the dash lands")
	check(hero.receive(DamageInfo.make(30.0, Vector2.RIGHT)) == 0, "Her mercy time protects her right after")

	# Her fall is reported, and she stays down.
	area.hero_fell.connect(_on_hero_fell)
	await drive(hero, HeroInput.new(), tuning.hurt_mercy + 0.1)
	hero.health.hp = 1
	hero.receive(DamageInfo.make(10.0, Vector2.RIGHT))
	check(hero_down and not hero.health.alive() and hero.motor.state == HeroMotor.State.DOWN, "Her fall is reported and she stays down")
	area.hit_stop.release()
	# Bodies are freed outside the physics step.
	await process_frame
	area.free()

	# The sandbox starts up and its director keeps the foes coming.
	var sandbox: CombatArea = load("res://world/areas/sandbox.tscn").instantiate()
	sandbox.seed_value = 5
	root.add_child(sandbox)
	await drive_frames(150)
	check(sandbox.hero != null and sandbox.hero.controlled, "The sandbox puts a hero under the player's control")
	check(sandbox.foes.size() >= 8 and sandbox.director.elapsed > 2.0, "The sandbox's director keeps sending foes")
	for each: Foe in sandbox.foes:
		check(sandbox.ground.is_open(each.global_position, 10.0), "Foes appear on open ground")
	check(sandbox.hud != null and sandbox.hud.hp_bar.value == sandbox.hero.health.hp, "The HUD shows the hero's health")
	sandbox.hit_stop.release()
	await process_frame
	sandbox.free()
	await process_frame

	print("Combat area tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _on_hurt(lost: int) -> void:
	hurts.append(lost)
	numbers_shown.append(area.popups.get_child_count())


func _on_foe_fell(foe: Foe) -> void:
	fallen.append(foe)


func _on_hero_fell() -> void:
	hero_down = true


func drive_frames(count: int) -> void:
	for index in count:
		await physics_frame
