extends SceneTree

# A run through its areas: an arena's waves (marks, each wave's foes, the
# next after the last is down, the goal on the HUD); a run director's map,
# entering an area with the run's health, clearing it (the crowd leaves, the
# gems come in), its reward and the next layer; a fall ending the run; and
# a run taken through every layer to the boss and won; and the events
# (the merchant's wares, the altar's price, the cursed stone's bargain).

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


# Puts an event on the map's current layer and stops at it, as if picked.
func stop_at(director: RunDirector, path: String) -> void:
	var point := RouteMap.Waypoint.new(load(path), AreaData.Reward.BOON, director.run.layer)
	director.run.route.layers[director.run.layer].append(point)
	director.show_map()
	director.enter(point)
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
	check(view.draw_progress < 1.0 and view.token != null and view.token.position + view.token.size * 0.5 == view.token_spot(), "The paths open to her draw out from her token, at the start")
	await create_timer(RouteMapView.DRAW_TIME + 0.1).timeout
	check(view.draw_progress == 1.0, "And reach the open layer")
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
	var start: Vector2 = view.token.position
	view._enter.pressed.emit()
	await process_frame
	check(view.prompt.visible and view.prompt.title_label.text == "「%s」に進みますか？" % first.area.display_name and not view.traveling and director.area == null, "A pick first asks whether to go there")
	view.prompt.canceled.emit()
	check(not view.prompt.visible and view.visible and not view.traveling, "Going back stays on the map")
	view._enter.pressed.emit()
	view.prompt.confirmed.emit()
	await process_frame
	check(view.traveling and director.area == null and view.visible, "Going ahead sends her token along the path, entering nothing yet")
	view._enter.pressed.emit()
	await create_timer(RouteMapView.TRAVEL_TIME * 0.5).timeout
	check(view.token.position != start and director.area == null, "The token travels, and a second press on the way does nothing")
	await create_timer(RouteMapView.TRAVEL_TIME + RouteMapView.ARRIVE_TIME + 0.1).timeout
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
	var after_first: RouteMap.Waypoint = director.run.taken[0]
	check(director.map_view.current == after_first.next and director.map_view.buttons.size() == after_first.next.size() and after_first.next.size() <= after_first.area.branches.y, "Past the first layer, only the paths from the area taken are open")
	var shut := director.run.route.nodes(1).filter(func(point: RouteMap.Waypoint): return not after_first.next.has(point))
	check(shut.all(func(point: RouteMap.Waypoint): return director.map_view.nodes_by_point[point].mark == RouteNode.Mark.PASSED and director.map_view.nodes_by_point[point].disabled), "The rest of that layer is shut, dimmed")
	director.map_view._choose(director.map_view.current[0])
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
		director.map_view._choose(director.map_view.current[0])
		await process_frame
		director.area.hero.controlled = false
		await clear_area(director)
	check(ended.size() == 1 and ended[0].cleared and ended[0].layer == director.run.route.size() - 1, "Clearing the boss wins the run")
	check(director.run.taken.back().area.kind == AreaData.Kind.BOSS and director.run.areas_cleared == director.run.route.size(), "The last area entered was the boss's")
	check(ended[0].echo == director.run.echo and ended[0].echo > 0, "The result hands back the echo earned")
	director.free()
	await process_frame
	# The second chapter, taken through every layer to the storm wolf: its
	# boss comes in, rages at half health and calls its rats, and falls.
	ended.clear()
	director = RunDirector.new()
	director.seed_value = 43
	director.chapter = load("res://data/chapters/gale_woods.tres")
	root.add_child(director)
	director.finished.connect(_on_finished)
	await process_frame
	check(director.run.route.size() == 5 and director.map_view._title.text.contains("風哭きの樹海"), "The run lays out the chapter it was given")
	for layer in director.run.route.size() - 1:
		director.map_view._choose(director.map_view.current[0])
		await process_frame
		director.area.hero.controlled = false
		await clear_area(director)
	director.map_view._choose(director.run.route.nodes(director.run.route.size() - 1)[0])
	await process_frame
	var den := director.area
	den.hero.controlled = false
	# She is not to fall while the wolf is looked at.
	den.hero.health.max_hp = 100000
	den.hero.health.hp = 100000
	await wait(BattleArea.BOSS_DELAY + BattleArea.BOSS_MARK_TIME + 0.4)
	await create_timer(BossIntro.total_time() + 0.3, true, false, true).timeout
	var wolf := den.boss_foe
	check(wolf != null and wolf.data.id == &"gale_wolf_king" and wolf.view.rig != null, "The storm wolf comes in, drawn by its rig")
	wolf.receive(DamageInfo.make(float(wolf.health.max_hp) * 0.55, Vector2.RIGHT))
	await wait(0.2)
	check(wolf.phase == 2, "At half health it rages")
	wolf.receive(DamageInfo.make(100000.0, Vector2.RIGHT))
	# Its gems may bring a level, whose cards are taken as they come.
	for frame in 400:
		if not ended.is_empty():
			break
		if is_instance_valid(den) and den.is_inside_tree() and den.choice.visible:
			den.choice._select(0)
		await physics_frame
	check(ended.size() == 1 and ended[0].cleared and ended[0].chapter_id == "gale_woods", "Felling it wins the second chapter")
	director.free()
	await process_frame

	# The special move set at the base goes with her, and its gauge carries
	# from area to area.
	var armed := MetaProgress.new()
	armed.ranks[String(MetaProgress.ROOT)] = 1
	armed.ranks["learn_echo_burst"] = 1
	armed.ranks["special_surge"] = 1
	armed.special = &"echo_burst"
	armed.ranks["learn_spear"] = 1
	armed.weapon = &"spear"
	director = RunDirector.new()
	director.seed_value = 37
	director.meta = armed
	root.add_child(director)
	await process_frame
	director.map_view._choose(director.run.route.nodes(0)[0])
	await process_frame
	var fighter := director.area.hero
	fighter.controlled = false
	check(fighter.special == MetaProgress.find_special(&"echo_burst") and is_equal_approx(fighter.special_gain, 1.2), "The run's special move and its gain reach her")
	check(fighter.motor.moveset.id == &"spear", "So does the weapon set at the base")
	fighter.special_charge = 42.0
	await clear_area(director)
	director.map_view._choose(director.map_view.current[0])
	await process_frame
	check(director.run.special_charge == 42.0 and director.area.hero.special_charge == 42.0, "The gauge carries into the next area")
	director.free()
	await process_frame

	# The merchant: no fight, a window over the map, wares paid in echo.
	director = RunDirector.new()
	director.seed_value = 41
	root.add_child(director)
	await process_frame
	var stop := director.event_view
	director.run.echo = 100
	director.run.hp = 40
	await stop_at(director, "res://data/areas/event_merchant.tres")
	check(director.area == null and stop.visible and director.map_view.visible and stop.title_label.text == "行商人", "An event opens its window over the map, without a fight")
	check(stop.ids == [&"boon", &"heal", EventView.LEAVE] and stop.buttons.all(func(button: Button): return not button.disabled), "The merchant offers a boon and a heal, and leaving")
	stop.buttons[0].pressed.emit()
	await process_frame
	check(director.choice.visible and not stop.visible and director.run.echo == 100 - RunDirector.MERCHANT_BOON_PRICE, "A boon is bought for echo, from the cards")
	var owned := director.run.build.owned().size()
	director.choice._select(0)
	await process_frame
	check(director.run.build.owned().size() == owned + 1 and stop.visible and director.run.layer == 0, "The boon is hers, and the merchant is still there")
	check(stop.buttons[0].disabled and stop.buttons[1].disabled and stop.buttons[1].tooltip_text.contains("足りない"), "A ware bought or too dear is offered but off, saying why")
	director.run.echo += RunDirector.MERCHANT_HEAL_PRICE
	director._show_event()
	stop.buttons[1].pressed.emit()
	await process_frame
	check(director.run.hp == 40 + roundi(director.max_hp() * RunDirector.MERCHANT_HEAL_SHARE) and director.run.echo == 100 - RunDirector.MERCHANT_BOON_PRICE, "Her wounds are tended for echo")
	stop._unhandled_input(_key(KEY_ESCAPE))
	await process_frame
	check(not stop.visible and director.run.layer == 1 and director.map_view.visible and not director.map_view.traveling, "Leaving goes on to the next layer")
	check(director.map_view._note.text.contains("行商人"), "The map tells what the stop gave")

	# The altar: health for a boon, and the stop is over.
	director.run.hp = 0
	await stop_at(director, "res://data/areas/event_altar.tres")
	check(stop.ids == [&"offer", EventView.LEAVE] and not stop.buttons[0].disabled, "The altar asks for health")
	director.run.hp = director.altar_cost()
	director._show_event()
	check(stop.buttons[0].disabled, "The altar cannot take the last of her health")
	director.run.hp = 0
	director._show_event()
	stop.buttons[0].pressed.emit()
	await process_frame
	check(director.run.hp == director.max_hp() - director.altar_cost() and director.choice.visible, "Her health is given, and a boon is chosen")
	director.choice._select(0)
	await process_frame
	check(not stop.visible and director.run.layer == 2, "The altar's boon ends the stop")

	# The cursed stone: a curse for a boon, and more echo from then on.
	var defense := director.run.tuning.defense
	var speed := director.run.tuning.max_speed
	var echo_without := director.run.echo_reward(100)
	await stop_at(director, "res://data/areas/event_curse.tres")
	var curse := director._event_curse
	check(stop.ids == [&"curse", EventView.LEAVE] and stop.buttons[0].text.contains(RunState.CURSES[curse][0]), "The stone names the curse it offers")
	stop.buttons[0].pressed.emit()
	await process_frame
	director.choice._select(0)
	await process_frame
	check(director.run.curses == [curse] and not stop.visible and director.run.layer == 3, "The curse is taken with a boon, and the stop ends")
	check(director.run.echo_reward(100) == echo_without + roundi(100 * RunState.CURSE_ECHO), "A curse raises the echo rewards")
	check(director.map_view._curses.visible and director.map_view._curses.text.contains(RunState.CURSES[curse][0]), "The map shows the curses she carries")
	director.run.take_curse(&"frailty")
	director.run.take_curse(&"sluggish")
	director.run.take_curse(&"thirst")
	check(director.run.tuning.defense == defense - RunState.FRAILTY and is_equal_approx(director.run.tuning.max_speed, speed * RunState.SLUGGISH), "Frailty and sluggishness reach her tuning")
	check(not director.run.take_curse(&"thirst") and director.run.curses_left().is_empty(), "A curse is not taken twice")
	director.run.hp = 10
	director.waypoint = director.run.route.nodes(director.run.layer)[0]
	director.grant(AreaData.Reward.HEAL)
	check(director.run.hp == 10 + roundi(director.max_hp() * RunDirector.HEAL_SHARE * 0.5), "Thirst halves a heal")
	director.free()
	await process_frame
	print("Run flow tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
