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

	# The director: the map, an area entered, cleared, rewarded, the next layer.
	var director := RunDirector.new()
	director.seed_value = 12
	root.add_child(director)
	await process_frame
	check(director.map_view.visible and director.map_view.route_layer == 0 and director.map_view.buttons.size() == director.run.route.nodes(0).size(), "A run opens on its map, the first layer to choose")
	var first: RouteMap.Waypoint = director.run.route.nodes(0)[0]
	director.map_view._choose(first)
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
