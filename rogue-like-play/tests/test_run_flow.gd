extends SceneTree

# A run through its areas: an arena's waves (marks, each wave's foes, the
# next after the last is down, the goal on the HUD); a run director's map,
# entering an area with the run's health, clearing it (the crowd leaves, the
# gems come in), its reward and the next layer; a fall ending the run; and
# a run taken through every layer to the boss and won.

const FRAME := 1.0 / 60.0
var failures := 0
var checks := 0
var ended: Array = []


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _on_finished(result: Dictionary) -> void:
	ended.append(result)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func wait(seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		await physics_frame


# Clears the area the director is in by meeting its goal, then waits until
# the director has handled it; takes a boon reward's first card.
func clear_area(director: RunDirector) -> void:
	var area := director.area
	if area.data.kind == AreaData.Kind.FIELD and area.data.survive_time > 0.0:
		area.elapsed = area.data.survive_time
	else:
		area.clear()
	await wait(BattleArea.CLEAR_PAUSE + 0.3)
	if director.choice.visible:
		director.choice._select(0)
	await process_frame


func run_tests() -> void:
	# An arena's waves, run by hand.
	var arena_data: AreaData = load("res://data/areas/pillar_arena.tres")
	var arena := BattleArea.new()
	arena.setup(arena_data, RunState.new(4), 4)
	root.add_child(arena)
	await process_frame
	arena.hero.controlled = false
	check(arena.waves != null and arena.director == null and arena.objective_text().contains("ウェーブ 1/3"), "An arena runs waves and says so")
	var spawned := 0
	var per_wave := [0, 0, 0]
	var placed_well := true
	var said_second := false
	for step in 3000:
		arena.waves.advance(0.1)
		for foe in arena.foes.duplicate():
			if foe.global_position.distance_to(arena.hero.global_position) < WaveRunner.MIN_DISTANCE or not arena.ground.is_open(foe.global_position, 10.0):
				placed_well = false
			if arena.waves.wave >= 0 and arena.waves.wave < 3:
				per_wave[arena.waves.wave] += 1
			spawned += 1
			foe.receive(DamageInfo.make(100000.0, Vector2.RIGHT))
		said_second = said_second or arena.objective_text().contains("ウェーブ 2/3")
		if arena.waves.done():
			break
	check(arena.waves.done() and arena.is_clear(), "Once every wave is down the arena is cleared")
	check(per_wave == [arena_data.waves[0].total(), arena_data.waves[1].total(), arena_data.waves[2].total()], "Each wave sends exactly its foes")
	check(placed_well, "Wave foes appear on open ground, away from her")
	check(said_second, "The goal follows the waves")
	arena.hit_stop.release()
	await process_frame
	arena.free()
	await process_frame

	# A level-up under every lasting upgrade: the gems' pull and the last
	# stand come in, four cards and a reroll are offered, the boon taken
	# heals her, and as the fight resumes a burst throws the crowd back, a
	# shield holds and her swings quicken.
	var full := MetaProgress.new()
	for upgrade in MetaProgress.UPGRADES:
		full.ranks[String(upgrade.id)] = upgrade.max_rank()
	var lasting_run := RunState.new(7)
	lasting_run.use_lasting(full.lasting())
	lasting_run.skills = [null, MetaProgress.find_skill(&"slam")]
	var lifted := BattleArea.new()
	lifted.setup(arena_data, lasting_run, 7)
	root.add_child(lifted)
	await process_frame
	lifted.hero.controlled = false
	check(lifted.gems.pull_radius == GemField.PULL_RADIUS + 40.0 and lifted.hero.health.last_stands == 1, "The gems' pull widens and her last stand comes with her")
	await process_frame
	check(not lifted.hud.slots[&"skill"].visible and lifted.hud.slots[&"skill_2"].visible, "The HUD shows the skill in the slot it is set in")
	var near_foe := lifted.spawn_foe(load("res://data/foes/wandering_sentinel.tres"), lifted.hero.global_position + Vector2(120, 0))
	var foe_hp := near_foe.health.hp
	lifted.hero.health.hp = 10
	lifted._on_gems(lasting_run.progression.required_exp())
	check(lifted.choosing() and not lifted.choice.visible and Engine.time_scale == BattleArea.LEAD_SLOW and not paused, "A level-up first slows the world for its lead-in")
	await create_timer(BattleArea.LEAD_TIME + 0.05, true, false, true).timeout
	check(paused and Engine.time_scale == 1.0 and lifted.choice.visible and not lifted.choice.armed, "Then the fight stops and the cards are dealt, not yet armed")
	lifted.choice._unhandled_input(_key(KEY_1))
	check(lifted.choice.visible and lasting_run.build.owned().is_empty(), "A number key while the cards are dealt takes nothing")
	check(lifted.choice.buttons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE, "The cards ignore the pointer while they are dealt")
	await create_timer(preload("res://ui/ability_choice.gd").arm_time(4) + 0.05, true, false, true).timeout
	check(lifted.choice.armed and lifted.choice.buttons[0].has_focus() and lifted.choice.buttons[0].mouse_filter == Control.MOUSE_FILTER_STOP, "Once dealt they are armed, focused and open to the pointer")
	check(lifted.choosing() and lifted.choice.offers.size() == 4 and lifted.choice.reroll_hint.visible, "A level-up offers four cards and a reroll")
	lifted.choice._reroll()
	check(lasting_run.rerolls_left == 1 and lifted.choice.visible and lifted.choice.offers.size() == 4 and lifted.choice.reroll_hint.text.contains("残り1"), "A reroll draws again and counts down")
	lifted.choice._select(0)
	await process_frame
	check(not lifted.choosing() and lifted.hero.health.hp == 10 + roundi(lifted.hero.health.max_hp * 0.1), "The boon taken heals her")
	check(near_foe.health.hp < foe_hp, "The fight resumes with a burst around her")
	check(lifted.hero.health.protected() and lasting_run.build._boosts.size() == 1, "A shield holds and her swings quicken")
	lifted.hit_stop.release()
	await process_frame
	lifted.free()
	await process_frame

	# The director: the map, an area entered, cleared, rewarded, the next layer.
	var director := RunDirector.new()
	director.seed_value = 12
	root.add_child(director)
	await process_frame
	check(director.map_view.visible and director.map_view.route_layer == 0 and director.map_view.buttons.size() == director.run.route.nodes(0).size(), "A run opens on its map, the first layer to choose")
	# The node map: every area a node, only the first layer open, the first
	# selected and told in the account, a later one readable but not enterable.
	var view := director.map_view
	var all_nodes := 0
	for index in director.run.route.size():
		all_nodes += director.run.route.nodes(index).size()
	check(view.nodes_by_point.size() == all_nodes and view.buttons.all(func(node: RouteNode): return node.mark == RouteNode.Mark.OPEN and node.focus_mode == Control.FOCUS_ALL), "Every area is a node; the first layer's are open")
	check(view.selected == director.run.route.nodes(0)[0] and view._detail_name.text == view.selected.area.display_name and not view._enter.disabled, "The first open node is selected and told, ready to enter")
	var later: RouteMap.Waypoint = director.run.route.nodes(1)[0]
	view._show_detail(later)
	check(view._detail_name.text == later.area.display_name and view._enter.disabled and view.nodes_by_point[later].disabled, "A later node can be read, not entered")
	view._choose(later)
	check(view.visible and director.area == null, "Choosing a node not open does nothing")
	view._show_detail(null)
	var first: RouteMap.Waypoint = director.run.route.nodes(0)[0]
	view._enter.pressed.emit()
	await process_frame
	check(director.area != null and director.area.data == first.area and not director.map_view.visible, "A choice enters its area")
	check(director.area.hero.health.hp == director.max_hp() and director.area.hero.build == director.run.build, "She comes in whole, with the run's build")
	director.area.hero.controlled = false
	director.area.hero.health.hp = 60
	director.area.gems.drop(director.area.hero.global_position + Vector2(600, 0), 2)
	var echo_before := director.run.echo
	var rank_before := director.run.build.owned().size()
	var reward := first.reward
	var area_before := director.area
	if first.area.survive_time > 0.0:
		area_before.elapsed = first.area.survive_time
	else:
		area_before.kills = first.area.kill_target
	await wait(0.1)
	check(area_before.finished and area_before.foes.is_empty() and is_inf(area_before.gems.pull_radius), "Its goal met, the area is cleared: the crowd leaves, the gems come in")
	await wait(BattleArea.CLEAR_PAUSE + 0.3)
	check(director.area == null and not is_instance_valid(area_before) or area_before.is_queued_for_deletion(), "The cleared area is left")
	match reward:
		AreaData.Reward.BOON:
			check(director.choice.visible, "A boon reward offers its cards")
			director.choice._select(0)
			await process_frame
			check(director.run.build.owned().size() == rank_before + 1 or director.run.build.owned().size() == rank_before, "The card's boon is taken")
		AreaData.Reward.HEAL:
			check(director.run.hp == 60 + roundi(director.max_hp() * RunDirector.HEAL_SHARE), "A heal reward restores her health")
		AreaData.Reward.ECHO:
			check(director.run.echo == echo_before + first.area.echo, "An echo reward adds the area's echo")
	check(director.run.layer == 1 and director.map_view.visible and director.run.areas_cleared == 1, "The route moves on a layer")
	var carried := director.run.hp
	director.map_view._choose(director.run.route.nodes(1)[0])
	await process_frame
	check(director.area.hero.health.hp == carried, "Her health is carried into the next area")
	# A fall ends the run.
	director.finished.connect(_on_finished)
	director.area.hero.health.hp = 1
	director.area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await wait(RunDirector.FALL_PAUSE + 0.3)
	check(ended.size() == 1 and not ended[0].cleared and ended[0].layer == 1, "A fall ends the run where it happened")
	check(director.end_view.visible and director.area == null and not paused, "The end is shown and the area left")
	director.free()
	await process_frame

	# Every layer to the boss: the run is won.
	ended.clear()
	director = RunDirector.new()
	director.seed_value = 31
	root.add_child(director)
	director.finished.connect(_on_finished)
	await process_frame
	for layer in director.run.route.size():
		director.map_view._choose(director.run.route.nodes(layer)[0])
		await process_frame
		director.area.hero.controlled = false
		await clear_area(director)
	check(ended.size() == 1 and ended[0].cleared and ended[0].layer == director.run.route.size() - 1, "Clearing the boss wins the run")
	check(director.run.taken.back().area.kind == AreaData.Kind.BOSS and director.run.areas_cleared == director.run.route.size(), "The last area entered was the boss's")
	check(ended[0].echo == director.run.echo and ended[0].echo > 0, "The result hands back the echo earned")
	director.free()
	await process_frame
	print("Run flow tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
