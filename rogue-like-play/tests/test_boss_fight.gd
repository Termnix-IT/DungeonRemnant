extends SceneTree

# The boss hall: the boss coming in on its mark with its health across the
# top, its attacks and the way it picks them, its second phase (quicker, a
# wider quake, its summons on marks), and its fall winning the hall (its
# escort leaving).

const FRAME := 1.0 / 60.0
var failures := 0
var checks := 0
var phases: Array = []


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func wait(seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		await physics_frame


func _on_phase(foe: Foe) -> void:
	phases.append(foe)


func run_tests() -> void:
	var hall: AreaData = load("res://data/areas/guardian_hall.tres")
	var king: FoeData = load("res://data/foes/ruin_king.tres")
	var rat: FoeData = load("res://data/foes/dashing_rat.tres")
	check(hall.kind == AreaData.Kind.BOSS and hall.boss == king and king.boss, "The boss hall holds its boss")
	check(king.attacks.size() == 3 and king.phase_two_attacks.size() == 1 and king.phase_two_at == 0.5, "Three attacks, a fourth in the second phase at half health")
	var covered := true
	for distance in range(0, 600, 10):
		if not king.attacks.any(func(attack: AttackData): return distance >= attack.use_from and distance <= attack.use_until):
			covered = false
	check(covered, "At any distance up to its charge's reach the boss has an attack")

	var run := RunState.new(9)
	var area := BattleArea.new()
	area.setup(hall, run, 9)
	root.add_child(area)
	await process_frame
	area.hero.controlled = false
	area.hero.health.max_hp = 100000
	area.hero.health.hp = 100000
	check(area.objective_text() == "遺跡王を倒す" and area.boss_foe == null, "The goal names the boss, who is not in yet")
	await wait(BattleArea.BOSS_DELAY + BattleArea.BOSS_MARK_TIME + 0.2)
	var boss := area.boss_foe
	check(boss != null and boss.data == king and area.foes.has(boss), "The boss comes in on its mark")
	check(boss.global_position.y < area.hero.global_position.y, "It comes in above her, across the hall")
	var intro: BossIntro = area.get_node_or_null("BossIntro")
	check(intro != null and intro._name.text == "遺跡王" and intro._epithet.text == king.epithet and not king.epithet.is_empty(), "It names itself as it arrives, its epithet over its name")
	check(not paused, "The fight does not wait for its name")
	await process_frame
	check(area.hud.boss_gauge.visible and area.hud.boss_gauge.bar.value == king.max_hp, "Its health shows across the top")
	check(not area.is_clear(), "The hall is not won while it stands")
	await wait(BossIntro.BAR_TIME + BossIntro.NAME_TIME + BossIntro.HOLD_TIME + BossIntro.OUT_TIME + 0.3)
	check(area.get_node_or_null("BossIntro") == null, "The nameplate leaves by itself")

	# The way it picks: at random among the attacks that fit.
	var picked := {}
	boss.set_physics_process(false)
	for draw in 60:
		boss.attack = null
		boss.brain.cooldown = 0.0
		boss.global_position = area.hero.global_position + Vector2(0, -120)
		boss.brain.step(boss, FRAME)
		if boss.attack != null:
			picked[boss.attack] = true
		boss._cancel_attack()
	check(picked.size() == 2 and picked.has(king.attacks[0]) and picked.has(king.attacks[2]), "Close up it picks between its sweep and its quake")
	boss.set_physics_process(true)

	# The second phase.
	boss.phase_changed.connect(_on_phase)
	var speed := boss.speed
	var rats_before := area.foes.filter(func(foe: Foe): return foe.data == rat).size()
	boss.receive(DamageInfo.make(king.max_hp * 0.3, Vector2.UP))
	check(boss.phase == 1 and phases.is_empty(), "Above half health it keeps its first phase")
	boss.receive(DamageInfo.make(king.max_hp * 0.25, Vector2.UP))
	check(boss.phase == 2 and phases == [boss], "At half health it enters its second phase")
	check(is_equal_approx(boss.speed, speed * king.phase_two_speed) and boss.attack_list().size() == 4, "It quickens and gains its wide quake")
	await wait(WaveRunner.MARK_TIME + 0.2)
	var rats := area.foes.filter(func(foe: Foe): return foe.data == rat).size()
	check(rats - rats_before == king.summon_count, "Its summons come in on their marks")
	boss.receive(DamageInfo.make(king.max_hp * 0.1, Vector2.UP))
	check(phases.size() == 1, "The second phase comes once")

	# Its fall wins the hall.
	var won := [false]
	area.cleared.connect(func(): won[0] = true)
	boss.receive(DamageInfo.make(100000.0, Vector2.UP))
	await wait(0.1)
	check(area.boss_down and area.finished and area.foes.is_empty(), "Its fall wins the hall and its escort leaves")
	# The boss's gems may bring a level: its cards pause the clearing.
	for attempt in 3:
		await wait(BattleArea.CLEAR_PAUSE * 0.5)
		while area.choosing():
			area.choice._select(0)
			await process_frame
	await wait(BattleArea.CLEAR_PAUSE)
	check(won[0], "The hall reports its clearing")
	await process_frame
	check(not area.hud.boss_gauge.visible, "Its gauge goes")
	area.hit_stop.release()
	await process_frame
	area.free()
	await process_frame
	print("Boss fight tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
