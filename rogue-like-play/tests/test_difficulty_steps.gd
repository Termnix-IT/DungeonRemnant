extends SceneTree

# The difficulty steps: eight laid one on another, each adding one
# constraint and a tenth more echo; the last chapter's first clear (the
# ending) opening the first, and each clear of it at the highest step open
# opening the next; the record saved and read back; and each constraint
# reaching the run: fewer cards, smaller heals, a curse to set out with,
# larger crowds and waves, sooner and more elites, stronger kin in the
# crowd, tougher foes, a boss quicker to rage and calling more help. Step 0
# changes nothing.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func make_area(size: Vector2i) -> CombatArea:
	var area := CombatArea.new()
	root.add_child(area)
	var walls := {}
	for x in size.x:
		walls[Vector2i(x, 0)] = true
		walls[Vector2i(x, size.y - 1)] = true
	for y in size.y:
		walls[Vector2i(0, y)] = true
		walls[Vector2i(size.x - 1, y)] = true
	area.ground.build(size, walls)
	var hero := area.spawn_hero(area.ground.bounds().get_center())
	hero.controlled = false
	return area


func cleared(chapter: StringName, step: int) -> Dictionary:
	return {"cleared": true, "layer": 3, "chapter_id": String(chapter), "step": step}


func run_tests() -> void:
	# The steps themselves.
	check(DifficultySteps.ALL.size() == DifficultySteps.MAX and DifficultySteps.MAX == 8, "There are eight steps")
	check(DifficultySteps.ALL.all(func(step: DifficultyStep): return not step.summary.is_empty() and is_equal_approx(step.echo, 0.1)), "Each says what it adds and brings a tenth more echo")
	var none := DifficultySteps.combined(0)
	check(none.echo == 0.0 and none.crowd == 1.0 and none.heal == 1.0 and none.elite_pace == 1.0 and none.elite_cap == 0 and none.offers == 0 and none.foe_hp == 1.0 and not none.curse and none.kin == 0.0 and none.boss_rage == 0.0 and none.boss_summons == 1.0, "Step 0 changes nothing")
	var third := DifficultySteps.combined(3)
	check(is_equal_approx(third.crowd, 1.2) and is_equal_approx(third.heal, 0.75) and is_equal_approx(third.elite_pace, 0.7) and third.elite_cap == 1 and third.offers == 0 and third.foe_hp == 1.0, "Step 3 holds steps 1 to 3 and nothing above them")
	var top := DifficultySteps.combined(8)
	check(is_equal_approx(top.echo, 0.8) and top.offers == -1 and is_equal_approx(top.foe_hp, 1.25) and top.curse and is_equal_approx(top.kin, 0.2) and is_equal_approx(top.boss_rage, 0.2) and is_equal_approx(top.boss_summons, 1.5), "Step 8 holds every constraint")
	check(DifficultySteps.constraints(3).split("\n").size() == 3 and DifficultySteps.echo_text(3) == "残響 +30%", "The departure can list what is in play and the echo it brings")

	# Opening them: the last chapter's first clear, then a clear of it at the
	# highest step open.
	var meta := MetaProgress.new()
	var final: StringName = Chapters.ALL.back().id
	var first: StringName = Chapters.ALL[0].id
	check(meta.steps_open() == 0 and not meta.ending_seen(), "No step is open before the ending")
	meta.record_run(cleared(first, 0))
	check(meta.steps_open() == 0, "Clearing an earlier chapter opens none")
	meta.record_run(cleared(final, 0))
	check(meta.ending_seen() and meta.steps_open() == 1, "The last chapter's first clear is the ending, and opens step 1")
	meta.record_run({"cleared": false, "layer": 2, "chapter_id": String(final), "step": 1})
	check(meta.steps_open() == 1, "A run lost at the step opens nothing")
	meta.record_run(cleared(first, 1))
	check(meta.steps_open() == 1 and meta.step_of(first) == 1, "Clearing another chapter at the step is its record, and opens nothing")
	meta.record_run(cleared(final, 1))
	check(meta.steps_open() == 2 and meta.step_of(final) == 1, "Clearing the last chapter at the highest step open opens the next")
	meta.record_run(cleared(final, 0))
	check(meta.step_of(final) == 1, "A clear at a lower step keeps the record")
	check(Chapters.record(meta, Chapters.ALL.back()) == "踏破 3回・段階1" and Chapters.record(meta, Chapters.ALL[0]) == "踏破 2回・段階1", "A chapter's record names the highest step it was cleared at")
	meta.chapter_steps[final] = DifficultySteps.MAX
	check(meta.steps_open() == DifficultySteps.MAX, "The steps stop at the last")
	meta.chapter_steps[final] = 1

	# Saved and read back; a save from before the steps has none.
	var back := MetaCodec.decode(JSON.parse_string(JSON.stringify(MetaCodec.encode(meta))))
	check(back != null and back.step_of(final) == 1 and back.step_of(first) == 1 and back.steps_open() == 2, "The steps cleared at are saved and read back")
	var older := MetaCodec.encode(meta)
	for id: String in older.chapters:
		older.chapters[id].erase("step")
	var read := MetaCodec.decode(older)
	check(read != null and read.step_of(final) == 0 and read.steps_open() == 1, "A save from before the steps has cleared none at a step")
	var beyond := MetaCodec.encode(meta)
	beyond.chapters[String(final)]["step"] = DifficultySteps.MAX + 1
	check(MetaCodec.decode(beyond) == null, "A step past the last is refused")
	var unearned := MetaCodec.encode(MetaProgress.new())
	unearned.chapters = {String(final): {"clears": 0, "best": 2, "step": 1}}
	check(MetaCodec.decode(unearned) == null, "A step cleared at where the chapter was never cleared is refused")

	# The run's rules.
	var plain := RunState.new(5)
	plain.use_step(0)
	check(plain.offer_count() == BuildState.OFFER_COUNT and plain.card_count() == BuildState.OFFER_COUNT and plain.echo_reward(100) == 100 and plain.curses.is_empty(), "At step 0 a run is as it was")
	var fewer := RunState.new(5)
	fewer.use_step(4)
	check(fewer.offer_count() == BuildState.OFFER_COUNT - 1 and fewer.card_count() == BuildState.OFFER_COUNT - 1 and fewer.curses.is_empty(), "Step 4 takes a card from every offer")
	check(fewer.echo_reward(100) == 140, "Each step brings a tenth more echo")
	var cursed := RunState.new(5)
	var speed := cursed.tuning.max_speed
	var defense := cursed.tuning.defense
	cursed.use_step(6)
	check(cursed.curses.size() == 1 and RunState.CURSES.has(cursed.curses[0]), "Step 6 sets out carrying a curse")
	check(cursed.echo_reward(100) == roundi(100 * (1.0 + 0.6 + RunState.CURSE_ECHO)), "The curse raises the echo with the step")
	check(cursed.curses[0] != &"sluggish" or cursed.tuning.max_speed < speed, "Its harm reaches her tuning")
	check(cursed.curses[0] != &"frailty" or cursed.tuning.defense < defense, "Its harm reaches her tuning")

	# Crowds: larger and quicker, elites sooner and more, kin mixed in.
	var area := make_area(Vector2i(64, 44))
	await process_frame
	var field: AreaData = load("res://data/areas/moss_plain.tres")
	var director := EnemyDirector.new()
	area.add_child(director)
	var table := field.spawn_table
	director.start(area, table, 3)
	var usual_aim := director.target_alive()
	director.crowd = 1.2
	director.elite_pace = 0.7
	director.elite_extra = 1
	director.start(area, table, 3)
	check(director.target_alive() == roundi(usual_aim * 1.2), "Step 1's crowd is a fifth larger")
	check(is_equal_approx(director._next_elite, table.elite_first * 0.7), "Step 3's first elite comes sooner")
	var kin: Array[FoeData] = Chapters.ALL[0].kin
	check(kin.size() == 2 and kin.all(func(foe: FoeData): return foe.tint != Color.WHITE and FoeCatalog.FOES.has(foe)), "Each chapter has two stronger kin in their own colour, in the encyclopedia")
	director.kin = kin
	director.kin_share = 1.0
	check(kin.has(director.pick()), "Step 7 mixes the kin into the crowd")
	director.kin_share = 0.0
	check(not kin.has(director.pick()), "Below it, the crowd is the table's")
	director.free()
	# Waves a fifth larger.
	var arena: AreaData = load("res://data/areas/pillar_arena.tres")
	var runner := WaveRunner.new()
	area.marks.add_child(runner)
	runner.crowd = 1.2
	runner.start(area, arena.waves, 3)
	runner.advance(0.01)
	var base := arena.waves[0].order().size()
	check(runner._queue.size() == base + roundi(base * 0.2), "Step 1's waves are a fifth larger")
	runner.free()
	# Tougher foes, and a boss quicker to rage.
	var sentinel: FoeData = load("res://data/foes/wandering_sentinel.tres")
	var king: FoeData = load("res://data/foes/ruin_king.tres")
	var usual := area.spawn_foe(sentinel, area.hero.global_position + Vector2(300, 0))
	check(usual.health.max_hp == sentinel.max_hp and usual.rage_shift == 0.0, "At step 0 a foe is as its data")
	area.foe_hp = 1.25
	area.boss_rage = 0.2
	var tough := area.spawn_foe(sentinel, area.hero.global_position + Vector2(-300, 0))
	var boss := area.spawn_foe(king, area.hero.global_position + Vector2(0, 300))
	check(tough.health.max_hp == roundi(sentinel.max_hp * 1.25) and tough.rage_shift == 0.0, "Step 5's foes come in tougher")
	check(boss.health.max_hp == roundi(king.max_hp * 1.25) and is_equal_approx(boss.rage_shift, 0.2), "So does the boss, quicker to rage")
	boss.receive(DamageInfo.make(float(boss.health.max_hp) * 0.35, Vector2.UP))
	check(boss.phase == 2, "Step 8's boss rages at seven tenths of its health")
	area.free()
	await process_frame

	# A run at a step: what the map tells, the area's hold on its foes, the
	# heal reward, and the step handed back with the result.
	var director_run := RunDirector.new()
	director_run.seed_value = 12
	director_run.step = 8
	root.add_child(director_run)
	await process_frame
	check(director_run.run.step == 8 and director_run.run.curses.size() == 1, "The run is played at its step, carrying its curse")
	check(director_run.map_view._title.text.ends_with("段階8"), "The map names the step")
	director_run.map_view._choose(director_run.map_view.current[0])
	await process_frame
	var fight := director_run.area
	check(is_equal_approx(fight.foe_hp, 1.25) and is_equal_approx(fight.boss_rage, 0.2), "The area takes the step's hold on its foes")
	check(is_equal_approx(fight.director.crowd, 1.2) and is_equal_approx(fight.director.elite_pace, 0.7) and fight.director.elite_extra == 1 and fight.director.kin == director_run.chapter.kin and is_equal_approx(fight.director.kin_share, 0.2), "Its crowd takes the step's size, elites and kin")
	fight.hero.controlled = false
	director_run.finish(false, true)
	check(director_run.result.step == 8, "The result says the step")
	check(director_run.end_view._ending.text.contains("段階8"), "And so does the result screen")
	director_run.free()
	await process_frame
	var healing := RunDirector.new()
	healing.seed_value = 12
	healing.step = 2
	root.add_child(healing)
	await process_frame
	healing.run.hp = 10
	healing.waypoint = healing.run.route.nodes(0)[0]
	healing.grant(AreaData.Reward.HEAL)
	check(healing.run.hp == 10 + roundi(healing.max_hp() * RunDirector.HEAL_SHARE * 0.75), "Step 2's heal reward restores a quarter less")
	healing.free()
	await process_frame

	print("Difficulty step tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
