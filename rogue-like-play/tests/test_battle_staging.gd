extends SceneTree

# The fight's staging: what is shown round the rules without touching them.
# Every theme's place stands on what its data says stops her; she arrives
# out of the dark and the fight is on at once; a level slows the world for a
# beat, stops it for the cards (dealt face down, turned over, armed) and
# lets it go, however many levels come at once; a boss is foretold, staged
# with the world stopped, enraged and felled with the world slowed for a
# moment each time and never left slow; her own fall closes the dark round
# her; and what follows an area comes up out of the dark. The staged
# slow-downs run on the real clock, so they are waited for on it.

const FRAME := 1.0 / 60.0
const Choice := preload("res://ui/ability_choice.gd")
var failures := 0
var checks := 0


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


# Real seconds, whatever the world's pace and whether it is stopped.
func real(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func enter(area_name: String, run: RunState) -> BattleArea:
	return enter_into(load("res://data/areas/%s.tres" % area_name), run)


func enter_into(data: AreaData, run: RunState) -> BattleArea:
	var area := BattleArea.new()
	area.setup(data, run, 9)
	root.add_child(area)
	area.hero.controlled = false
	return area


func leave(area: BattleArea) -> void:
	area.hit_stop.release()
	paused = false
	area.free()
	await process_frame


func run_tests() -> void:
	await _places()
	await _arrival_and_leaving()
	await _levels()
	await _boss()
	await _boss_gate()
	await _clear_then_level()
	await _fall()
	await _cover()
	print("Battle staging tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# Every theme has its light, its air, its stone and its things, and a place
# built of them stops her exactly where its data says.
func _places() -> void:
	var themes := AreaGround.THEMES.size()
	check(AreaGround.MOODS.size() == themes and AreaGround.AIRS.size() == themes and AreaGround.PROPS_BY_THEME.size() == themes, "Every theme has its light, its air and its things")
	var whole := true
	for theme: StringName in AreaGround.THEMES:
		whole = whole and ResourceLoader.exists(AreaGround.STONES % theme) and ResourceLoader.exists(AreaGround.ROCKS % theme)
	for set_name: StringName in AreaGround.PROPS_BY_THEME:
		whole = whole and AreaGround.PROP_SETS.has(set_name) and ResourceLoader.exists(AreaGround.PROP_SETS[set_name].atlas)
	check(whole, "Every theme's stone and things are painted")
	var seen := {}
	for file in DirAccess.get_files_at("res://data/areas"):
		var data := load("res://data/areas/" + file.trim_suffix(".remap")) as AreaData
		if data == null or data.is_event() or seen.has(data.theme):
			continue
		seen[data.theme] = true
		var area := enter_into(data, RunState.new(9))
		await process_frame
		var ground := area.ground
		var walls: Dictionary = data.walls()
		var stops := ground.walls == walls
		for cell: Vector2i in walls:
			stops = stops and not ground.is_open((Vector2(cell) + Vector2.ONE * 0.5) * AreaGround.CELL)
		check(stops and ground.bounds().size == Vector2(data.size * AreaGround.CELL), "What stops her in %s is what its data says, no more and no fewer" % data.id)
		check(ground.air != null and ground.air.mouse_filter == Control.MOUSE_FILTER_IGNORE and ground.sheet != null, "Its floor and its air are only seen: " + String(data.id))
		await leave(area)
	check(seen.size() == themes, "An area of every theme was built (%d of %d)" % [seen.size(), themes])
	# The lights of a fight are capped, however much happens at once.
	var field := enter("echo_corridor", RunState.new(9))
	await process_frame
	field.sparks.burst(field.hero.global_position, SparkField.MAX * 3, Color.WHITE)
	for index in AreaGround.FLASHES * 4:
		field.ground.flash(field.hero.global_position, 200.0, 1.0)
	check(field.sparks.count() <= SparkField.MAX and field.ground._flashes.size() <= AreaGround.FLASHES, "However much happens at once, the sparks and the flashes keep to their caps")
	# A warning is drawn heavier the greater the foe that gives it.
	var weights: Array[float] = []
	for foe_name in ["dashing_rat", "raging_charger", "ruin_king"]:
		var data: FoeData = load("res://data/foes/%s.tres" % foe_name)
		var foe: Foe = field.spawn_foe(data, field.hero.global_position + Vector2(160.0, 0.0))
		foe.set_physics_process(false)
		foe.begin_attack(data.attacks[0], Vector2.LEFT)
		weights.append(foe.telegraph.weight if foe.telegraph != null else -1.0)
	check(weights == [0.0, 1.0, 2.0], "A crowd foe's warning is drawn light, an elite's heavier, a boss's heaviest: %s" % [weights])
	await leave(field)


func _arrival_and_leaving() -> void:
	var run := RunState.new(9)
	var area := enter("echo_corridor", run)
	check(area.veil != null and area.veil.visible and is_equal_approx(area.veil_open, BattleArea.VEIL_FROM) and area.camera.zoom.x > CombatArea.CAMERA_ZOOM, "She arrives out of the dark, the view close on her")
	check(area.veil.mouse_filter == Control.MOUSE_FILTER_IGNORE and not paused and is_equal_approx(Engine.time_scale, 1.0) and not area.choosing(), "Her arrival holds nothing back: the fight is on at once")
	await real(BattleArea.ARRIVE_TIME + 0.4)
	check(is_equal_approx(area.veil_open, 1.0) and not area.veil.visible and area.camera.zoom.is_equal_approx(Vector2.ONE * CombatArea.CAMERA_ZOOM), "Her light opens the place and the view settles")
	# Cleared: it brightens and stays in sight, the dark closing on her only
	# at the last, and it is left when it always was.
	area.hero.health.max_hp = 100000
	area.hero.health.hp = 100000
	var left := [false]
	area.cleared.connect(func(): left[0] = true)
	area.elapsed = area.data.survive_time
	await wait(BattleArea.CLEAR_PAUSE - BattleArea.LEAVE_TIME - 0.1)
	check(area.finished and not left[0] and is_equal_approx(area.veil_open, 1.0) and area.ground.lift > 1.2, "Cleared, the place brightens and stays in sight")
	await wait(BattleArea.LEAVE_TIME + 0.35)
	check(left[0] and area.veil_open < 0.05 and area.veil.visible, "The dark closes on her as it is left, and it is left when it always was")
	await leave(area)


func _levels() -> void:
	var run := RunState.new(9)
	var area := enter("moss_plain", run)
	area.director.running = false
	area.dismiss_foes()
	area.hero.health.max_hp = 100000
	area.hero.health.hp = 100000
	await real(BattleArea.ARRIVE_TIME + 0.3)
	var hud := area.hud
	# Echoes short of a level: the bar runs to what she holds.
	area._on_gems(maxi(1, run.progression.required_exp() / 2))
	check(not area.choosing() and is_equal_approx(Engine.time_scale, 1.0), "Echoes short of a level stop nothing")
	await wait(1.0)
	check(is_equal_approx(hud.exp_bar.value, run.progression.exp) and is_equal_approx(hud.exp_bar.max_value, run.progression.required_exp()), "The echo bar runs to what she holds")
	# A level: a beat of slowed world, then the cards.
	var level := run.progression.level
	area._on_gems(run.progression.required_exp() - run.progression.exp)
	check(run.progression.level == level + 1 and area._leading and is_equal_approx(Engine.time_scale, BattleArea.LEAD_SLOW) and not paused, "A level gained slows the world for a beat before the cards")
	area._slow(0.4, 0.5)
	check(is_equal_approx(Engine.time_scale, BattleArea.LEAD_SLOW), "No other slow-down cuts into that beat")
	await real(BattleArea.LEAD_TIME + 0.08)
	var choice := area.choice
	check(choice.visible and paused and is_equal_approx(Engine.time_scale, 1.0) and choice.offers.size() == run.card_count(), "Then the fight stops for the cards, as many as the run offers")
	check(choice.pace == 0 and choice.cards[0].families_label.text == choice.offers[0].families_text(), "The area's first hand is dealt in full, each card showing what it belongs to")
	check(not choice.armed and choice.cards[0].turn < 0.5 and not choice.cards[0]._content.visible, "They are dealt face down: no card's words show before it turns, and none can be taken")
	await real(Choice.arm_time(choice.offers.size()) + 0.25)
	var turned := true
	for index in choice.offers.size():
		turned = turned and is_equal_approx(choice.cards[index].turn, 1.0) and choice.cards[index]._content.visible
	check(choice.armed and turned, "Dealt, every card is face up and the hand is armed")
	var taken: StringName = choice.offers[0].id
	var rank := run.build.rank(taken)
	choice._select(0)
	check(run.build.rank(taken) == rank + 1 and not choice.visible and not paused and is_equal_approx(Engine.time_scale, 1.0) and not area.choosing(), "The card taken raises its boon and the fight goes on at once")
	await wait(1.2)
	check(is_equal_approx(hud.exp_bar.value, run.progression.exp) and hud.level_label.text == "Lv %d" % run.progression.level, "The echo bar starts again for the next level")
	# Levels gained together: a hand for each, the fight stopped between them.
	level = run.progression.level
	var needed: int = run.progression.settings.required_exp(level) + run.progression.settings.required_exp(level + 1)
	area._on_gems(needed - run.progression.exp)
	await real(BattleArea.LEAD_TIME + 0.08)
	var hands := 0
	var held := true
	var paces: Array[int] = []
	while area.choosing() and hands < 6:
		held = held and choice.visible and paused
		paces.append(choice.pace)
		choice._select(0)
		hands += 1
	check(paces.size() >= 2 and paces[0] == 1 and paces[1] == 2 and Choice.arm_time(3, 1) < Choice.arm_time(3, 0) and Choice.arm_time(3, 2) < Choice.arm_time(3, 1), "Later hands are dealt briskly, and one that follows another at once: %s" % [paces])
	check(run.progression.level - level == hands and hands >= 2 and held and run.progression.pending_choices == 0, "Levels gained together each bring a hand, the fight stopped until the last is answered (%d levels, %d hands)" % [run.progression.level - level, hands])
	check(not paused and is_equal_approx(Engine.time_scale, 1.0), "Then it goes on")
	# A slow-down asked for before a level does not let the level's beat go early.
	area._slow(0.12, 0.5)
	area._on_gems(run.progression.required_exp() - run.progression.exp)
	await real(0.18)
	check(area._leading and is_equal_approx(Engine.time_scale, BattleArea.LEAD_SLOW), "An earlier slow-down running out does not cut a level's beat short")
	await real(BattleArea.LEAD_TIME)
	while area.choosing() and choice.visible:
		choice._select(0)
	# A staged slow-down is a moment, and ends by itself.
	area._slow(0.1, 0.4)
	check(is_equal_approx(Engine.time_scale, 0.4), "A staged moment slows the world")
	await real(0.2)
	check(is_equal_approx(Engine.time_scale, 1.0), "And lets it go when the moment is over")
	await leave(area)


func _boss() -> void:
	var run := RunState.new(9)
	# As a player comes through the gate: a way and a blow already held.
	Input.action_press(&"move_right")
	Input.action_press(&"strike")
	var area := enter("guardian_hall", run)
	area.hero.controlled = true
	var start := area.hero.global_position
	var hp := area.hero.health.hp
	check(area.entrance == BattleArea.Entrance.PREPARING and area.staging and paused and area.camera_held and area.boss_foe == null and not area.hud.boss_gauge.visible, "A boss hall opens with its entrance: the world is stopped before the hall's first frame")
	var most := 0.0
	var acted := false
	var seen := {}
	var foretold := false
	var closed_in := false
	var until := Time.get_ticks_msec() + roundi((BossIntro.total_time() + BattleArea.ENTRANCE_GRACE) * 1000.0) + 2000
	while area.staging and Time.get_ticks_msec() < until:
		await process_frame
		# (The frame after it ends is the fight's, not the entrance's.)
		if not area.staging:
			break
		most = maxf(most, area.hero.global_position.distance_to(start))
		acted = acted or area.hero.motor.state != HeroMotor.State.FREE
		seen[area.entrance] = true
		foretold = foretold or (area.boss_foe == null and is_instance_valid(area.sigil) and area.sigil.shown > 0.0)
		closed_in = closed_in or (area.boss_foe != null and area.boss_named and area.camera.zoom.x > CombatArea.CAMERA_ZOOM + 0.2 and area.ground.dread > BattleArea.BOSS_DREAD * 0.7)
	check(most == 0.0 and not acted, "With a way and a blow held all the while, she neither moves nor strikes before the fight begins (moved %.2f px)" % most)
	check(seen.has(BattleArea.Entrance.INTRO) and seen.has(BattleArea.Entrance.RETURN) and area.entrance == BattleArea.Entrance.ACTIVE, "Its entrance goes through its steps in order and ends with the fight on")
	check(foretold and closed_in, "It is foretold by its sigil before it is in, and the view closes on it in a hall gone red as it is named")
	check(not area.staging and area.hero.health.hp == hp and area.elapsed < 0.1 and area.boss_foe != null, "Nothing was taken from her and the fight's clock had not begun")
	check(not paused and not area.camera_held and area.camera.zoom.is_equal_approx(Vector2.ONE * CombatArea.CAMERA_ZOOM), "The view is back on her and the fight goes on")
	await wait(0.4)
	check(area.hero.global_position.distance_to(start) > 20.0, "And then the held way moves her: the fight is hers again")
	Input.action_release(&"move_right")
	Input.action_release(&"strike")
	area.hero.controlled = false
	area.hero.health.max_hp = 100000
	area.hero.health.hp = 100000
	await real(BossSigil.FLARE_TIME + 0.2)
	check(not is_instance_valid(area.sigil), "Its sigil has burnt out")
	# Its rage and its fall each slow the world for a moment, and no longer.
	var boss := area.boss_foe
	boss.receive(DamageInfo.make(boss.data.max_hp * 0.55, Vector2.UP))
	check(boss.phase == 2 and is_equal_approx(Engine.time_scale, BattleArea.RAGE_SLOW), "Its rage slows the world for a moment")
	await real(BattleArea.RAGE_SLOW_TIME + 0.5)
	check(is_equal_approx(Engine.time_scale, 1.0) and area.ground.dread > BattleArea.BOSS_DREAD + 0.2, "And no longer; the hall reddens further")
	var won := [false]
	area.cleared.connect(func(): won[0] = true)
	boss.receive(DamageInfo.make(1000000.0, Vector2.UP))
	check(area.boss_down and is_equal_approx(Engine.time_scale, BattleArea.BOSS_FALL_SLOW), "Its fall slows the world")
	await real(BattleArea.BOSS_FALL_TIME + 0.2)
	check(is_equal_approx(Engine.time_scale, 1.0) or area.choosing(), "And lets it go")
	for attempt in 10:
		if won[0]:
			break
		await real(0.4)
		while area.choosing() and area.choice.visible:
			area.choice._select(0)
	check(won[0] and area.ground.dread < 0.05 and area.ground.lift > 1.2 and is_equal_approx(Engine.time_scale, 1.0) and not paused, "The hall is cleared as ever, let out of its red")
	await leave(area)
	# The entrance never keeps the world: gone, the area lets the fight begin.
	var lost := enter("guardian_hall", RunState.new(9))
	for frame in BattleArea.ARRIVE_AFTER + 2:
		await process_frame
	lost.get_node("BossIntro").free()
	for frame in 3:
		await process_frame
	check(not lost.staging and not paused and not lost.camera_held and lost.entrance == BattleArea.Entrance.ACTIVE and lost.boss_foe != null and lost.camera.zoom.is_equal_approx(Vector2.ONE * CombatArea.CAMERA_ZOOM), "Should its entrance ever be gone, the area starts the fight by itself")
	await leave(lost)
	# Left in the middle of it (the run abandoned, the game closed): nothing stays stopped.
	var left := enter("guardian_hall", RunState.new(9))
	for frame in BattleArea.ARRIVE_AFTER + 2:
		await process_frame
	left.free()
	await process_frame
	check(not paused, "An area left in the middle of its boss's entrance leaves the world running")


# In a run, through the gate with keys held: the real way into a boss hall.
func _boss_gate() -> void:
	var director = RunDirector.new()
	director.seed_value = 12
	root.add_child(director)
	await process_frame
	var run: RunState = director.run
	var at: RouteMap.Waypoint = run.route.nodes(0)[0]
	for layer in run.route.size() - 1:
		run.taken.append(at)
		at = at.next[0]
	run.layer = run.route.size() - 1
	director.show_map()
	await process_frame
	Input.action_press(&"move_left")
	director.map_view._choose(director.map_view.current[0])
	await process_frame
	var area: BattleArea = director.area
	check(area != null and area.data.boss != null and area.hero.controlled and area.staging and paused, "Through the last gate is the boss's hall, stopped from its first frame")
	var start := area.hero.global_position
	var most := 0.0
	var until := Time.get_ticks_msec() + roundi((BossIntro.total_time() + BattleArea.ENTRANCE_GRACE) * 1000.0) + 2000
	while area.staging and Time.get_ticks_msec() < until:
		await process_frame
		# (The frame after it ends is the fight's, not the entrance's.)
		if not area.staging:
			break
		most = maxf(most, area.hero.global_position.distance_to(start))
	check(most == 0.0 and not area.staging and not paused, "Coming through the gate with a way held, she stands until the fight begins (moved %.2f px)" % most)
	await wait(0.4)
	check(area.hero.global_position.distance_to(start) > 20.0, "Then she moves")
	Input.action_release(&"move_left")
	director.free()
	paused = false
	await process_frame


# A clearing and the levels its last echoes bring are told one after the
# other, never at once, and the place is not left while cards are owed.
func _clear_then_level() -> void:
	var run := RunState.new(9)
	var area := enter("ember_waste", run)
	area.hero.health.max_hp = 100000
	area.hero.health.hp = 100000
	await real(BattleArea.ARRIVE_TIME + 0.3)
	area.director.running = false
	area.dismiss_foes()
	var need: int = run.progression.settings.required_exp(1) + run.progression.settings.required_exp(2)
	for index in 6:
		area.gems.drop(area.hero.global_position + Vector2.RIGHT.rotated(index) * 380.0, ceili(need / 6.0))
	var began := Time.get_ticks_msec()
	var left := [-1.0]
	area.cleared.connect(func(): left[0] = (Time.get_ticks_msec() - began) / 1000.0)
	area.kills = area.data.kill_target
	var told := -1.0
	var beat := -1.0
	var together := false
	var answered := 0
	while left[0] < 0.0 and Time.get_ticks_msec() - began < 12000:
		await process_frame
		var now := (Time.get_ticks_msec() - began) / 1000.0
		var banner: bool = area.hud.banner.visible and area.hud.message.text == "制圧完了"
		if told < 0.0 and banner:
			told = now
		if beat < 0.0 and area._leading:
			beat = now
		together = together or (banner and (area._leading or area.choice.visible))
		if area.choice.visible and area.choice.armed:
			area.choice._select(0)
			answered += 1
	check(told >= 0.0 and beat - told >= BattleArea.CLEAR_BEAT - 0.08 and not together, "The clearing is told by itself, and the level's beat comes after it (told at %.2f, the beat at %.2f)" % [told, beat])
	check(run.progression.level == 3 and answered == 2 and run.progression.pending_choices == 0, "Both levels are hers and both hands were answered before the place was left")
	check(left[0] > 0.0 and area.veil_open < 0.05, "Then the place is left, the dark closed on it (after %.2f s)" % left[0])
	await leave(area)


func _fall() -> void:
	var area := enter("ember_waste", RunState.new(9))
	await real(BattleArea.ARRIVE_TIME + 0.3)
	area.hero.health.hp = 1
	area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	check(not area.hero.health.alive() and is_equal_approx(Engine.time_scale, BattleArea.FALL_SLOW), "Her fall slows the world")
	await real(BattleArea.FALL_SLOW_TIME + 0.8)
	check(is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(area.veil_open, BattleArea.FALL_VEIL) and area.veil.visible and area.ground.dread > 0.9, "Then lets it go: the hall is red and the dark has closed round her, not over her")
	await leave(area)


# In a run, what follows an area comes up out of the dark.
func _cover() -> void:
	var director = RunDirector.new()
	director.seed_value = 12
	root.add_child(director)
	await process_frame
	director.map_view._choose(director.run.route.nodes(0)[0])
	await process_frame
	var area: BattleArea = director.area
	area.hero.controlled = false
	if area.data.survive_time > 0.0:
		area.elapsed = area.data.survive_time
	else:
		area.kills = area.data.kill_target
	var frames := 0
	while director.area != null and frames < 300:
		await physics_frame
		frames += 1
	var cover: ColorRect = director._cover
	check(director.area == null and cover != null and cover.visible and cover.modulate.a > 0.5 and cover.mouse_filter == Control.MOUSE_FILTER_IGNORE, "What follows a cleared area comes up out of the dark, which takes no input")
	await real(RunDirector.COVER_TIME + 0.3)
	check(not cover.visible, "And the dark is gone in a moment")
	director.free()
	paused = false
	await process_frame
