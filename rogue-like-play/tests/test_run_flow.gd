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
	# The goal's bar: it never falls back, and it moves within a wave.
	var bar_last := 0.0
	var bar_steady := true
	var bar_within := false
	for step in 3000:
		arena.waves.advance(0.1)
		var bar := arena.waves.progress()
		bar_steady = bar_steady and bar >= bar_last - 0.0001
		bar_within = bar_within or (bar > 0.02 and bar < 1.0 / 3.0 - 0.02)
		bar_last = bar
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
	check(bar_steady and bar_within and is_equal_approx(arena.waves.progress(), 1.0), "The goal's bar fills as the foes of each wave fall, not only when a wave ends")
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
	check(not lifted.choosing() and lifted.hero.health.hp == 10 + roundi(lifted.hero.health.max_hp * lifted.run.rule(&"level_heal")) and lifted.run.rule(&"level_heal") > 0.0, "The boon taken heals her")
	check(near_foe.health.hp < foe_hp, "The fight resumes with a burst around her")
	check(lifted.hero.health.protected() and lasting_run.build._boosts.size() == 1, "A shield holds and her swings quicken")
	lifted.hit_stop.release()
	await process_frame
	lifted.free()
	await process_frame

	# The boss's layer: the view goes to it, it comes out of the dark with its
	# name, and the view comes back to her; once a run, and a key cuts it short.
	for cut_short in [false, true]:
		var boss_run := RunDirector.new()
		boss_run.seed_value = 12
		root.add_child(boss_run)
		await create_timer(0.3).timeout
		var boss_route: RouteMap = boss_run.run.route
		var walked: RouteMap.Waypoint = boss_route.nodes(0)[0]
		for index in boss_route.size() - 1:
			boss_run.run.taken.append(walked)
			walked = walked.next[0]
		boss_run.run.layer = boss_route.size() - 1
		boss_run.show_map()
		var boss_view := boss_run.map_view
		var boss: RouteNode = boss_view.nodes_by_point[boss_route.nodes(boss_route.size() - 1)[0]]
		check(boss_view.waiting_boss() == boss and boss.veiled and boss_view.panning and boss_view._revealed_route == boss_route, "The boss's layer open, its coming out begins")
		if cut_short:
			await create_timer(RouteMapView.DRAW_TIME + RouteMapView.REVEAL_PAN + RouteMapView.COMING_OUT * 0.3).timeout
			boss_view._end_pan()
			check(not boss.veiled and boss.figure.modulate == Color.WHITE and not boss_view._boss_title.visible and boss_view._world.position.y == 0.0 and is_equal_approx(boss_view.scroll, boss_view.follow_scroll()), "A key cuts it short: the boss out, the view back on her")
		else:
			await create_timer(RouteMapView.DRAW_TIME + RouteMapView.REVEAL_PAN + RouteMapView.COMING_OUT + 0.1).timeout
			var boss_middle: float = boss_view._center(boss.waypoint).x - boss_view._frame.size.x * 0.5
			check(not boss.veiled and boss.figure.modulate.is_equal_approx(Color.WHITE) and boss_view._boss_title.visible and boss_view._boss_name.text == boss.waypoint.area.boss.display_name and boss_view._boss_epithet.text == boss.waypoint.area.boss.epithet and is_equal_approx(boss_view.scroll, clampf(boss_middle, 0.0, boss_view.scroll_limit())), "The view on the boss, it comes out and its name rises")
			await create_timer(RouteMapView.REVEAL_HOLD + RouteMapView.REVEAL_FADE + RouteMapView.REVEAL_PAN + 0.2).timeout
			check(not boss_view.panning and not boss_view._boss_title.visible and is_equal_approx(boss_view.scroll, boss_view.follow_scroll()) and boss_view._card.visible, "Then the view comes back to her")
			var boss_point: RouteMap.Waypoint = boss.waypoint
			boss_run.show_map()
			check(boss_view.waiting_boss() == null and not boss_view.panning and not (boss_view.nodes_by_point[boss_point] as RouteNode).veiled, "Opened again, the boss stands in the open")
		boss_run.queue_free()
		await process_frame

	# The director: the map, an area entered, cleared, rewarded, the next layer.
	var director := RunDirector.new()
	director.seed_value = 12
	root.add_child(director)
	await process_frame
	check(director.map_view.visible and director.map_view.route_layer == 0 and director.map_view.buttons.size() == director.run.route.nodes(0).size(), "A run opens on its map, the first layer to choose")
	# The node map: the whole screen, wider than it (a chapter of four
	# columns scrolls), the boss shown first and the view panning back to her.
	var view := director.map_view
	check(view._frame.size == root.get_visible_rect().size and view._world.size.x > view._frame.size.x and view.scroll_limit() > 0.0, "The map fills the screen and runs past its edge")
	check(view.panning and view.scroll == view.scroll_limit() and not view._card.visible, "At the chapter's start the view rests on the boss, no card yet")
	check(view.draw_progress < 1.0 and view.hero != null and view.hero.position == view.hero_spot() and view.hero_spot() == view.anchor() + RouteMapView.HERO_OFFSET, "She stands on the road at the start, the open roads not yet drawn")
	await create_timer(RouteMapView.PAN_HOLD + RouteMapView.PAN_TIME + RouteMapView.DRAW_TIME + RouteMapView.FOCUS_DELAY + 0.2).timeout
	check(not view.panning and is_equal_approx(view.scroll, view.follow_scroll()) and view.draw_progress == 1.0, "The view pans back to her and the open roads draw out")
	var all_nodes := 0
	for index in director.run.route.size():
		all_nodes += director.run.route.nodes(index).size()
	check(view.nodes_by_point.size() == all_nodes and view.buttons.all(func(node: RouteNode): return node.mark == RouteNode.Mark.OPEN and node.focus_mode == Control.FOCUS_ALL), "Every area is a node; the first layer's are open")
	check(view.nodes_by_point.values().all(func(node: RouteNode): return node._caption.text == ("" if node.waypoint.area.boss != null else node.waypoint.area.stars()) and node.tooltip_text.is_empty()), "A node shows its reward and its stars, nothing more")
	var column_gap: float = view._center(director.run.route.nodes(1)[0]).x - view._center(director.run.route.nodes(0)[0]).x
	check(is_equal_approx(column_gap, RouteMapView.COLUMN_GAP), "The layers stand in columns along the map")
	var road := view.road_texture()
	var lines := view.road_lines()
	var ways := func(way: int) -> Array: return lines.filter(func(line: Line2D): return line.get_meta(&"way", -1) == way)
	var paths := 0
	for index in director.run.route.size() - 1:
		for point: RouteMap.Waypoint in director.run.route.nodes(index):
			paths += point.next.size()
	var open_ways: Array = ways.call(RouteMapView.Way.OPEN)
	check(open_ways.size() == director.run.route.nodes(0).size() and open_ways.all(func(line: Line2D): return line.texture == road and line.width == RouteMapView.ROAD_WIDTH) and view._open_roads.size() == open_ways.size() and view._roads.get_node("Glows").get_child_count() == open_ways.size(), "The open ways are roads in the chapter's ground, each over its glow")
	# Each layer of roads: every road whole, then every road by its middle, so
	# where they meet the middles run together over the rims.
	var middle := view.middle_texture()
	var open_layer: Node2D = open_ways[0].get_parent()
	var open_parts := open_layer.get_children()
	var whole_count := open_parts.filter(func(line: Line2D): return line.has_meta(&"way")).size()
	check(middle != null and middle.get_width() == road.get_width() and middle.get_height() == roundi(road.get_height() * RouteMapView.MIDDLE_SHARE) and open_parts.size() == whole_count * 2 and open_parts.slice(0, whole_count).all(func(line: Line2D): return line.has_meta(&"way")) and open_parts.slice(whole_count).all(func(line: Line2D): return line.texture == middle and is_equal_approx(line.width, RouteMapView.ROAD_WIDTH * RouteMapView.MIDDLE_SHARE)), "Roads are laid whole, then by their middles over all the rims")
	check(middle.get_image().get_pixel(middle.get_width() / 2, 0).a < 0.1 and middle.get_image().get_pixel(middle.get_width() / 2, middle.get_height() / 2).a > 0.9, "A middle's cut edges fade out")
	var faint: Array = ways.call(RouteMapView.Way.AHEAD)
	var faint_layer: Node = faint[0].get_parent() if not faint.is_empty() else null
	check(faint.size() == paths and faint.all(func(line: Line2D): return line.texture == road and line.width == RouteMapView.FAINT_WIDTH and line.get_parent() == faint_layer and line.modulate.a == 1.0) and faint_layer is CanvasGroup and is_equal_approx(faint_layer.self_modulate.a, RouteMapView.AHEAD_ALPHA), "The ways further on are the same road, narrower, laid as one and made see-through together")
	check(view.selected == director.run.route.nodes(0)[0] and view.buttons[0].has_focus() and view._card.visible and view._detail_name.text == view.selected.area.display_name and not view._detail_state.visible, "The first open node is focused and its card shows")
	var first_rect: Rect2 = view.nodes_by_point[view.selected].get_global_rect()
	check(view._card.get_global_rect().end.x <= first_rect.position.x or view._card.get_global_rect().position.x >= first_rect.end.x, "The card stands beside its node, not over it")
	check(view._detail_foe_row.get_child_count() == Chapters.area_foes(view.selected.area).size() and view._detail_foe_row.get_child_count() > 0, "The card shows the area's foes as pictures")
	# Each node is a stage of the chapter's ground: the foes on it braced and
	# facing her, an event's object, the boss's a size up and in the dark.
	var stage := RouteNode.plate_for(director.run.route.chapter.id)
	check(stage != null and view.nodes_by_point.values().all(func(node: RouteNode): return node.plate == stage), "Every node stands on the chapter's stage")
	var fights: Array = view.nodes_by_point.values().filter(func(node: RouteNode): return not node.waypoint.area.is_event())
	var rigs_ready := fights.all(func(node: RouteNode):
		var rigs := node.figure.find_children("*", "CharacterRig", true, false)
		return not rigs.is_empty() and rigs.all(func(rig: CharacterRig): return rig.braced and rig.get_parent().scale.x < 0.0))
	check(rigs_ready, "Its foes stand on it braced, facing her")
	var events: Array = view.nodes_by_point.values().filter(func(node: RouteNode): return node.waypoint.area.is_event())
	check(not events.is_empty() and events.all(func(node: RouteNode):
		var props := node.figure.get_children().filter(func(child: Node): return child is Sprite2D)
		return props.size() == 1 and props[0].texture == RouteNode.prop_for(node.waypoint.area.event)), "An event's stage holds its object instead")
	check(view._start_stage != null and view._start_stage.find_children("*", "Sprite2D", true, false).any(func(sprite: Sprite2D): return sprite.texture == RouteNode.prop_for(&"sign")), "The start is a smaller stage with a signpost")
	var field: AreaData = fights.map(func(node: RouteNode): return node.waypoint.area).filter(func(area: AreaData): return area.spawn_table != null)[0]
	var heaviest: SpawnEntry = field.spawn_table.entries[0]
	for entry: SpawnEntry in field.spawn_table.entries:
		if entry.weight > heaviest.weight:
			heaviest = entry
	check(RouteNode.leader(field) == heaviest.foe and RouteNode.company(field) != null and RouteNode.company(field) != heaviest.foe, "A field is shown by the kind met most, another behind it")
	var boss_point: RouteMap.Waypoint = director.run.route.nodes(director.run.route.size() - 1)[0]
	var boss_node: RouteNode = view.nodes_by_point[boss_point]
	var plain_node: RouteNode = view.nodes_by_point[director.run.route.nodes(0)[0]]
	check(is_equal_approx(boss_node.size.x, plain_node.size.x * RouteNode.BOSS_SCALE), "The boss's stage is a size up")
	check(boss_node.veiled and boss_node.figure.modulate.is_equal_approx(RouteNode.VEIL), "The boss waits in the dark")
	view._point_at(boss_point)
	check(view._detail_name.text == RouteMapView.VEILED_NAME and view._detail_goal.text == RouteMapView.VEILED_NOTE and not view._detail_reward.visible and not view._detail_foe_row.visible, "Its card names nothing, only that something waits")
	view._point_at(null)
	var later: RouteMap.Waypoint = director.run.route.nodes(1)[0]
	view._point_at(later)
	check(view.told == later and view._detail_name.text == later.area.display_name and view._detail_state.text == RouteMapView.AHEAD_NOTE and view.nodes_by_point[later].disabled, "A later node can be read, not entered")
	check(view._card.get_global_rect().end.x <= view.nodes_by_point[later].get_global_rect().position.x, "Its card stands on its left, the side already passed")
	view._point_at(null)
	check(view.told == view.selected, "Pointing away tells the selected node again")
	view._choose(later)
	check(view.visible and director.area == null, "Choosing a node not open does nothing")
	var looked := view.scroll
	view.look(RouteMapView.LOOK_STEP)
	check(view.scroll > looked or looked == view.scroll_limit(), "The wheel or the stick looks along the map")
	view.look(-view.scroll_limit() * 2.0)
	check(view.scroll == 0.0, "And no further than its ends")
	var first: RouteMap.Waypoint = director.run.route.nodes(0)[0]
	var start: Vector2 = view.hero.position
	view.nodes_by_point[first].pressed.emit()
	await process_frame
	check(view.prompt.visible and view.prompt.title_label.text == "「%s」に進みますか？" % first.area.display_name and not view.traveling and director.area == null and not view._card.visible, "A pick first asks whether to go there")
	view.prompt.canceled.emit()
	check(not view.prompt.visible and view.visible and not view.traveling and view._card.visible, "Going back stays on the map")
	view.nodes_by_point[first].pressed.emit()
	view.prompt.confirmed.emit()
	await process_frame
	check(view.traveling and director.area == null and view.visible and not view._card.visible, "Going ahead walks her along the road, entering nothing yet")
	view.nodes_by_point[first].pressed.emit()
	await create_timer(RouteMapView.TRAVEL_TIME * 0.5).timeout
	check(view.hero.position != start and view.hero.rig.animation_player.current_animation == CharacterRig.WALK and director.area == null, "She walks, and a second press on the way does nothing")
	await create_timer(RouteMapView.TRAVEL_TIME * 0.5 + 0.05).timeout
	check(view.hero.position.distance_to(view._center(first) + RouteMapView.HERO_OFFSET) < 1.0, "She stops on the road at the area she picked")
	await create_timer(RouteMapView.ARRIVE_TIME + 0.1).timeout
	check(director.area != null and director.area.data == first.area and not director.map_view.visible, "A choice enters its area")
	check(director.area.hero.health.hp == director.max_hp() and director.area.hero.build == director.run.build, "She comes in whole, with the run's build")
	director.area.hero.controlled = false
	director.area.hero.health.hp = 60
	director.area.gems.drop(director.area.hero.global_position + Vector2(600, 0), 2)
	# An elite felled in the fight adds its echo to the run's at once.
	var brute: FoeData = load("res://data/foes/raging_charger.tres")
	var elite := director.area.spawn_foe(brute, director.area.hero.global_position + Vector2(300, 0))
	var echo_fight := director.run.echo
	director.area._on_foe_echo(elite)
	check(brute.echo_reward > 0 and director.run.echo == echo_fight + brute.echo_reward, "An elite's fall adds its echo to the run's, mid-fight")
	var crowd_foe := director.area.spawn_foe(load("res://data/foes/wandering_sentinel.tres") as FoeData, director.area.hero.global_position + Vector2(300, 0))
	director.area._on_foe_echo(crowd_foe)
	check(director.run.echo == echo_fight + brute.echo_reward, "The crowd gives none")
	# (Told to the area directly: a fall would leave a gem, and a level-up.)
	elite.vanish()
	crowd_foe.vanish()
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
			check(director.run.echo == echo_before + roundi(first.area.echo * RunState.CLEAR_ECHO_SHARE) and director.run.echo > echo_before, "Clearing the area gave a share of its echo, whatever its reward")
			director.choice._select(0)
			await process_frame
			check(director.run.build.owned().size() == rank_before + 1 or director.run.build.owned().size() == rank_before, "The card's boon is taken")
		AreaData.Reward.HEAL:
			check(director.run.hp == 60 + roundi(director.max_hp() * RunDirector.HEAL_SHARE), "A heal reward restores her health")
			check(director.run.echo == echo_before + roundi(first.area.echo * RunState.CLEAR_ECHO_SHARE) and director.run.echo > echo_before, "Clearing the area gave a share of its echo, whatever its reward")
		AreaData.Reward.ECHO:
			check(director.run.echo == echo_before + first.area.echo, "An echo reward makes the area's echo whole")
	check(director.run.layer == 1 and director.map_view.visible and director.run.areas_cleared == 1, "The route moves on a layer")
	var carried := director.run.hp
	var after_first: RouteMap.Waypoint = director.run.taken[0]
	check(director.map_view.current == after_first.next and director.map_view.buttons.size() == after_first.next.size() and after_first.next.size() <= after_first.area.branches.y, "Past the first layer, only the paths from the area taken are open")
	var after_lines := director.map_view.road_lines()
	check(after_lines.any(func(line: Line2D): return line.get_meta(&"way", -1) == RouteMapView.Way.WALKED) and after_lines.any(func(line: Line2D): return line.get_meta(&"way", -1) == RouteMapView.Way.SHUT and line.get_parent() is CanvasGroup and is_equal_approx(line.get_parent().self_modulate.a, RouteMapView.SHUT_ALPHA)), "The way walked is a road, the ways forgone fainter still")
	var first_shut := after_lines.find_custom(func(line: Line2D): return line.get_meta(&"way", -1) == RouteMapView.Way.SHUT)
	var first_ahead := after_lines.find_custom(func(line: Line2D): return line.get_meta(&"way", -1) == RouteMapView.Way.AHEAD)
	check(first_ahead < 0 or first_shut < first_ahead, "The ways cut off lie under the ways still in reach")
	var shut := director.run.route.nodes(1).filter(func(point: RouteMap.Waypoint): return not after_first.next.has(point))
	check(shut.all(func(point: RouteMap.Waypoint): return director.map_view.nodes_by_point[point].mark == RouteNode.Mark.PASSED and director.map_view.nodes_by_point[point].disabled), "The rest of that layer is shut, dimmed")
	check(director.map_view.nodes_by_point[after_first].figure.get_child_count() == 0, "The stage she cleared stands empty")
	director.map_view._choose(director.map_view.current[0])
	await process_frame
	check(director.area.hero.health.hp == carried, "Her health is carried into the next area")
	# A fall ends the run.
	director.finished.connect(_on_finished)
	director.area.hero.health.hp = 1
	var last_area: AreaData = director.area.data
	director.area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await wait(RunDirector.FALL_PAUSE + 0.3)
	check(ended.size() == 1 and not ended[0].cleared and ended[0].layer == 1, "A fall ends the run where it happened")
	check(director.end_view.visible and director.area == null and not paused, "The end is shown and the area left")
	var journey := director.end_view.journey
	check(ended[0].fallen_to == null and journey.ended_at == 2 and journey.spots.size() == director.run.route.size() + 1 and not (journey.figure is DirectionalRig) and journey.caption.text == "%sに倒された" % RouteNode.leader(last_area).display_name, "A blow that names no foe leaves the area's foe standing where she fell")
	var dummy := Foe.new()
	dummy.data = RouteNode.leader(last_area)
	check(RunDirector.foe_of(DamageInfo.make(1.0, Vector2.RIGHT, 0.0, dummy)) == dummy.data and RunDirector.foe_of(DamageInfo.make(1.0, Vector2.RIGHT)) == null, "A foe's own blow names it")
	dummy.free()
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

	# The third chapter, taken through to the summoning priest: its crowd is
	# skeletons and wisps drawn from baked frames, its ground the crypt's,
	# and its boss comes in by its rig, calls skeletons, rages and falls.
	ended.clear()
	director = RunDirector.new()
	director.seed_value = 47
	director.chapter = load("res://data/chapters/amethyst_mausoleum.tres")
	root.add_child(director)
	director.finished.connect(_on_finished)
	await process_frame
	check(director.run.route.size() == 5 and director.map_view._title.text.contains("紫晶の霊廟"), "The third chapter lays out four layers and its boss")
	var crypt_seen := false
	var crowd_seen := false
	for layer in director.run.route.size() - 1:
		director.map_view._choose(director.map_view.current[0])
		await process_frame
		var hall := director.area
		hall.hero.controlled = false
		crypt_seen = crypt_seen or hall.data.theme == 5
		if hall.director != null:
			hall.director.advance(1.0)
			crowd_seen = crowd_seen or hall.foes.any(func(foe: Foe): return foe.data.id in [&"skeleton", &"wisp"] and foe.view.sprite != null)
		await clear_area(director)
	check(crypt_seen, "Its areas lie on the crypt's ground")
	check(crowd_seen, "Its crowd comes in drawn from their baked frames")
	director.map_view._choose(director.run.route.nodes(director.run.route.size() - 1)[0])
	await process_frame
	var ossuary := director.area
	ossuary.hero.controlled = false
	ossuary.hero.health.max_hp = 100000
	ossuary.hero.health.hp = 100000
	await wait(BattleArea.BOSS_DELAY + BattleArea.BOSS_MARK_TIME + 0.4)
	await create_timer(BossIntro.total_time() + 0.3, true, false, true).timeout
	var priest := ossuary.boss_foe
	check(priest != null and priest.data.id == &"summoning_priest" and priest.view.rig != null, "The summoning priest comes in, drawn by its rig")
	var skeletons_before := ossuary.foes.filter(func(foe: Foe): return foe.data.id == &"skeleton").size()
	priest.receive(DamageInfo.make(float(priest.health.max_hp) * 0.55, Vector2.RIGHT))
	await wait(WaveRunner.MARK_TIME + 0.3)
	check(priest.phase == 2 and ossuary.foes.filter(func(foe: Foe): return foe.data.id == &"skeleton").size() > skeletons_before, "At half health it rages and calls skeletons")
	priest.receive(DamageInfo.make(100000.0, Vector2.RIGHT))
	for frame in 400:
		if not ended.is_empty():
			break
		if is_instance_valid(ossuary) and ossuary.is_inside_tree() and ossuary.choice.visible:
			ossuary.choice._select(0)
		await physics_frame
	check(ended.size() == 1 and ended[0].cleared and ended[0].chapter_id == "amethyst_mausoleum", "Felling it wins the third chapter")
	director.free()
	await process_frame

	# The last chapter, taken through to the master of echoes: its crowd is
	# wraiths and bells drawn from baked frames, its ground the abyss's, and
	# its boss comes in by its rig, rages, calls wraiths and falls.
	ended.clear()
	director = RunDirector.new()
	director.seed_value = 53
	director.chapter = load("res://data/chapters/abyss_of_echoes.tres")
	root.add_child(director)
	director.finished.connect(_on_finished)
	await process_frame
	check(director.run.route.size() == 5 and director.map_view._title.text.contains("残響の深淵"), "The last chapter lays out four layers and its boss")
	var abyss_seen := false
	var echoes_seen := false
	for layer in director.run.route.size() - 1:
		director.map_view._choose(director.map_view.current[0])
		await process_frame
		var deep := director.area
		deep.hero.controlled = false
		abyss_seen = abyss_seen or deep.data.theme == 6
		if deep.director != null:
			deep.director.advance(1.0)
			echoes_seen = echoes_seen or deep.foes.any(func(foe: Foe): return foe.data.id in [&"echo_wraith", &"mourning_bell"] and foe.view.sprite != null)
		await clear_area(director)
	check(abyss_seen, "Its areas lie on the abyss's ground")
	check(echoes_seen, "Its crowd comes in drawn from their baked frames")
	director.map_view._choose(director.run.route.nodes(director.run.route.size() - 1)[0])
	await process_frame
	var throne := director.area
	throne.hero.controlled = false
	throne.hero.health.max_hp = 100000
	throne.hero.health.hp = 100000
	await wait(BattleArea.BOSS_DELAY + BattleArea.BOSS_MARK_TIME + 0.4)
	await create_timer(BossIntro.total_time() + 0.3, true, false, true).timeout
	var master := throne.boss_foe
	check(master != null and master.data.id == &"master_of_echoes" and master.view.rig != null, "The master of echoes comes in, drawn by its rig")
	var wraiths_before := throne.foes.filter(func(foe: Foe): return foe.data.id == &"echo_wraith").size()
	master.receive(DamageInfo.make(float(master.health.max_hp) * 0.55, Vector2.RIGHT))
	await wait(WaveRunner.MARK_TIME + 0.3)
	check(master.phase == 2 and throne.foes.filter(func(foe: Foe): return foe.data.id == &"echo_wraith").size() > wraiths_before, "At half health it rages and calls wraiths")
	master.receive(DamageInfo.make(100000.0, Vector2.RIGHT))
	for frame in 400:
		if not ended.is_empty():
			break
		if is_instance_valid(throne) and throne.is_inside_tree() and throne.choice.visible:
			throne.choice._select(0)
		await physics_frame
	check(ended.size() == 1 and ended[0].cleared and ended[0].chapter_id == "abyss_of_echoes", "Felling it wins the last chapter")
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
	check(stop.buttons[0].disabled and stop.buttons[1].disabled and stop.reasons[1] != null and stop.reasons[1].text.contains("足りない") and stop.buttons[1].get_global_rect().encloses(stop.reasons[1].get_global_rect()), "A ware bought or too dear is offered but off, its row saying why")
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

	# The shelf of memories: a boon held given up for another, never itself.
	director = RunDirector.new()
	director.seed_value = 19
	root.add_child(director)
	await process_frame
	stop = director.event_view
	await stop_at(director, "res://data/areas/event_shelf.tres")
	check(stop.ids == [&"give", EventView.LEAVE] and stop.buttons[0].disabled, "With no boon held, the shelf has nothing to trade")
	stop.buttons[-1].pressed.emit()
	await process_frame
	var blade := director.run.build.find(&"blade_speed")
	director.run.build.take(blade)
	director.run.build.take(blade)
	director.run.build.take(director.run.build.find(&"brute_force"))
	await stop_at(director, "res://data/areas/event_shelf.tres")
	var trade := stop.ids.find(&"give:blade_speed")
	check(stop.ids.size() == 3 and trade >= 0 and stop.buttons[trade].text.contains("剣速 2") and stop.ids.has(&"give:brute_force"), "The shelf offers to trade each boon held, with its rank")
	stop.buttons[trade].pressed.emit()
	await process_frame
	check(director.run.build.rank(&"blade_speed") == 0 and director.choice.visible and not director.choice.offers.has(blade) and director.choice.offers.size() == director.run.card_count(), "The boon is given up, and a card of others is dealt")
	director.choice._select(0)
	await process_frame
	check(not stop.visible and director.run.build.owned().size() == 2 and director.map_view._note.text.contains("剣速"), "Taking one ends the stop, and the map tells the trade")
	director.free()
	await process_frame

	# The spring of cleansing: echo for a curse lifted, or a drink that heals;
	# either ends the stop.
	director = RunDirector.new()
	director.seed_value = 23
	root.add_child(director)
	await process_frame
	stop = director.event_view
	await stop_at(director, "res://data/areas/event_spring.tres")
	check(stop.ids == [&"cleanse", &"drink", EventView.LEAVE] and stop.buttons[0].disabled and stop.buttons[1].disabled, "With no curse and full health, the spring has nothing to give")
	stop.buttons[-1].pressed.emit()
	await process_frame
	var spring_defense := director.run.tuning.defense
	director.run.take_curse(&"frailty")
	director.run.echo = 80
	director.run.hp = 20
	await stop_at(director, "res://data/areas/event_spring.tres")
	check(stop.ids == [&"cleanse:frailty", &"drink", EventView.LEAVE] and stop.buttons[0].text.contains("脆さ") and not stop.buttons[0].disabled and not stop.buttons[1].disabled, "The spring offers to lift each curse for echo, or a drink")
	stop.buttons[0].pressed.emit()
	await process_frame
	check(director.run.curses.is_empty() and director.run.tuning.defense == spring_defense and director.run.echo == 80 - RunDirector.SPRING_PRICE and director.run.hp == 20 and not stop.visible, "Lifting the curse takes its harm away for echo, and ends the stop")
	director.run.take_curse(&"sluggish")
	director.run.echo = 10
	await stop_at(director, "res://data/areas/event_spring.tres")
	check(stop.buttons[0].disabled and stop.reasons[0].text.contains("足りない"), "A curse costs more echo than she has: offered, but off, its row saying why")
	stop.buttons[1].pressed.emit()
	await process_frame
	check(director.run.hp == 20 + roundi(director.max_hp() * RunDirector.SPRING_HEAL_SHARE) and director.run.curses == [&"sluggish"] and not stop.visible, "The drink heals instead, and ends the stop")
	director.free()
	await process_frame
	print("Run flow tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
