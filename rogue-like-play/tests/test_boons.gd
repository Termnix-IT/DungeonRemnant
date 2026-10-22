extends SceneTree

# The run's build: the eight boons and their data, the offer (requirements,
# last ranks, weights), the stats, how swings are shaped (never changing the
# data), the skill and the shortened charge, then each boon at work in a
# CombatArea (shock and its chain, burn and its spreading burst, the spin
# after a dash, the wave of the third swing), gems and levels, the sandbox's
# level-up pause, and a new run starting bare.

const FRAME := 1.0 / 60.0
var failures := 0
var checks := 0
var area: CombatArea
var hero: Hero
var sentinel: FoeData


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func boon(build: BuildState, id: StringName) -> BoonData:
	return build.find(id)


# A foe that stands still where it is put.
func still(offset: Vector2) -> Foe:
	var foe := area.spawn_foe(sentinel, hero.global_position + offset)
	foe.set_physics_process(false)
	return foe


# Steps the hero inside physics frames; a press counts on the first only.
func drive(input: HeroInput, seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		await physics_frame
		var frame_input := input if index == 0 else HeroInput.make(input.move, input.aim, false, input.strike_held, false, false)
		hero.step(frame_input, FRAME)


func clear_foes() -> void:
	for foe in area.foes.duplicate():
		foe.receive(DamageInfo.make(100000.0, Vector2.RIGHT))
	area.gems.clear()


func run_tests() -> void:
	sentinel = load("res://data/foes/wandering_sentinel.tres")
	var run := RunState.new(7)
	var build := run.build

	# The eight boons.
	var ids := {}
	for each in build.pool:
		ids[each.id] = true
		check(not each.display_name.is_empty() and not each.families.is_empty() and not each.effects.is_empty(), "A boon has a name, families and effects: " + String(each.id))
		check(EmblemIcons.texture(each.emblem_key()) != null, "A boon's emblem exists: " + String(each.id))
		check(each.effect_description(1).length() <= 20 and each.families.size() <= 2, "A boon's words and families fit its card: " + String(each.id))
	check(build.pool.size() == 8 and ids.size() == 8, "Eight boons, each its own id")

	# The offer: three different boons, requirements and last ranks respected.
	var offer := build.offer(run.rng)
	check(offer.size() == 3 and offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2], "An offer is three different boons")
	var never_chain := true
	for draw in 60:
		for each in build.offer(run.rng):
			if each.id == &"chain_lightning":
				never_chain = false
	check(never_chain, "Chain lightning is not offered before a lightning blade")
	check(build.take(boon(build, &"thunder_blade")) and build.rank(&"thunder_blade") == 1, "Taking a boon raises its rank")
	check(not build.take(boon(build, &"thunder_blade")), "A boon is not taken past its last rank")
	var chain_offered := false
	var blade_offered := false
	for draw in 60:
		for each in build.offer(run.rng):
			chain_offered = chain_offered or each.id == &"chain_lightning"
			blade_offered = blade_offered or each.id == &"thunder_blade"
	check(chain_offered and not blade_offered, "Once its need is held a boon is offered, and a full one no more")
	var first := RunState.new(99)
	var second := RunState.new(99)
	check(first.build.offer(first.rng) == second.build.offer(second.rng), "The same seed offers the same boons")

	# Stats.
	build.take(boon(build, &"blade_speed"))
	build.take(boon(build, &"blade_speed"))
	build.take(boon(build, &"great_charge"))
	check(is_equal_approx(build.stat(&"attack_speed"), 0.24) and is_equal_approx(build.stat(&"charge_time"), -0.15), "Stats add up by rank")

	# Shaping swings: copies changed, the data never.
	var moveset: Moveset = load("res://data/movesets/sword.tres")
	var swing: AttackData = moveset.combo[0]
	var shaped := build.shape(swing, &"combo", 0)
	check(shaped != swing and swing.inflicts.is_empty() and Status.SHOCK in shaped.inflicts, "A lightning blade shocks with a copy; the data is untouched")
	check(is_equal_approx(shaped.windup, swing.windup / 1.24) and is_equal_approx(shaped.recovery, swing.recovery / 1.24), "Blade speed shortens a combo swing")
	var skill := build.shape(moveset.skill, &"skill", HeroMotor.SKILL)
	check(Status.SHOCK in skill.inflicts and is_equal_approx(skill.windup, moveset.skill.windup), "The skill is shocked too but not quickened")
	var charged := build.shape(moveset.charged, &"charged", -1)
	check(is_equal_approx(charged.reach, moveset.charged.reach * 1.25) and charged.damage_scale > moveset.charged.damage_scale, "The great charge widens the charged attack")
	build.take(boon(build, &"afterimage"))
	check(is_equal_approx(build.shape(swing, &"combo", 0, 0.3).arc_degrees, 300.0), "Just after a dash a swing becomes the wide afterimage")
	check(is_equal_approx(build.shape(swing, &"combo", 0, 1.0).arc_degrees, swing.arc_degrees) and is_equal_approx(build.shape(swing, &"combo", 0).reach, swing.reach), "Long after a dash it is a plain swing")
	build.take(boon(build, &"shockwave"))
	check(build.shape(moveset.combo[2], &"combo", 2).projectile != null and build.shape(moveset.combo[1], &"combo", 1).projectile == null, "Only the third swing sends a wave")
	build.take(boon(build, &"shockwave"))
	var wave_data: ProjectileData = boon(build, &"shockwave").effects[0].projectile
	check(is_equal_approx(build.shape(moveset.combo[2], &"combo", 2).projectile.distance, wave_data.distance + 100.0) and is_equal_approx(wave_data.distance, 340.0), "A higher rank sends the wave farther; the data is untouched")

	# The motor: the skill, its cooldown, and a charge the build shortens.
	var motor := HeroMotor.new(load("res://data/hero/mio.tres"), moveset)
	var used := []
	motor.skill_used.connect(func(attack: AttackData): used.append(attack))
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.UP, false, false, false, true), FRAME)
	check(motor.state == HeroMotor.State.ATTACK and motor.combo_index == HeroMotor.SKILL and used.size() == 1, "Q lets the skill loose")
	check(is_equal_approx(motor.skill_cooldown_left, moveset.skill_cooldown), "The skill rests for its cooldown")
	for frame in 60:
		motor.step(HeroInput.new(), FRAME)
	motor.step(HeroInput.make(Vector2.ZERO, Vector2.UP, false, false, false, true), FRAME)
	check(used.size() == 1, "The skill cannot be used again while it rests")
	motor = HeroMotor.new(load("res://data/hero/mio.tres"), moveset)
	motor.charge_scale = 0.5
	for frame in roundi(moveset.charge_time * 0.5 / FRAME) + 2:
		motor.step(HeroInput.make(Vector2.ZERO, Vector2.RIGHT, frame == 0, true), FRAME)
	check(motor.charge_progress() == 1.0, "A charge shortened by the build is full sooner")

	# In a CombatArea: each boon at work.
	area = CombatArea.new()
	root.add_child(area)
	area.ground.build(Vector2i(40, 30), {})
	hero = area.spawn_hero(Vector2(20, 15) * AreaGround.CELL)
	hero.controlled = false
	run = RunState.new(3)
	hero.use_build(run.build)
	await process_frame
	var bare := hero.motor.shaper.call(moveset.combo[0], &"combo", 0, INF) as AttackData
	check(bare.inflicts.is_empty(), "A new run's build changes nothing")
	run.build.take(run.build.find(&"thunder_blade"))
	var target := still(Vector2(60, 0))
	await drive(HeroInput.make(Vector2.ZERO, Vector2.RIGHT, true), 0.15)
	check(target.has_status(Status.SHOCK), "A lightning blade's swing shocks its target")
	# Once its flinch is over it walks at its shocked pace.
	for frame in 40:
		await physics_frame
		target.step(FRAME)
	check(absf(target.walk.length() - target.speed * (1.0 - Status.SHOCK_SLOW)) < 1.0, "A shocked foe walks slower")
	# Its chain: a shocked foe's fall sends lightning to the foes near it.
	run.build.take(run.build.find(&"chain_lightning"))
	var near_a := still(Vector2(60, 140))
	var near_b := still(Vector2(160, 0))
	var far := still(Vector2(900, 0))
	await process_frame
	area.deal(target, DamageInfo.make(1000.0, Vector2.RIGHT))
	check(near_a.health.hp < sentinel.max_hp and near_b.health.hp < sentinel.max_hp, "Lightning chains from a shocked foe's fall to those near it")
	check(near_a.has_status(Status.SHOCK) and far.health.hp == sentinel.max_hp, "The chain shocks what it strikes and reaches no farther than its jumps")
	clear_foes()
	await drive(HeroInput.new(), 1.0)

	# Burn: ticks without a flinch, and a burning foe's fall bursts into fire.
	run.build.take(run.build.find(&"hellfire"))
	var burning := still(Vector2(70, 0))
	var beside := still(Vector2(110, 40))
	await drive(HeroInput.make(Vector2.ZERO, Vector2.RIGHT, true), 0.15)
	check(burning.has_status(Status.BURN), "Hellfire sets its target burning")
	var hp_before := burning.health.hp
	for frame in 40:
		await physics_frame
		burning.step(FRAME)
	check(burning.health.hp < hp_before and burning._stun_left <= 0.0, "A burn takes health over time without a flinch")
	beside.statuses.clear()
	beside.health = Combatant.new(1000)
	burning.apply_status(Status.BURN, 10.0)
	area.deal(burning, DamageInfo.make(1000.0, Vector2.RIGHT))
	check(beside.health.hp < 1000 and beside.has_status(Status.BURN), "A burning foe's fall bursts and spreads the fire")
	clear_foes()
	await drive(HeroInput.new(), 1.0)

	# The whirlwind after a dash.
	run.build.take(run.build.find(&"whirlwind"))
	# Where the dash down will end, a foe waits.
	var around := still(Vector2(40, hero.tuning.dash_distance + 20.0))
	var hp_around := around.health.hp
	await drive(HeroInput.make(Vector2.DOWN, Vector2.ZERO, false, false, true), 0.25)
	check(around.health.hp < hp_around, "A dash's end spins a blade around her")
	clear_foes()
	await drive(HeroInput.new(), 1.0)

	# The wave of the third swing reaches a foe out of the swing's reach.
	run.build.take(run.build.find(&"shockwave"))
	var distant := still(Vector2(260, 0))
	var hp_distant := distant.health.hp
	for swing_index in 3:
		await drive(HeroInput.make(Vector2.ZERO, Vector2.RIGHT, true), 0.14)
	await drive(HeroInput.new(), 0.6)
	check(distant.health.hp < hp_distant, "The third swing's wave strikes a foe far ahead")
	clear_foes()
	await drive(HeroInput.new(), 1.0)

	# Gems: a fall drops one; near her it flies in and brings a level.
	var levels := RunState.new(5)
	var gained := []
	area.gems.collected.connect(func(amount: int): gained.append(amount))
	area.gems.drop(hero.global_position + Vector2(400, 0), 3)
	area.gems.step(hero.global_position, FRAME)
	check(area.gems.count() == 1 and gained.is_empty(), "A gem beyond her pull stays put")
	area.gems.drop(hero.global_position + Vector2(60, 0), 5)
	for frame in 30:
		area.gems.step(hero.global_position, FRAME)
	check(gained == [5] and area.gems.count() == 1, "A gem within her pull flies to her and is collected")
	for index in GemField.MAX_GEMS + 20:
		area.gems.drop(Vector2(index, 0), 1)
	check(area.gems.count() == GemField.MAX_GEMS and area.gems.total() == 3 + GemField.MAX_GEMS + 20, "Past the cap, gems merge and none are lost")
	check(levels.gain(levels.progression.required_exp()) and levels.progression.pending_choices == 1, "Enough experience brings a level and a waiting choice")
	var picks := levels.next_offer()
	check(levels.choose(picks[0].id) and levels.progression.pending_choices == 0 and levels.build.rank(picks[0].id) == 1, "Choosing a card takes the boon and spends the choice")
	check(not levels.choose(picks[1].id), "Nothing is taken without a waiting choice")
	area.hit_stop.release()
	await process_frame
	area.free()
	await process_frame

	# The sandbox: a level pauses the world for the cards; a pick resumes it.
	var sandbox: CombatArea = load("res://world/areas/sandbox.tscn").instantiate()
	sandbox.seed_value = 8
	root.add_child(sandbox)
	await process_frame
	sandbox._on_gems(sandbox.run.progression.required_exp())
	await create_timer(BattleArea.LEAD_TIME + 0.05, true, false, true).timeout
	check(paused and sandbox.choosing(), "A level-up pauses the fight and shows the cards")
	sandbox.choice._select(0)
	check(not paused and not sandbox.choosing() and sandbox.run.build.owned().size() == 1, "Picking a card takes the boon and resumes the fight")
	sandbox.hit_stop.release()
	await process_frame
	sandbox.free()
	await process_frame
	check(RunState.new().build.owned().is_empty() and RunState.new().progression.level == 1, "A new run starts with no boons at level 1")
	print("Boon tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

