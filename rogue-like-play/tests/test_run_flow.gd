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
	# A boss's hall opens with its entrance, the world stopped: it is cleared
	# once the fight is on.
	var until := Time.get_ticks_msec() + roundi((BossIntro.total_time() + BattleArea.ENTRANCE_GRACE) * 1000.0) + 2000
	while area.staging and Time.get_ticks_msec() < until:
		await process_frame
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
	# An elite still standing when an area is cleared leaves the gems already
	# cut out of it.
	var timed := BattleArea.new()
	timed.setup(load("res://data/areas/moss_plain.tres"), RunState.new(5), 5)
	root.add_child(timed)
	await process_frame
	timed.hero.controlled = false
	timed.director.running = false
	var charger_data: FoeData = load("res://data/foes/raging_charger.tres")
	var standing := timed.spawn_foe(charger_data, timed.hero.global_position + Vector2(400, 0))
	standing.health.hp = standing.health.max_hp / 2
	var gems_before := timed.gems.total()
	timed.clear()
	check(timed.gems.total() == gems_before + roundi(charger_data.exp_reward * 0.5), "An elite half felled when the area is cleared leaves half its gems")
	timed.hit_stop.release()
	timed.free()
	await process_frame
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

	# The boss's layer: its gate stands dark, tolls, and the boss comes out with
	# its name; once a run, and a key cuts it short.
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
		var boss_page := boss_run.map_view.page
		var boss_point: RouteMap.Waypoint = boss_route.nodes(boss_route.size() - 1)[0]
		check(boss_page.open == [boss_point] and boss_page.revealing and boss_page.veiled(boss_point) and boss_page.tell(boss_point).name == RouteGates.VEILED_NAME, "The boss's layer open, its gate stands dark and its coming out begins")
		boss_page.accept()
		check(not boss_page.asked and boss_run.area == null, "Nothing is asked while it comes out")
		if cut_short:
			await create_timer(RouteGates.REVEAL_DARK + RouteGates.COMING_OUT * 0.3).timeout
			boss_page._take_key(_key(KEY_SPACE))
			check(not boss_page.revealing and not boss_page.veiled(boss_point) and boss_page.tell(boss_point).name == boss_point.area.display_name and is_equal_approx(boss_page._lit[0], 1.0), "A key cuts it short: the boss out, its gate hers to take")
		else:
			await create_timer(RouteGates.REVEAL_DARK + RouteGates.COMING_OUT + 0.1).timeout
			check(boss_page.revealing and not boss_page.veiled(boss_point) and boss_page._lit[0] > 0.9 and boss_page._tolled, "It tolls, comes out of the dark, and its name rises")
			await create_timer(RouteGates.REVEAL_HOLD + RouteGates.REVEAL_FADE + 0.2).timeout
			check(not boss_page.revealing and boss_page.selected() == boss_point, "Then the fork is hers again")
			boss_run.show_map()
			check(not boss_page.revealing and not boss_page.veiled(boss_point), "Opened again, the boss stands in the open")
		boss_run.queue_free()
		await process_frame

	# The director: the map, an area entered, cleared, rewarded, the next layer.
	var director := RunDirector.new()
	director.seed_value = 12
	root.add_child(director)
	await process_frame
	check(director.map_view.visible and director.map_view.route_layer == 0 and director.map_view.current == director.run.route.nodes(0), "A run opens on its route, the whole first layer to choose from")
	# The gates: every way open now is a gate before her, and the chapter's
	# whole route the tablet over them.
	var view := director.map_view
	var page := view.page
	var route := director.run.route
	check(page.size == root.get_visible_rect().size and page.theme_type_variation == &"Gates", "The page of gates fills the screen, in its own type")
	check(page.hero != null and page.hero.facing.y == -1 and page.has_focus(), "She stands at the fork with her back to the player, and the page holds the focus")
	await create_timer(RouteGates.RISE_TIME + RouteGates.RISE_STAGGER * 3.0 + 0.2).timeout
	var first: RouteMap.Waypoint = route.nodes(0)[0]
	check(page.selected() == first and page.cursor == 0 and not page.asked and is_equal_approx(page._lit[0], 1.0) and is_zero_approx(page._lit[1]), "The first gate is turned to and lit, nothing asked")
	# The hall: a gate of the chapter's painted stone for each way open, the
	# chapter's floor and painting behind them.
	check(page.gates.size() == page.open.size() and page.gates.all(func(gate: RouteGateView) -> bool: return gate.stone.texture == load(RouteGateView.STONES % route.chapter.id) and gate.figure.texture != null), "Each way open is a gate of the chapter's stone, with what leads it standing in it")
	var hall_light := page._hall.material as ShaderMaterial
	check(hall_light.get_shader_parameter(&"ground") == RouteGates.ground_of(route.chapter.id) and hall_light.get_shader_parameter(&"painting") == RouteGates.painting_of(route.chapter) and RouteGates.ground_of(route.chapter.id).get_width() == AreaGround.PAINTED_CELL * AreaGround.FLOOR_PERIOD, "The hall is floored with the chapter's own ground under its painting")
	check(page.gates[0].power() > page.gates[1].power() * 1.6 and page.gates[1].power() >= 0.5 and page.gates[0].grown() > page.gates[1].grown(), "The gate turned to stands larger and burns brighter; the others smoulder, bright enough to be weighed against it")
	# The floor is paved: the hall's flags, a causeway from each gate to the
	# round stone she stands on, the light of the gate turned to run down its
	# channel to her feet and the others' lying short of her.
	check(hall_light.get_shader_parameter(&"flags") == load(RouteGates.FLAGS) and hall_light.get_shader_parameter(&"road") == load(RouteGates.ROAD) and hall_light.get_shader_parameter(&"dais") == load(RouteGates.DAIS) and (hall_light.get_shader_parameter(&"stand") as Vector2).distance_to(RouteGates.HERO) < 8.0, "The hall is paved, a causeway running from each gate to the round stone she stands on")
	check(is_equal_approx(page._run[0], 1.0) and is_equal_approx(page._run[1], RouteGates.REST_RUN) and (hall_light.get_shader_parameter(&"road_power") as PackedFloat32Array)[0] > (hall_light.get_shader_parameter(&"road_power") as PackedFloat32Array)[1] * 3.0, "The light of the gate turned to has run down its channel to her feet; the others' lies short of her")
	# Each gate is dressed by its area's kind, and shows the place it leads to.
	for index in page.gates.size():
		var dressed := page.gates[index]
		var kind := RouteGates.kind_of((page.open[index] as RouteMap.Waypoint).area)
		check(dressed.kind == kind and (dressed.inside.material as ShaderMaterial).get_shader_parameter(&"beyond") == load(RouteGateView.INSIDES % kind) and dressed.has_fires() == (kind == RouteGateView.ARENA or kind == RouteGateView.BOSS) and (dressed.crest != null) == (kind != RouteGateView.FIELD) and dressed.stands.size() == (2 if dressed.has_fires() else 0), "Gate %d is dressed as its area's kind (%s), the place it leads to seen through it" % [index + 1, kind])
	check(RouteGates.kind_of(load("res://data/areas/moss_plain.tres")) == RouteGateView.FIELD and RouteGates.kind_of(arena_data) == RouteGateView.ARENA and RouteGates.kind_of(route.chapter.boss) == RouteGateView.BOSS and RouteGates.kind_of(route.chapter.events[0]) == RouteGateView.EVENT, "A field, a trial, an event and the boss each have their own gate")
	# A gate's outline tells its kind: every kind is dressed from the one
	# table, with parts no other kind's bare gate has.
	for kind: StringName in [RouteGateView.FIELD, RouteGateView.ARENA, RouteGateView.EVENT, RouteGateView.BOSS]:
		var worn := RouteGateView.new()
		root.add_child(worn)
		worn.setup(route.chapter.id, kind, null, Color.BLACK)
		var wears: Array = RouteGateView.DRESS[kind]
		check(wears.all(func(part: StringName) -> bool: return worn.wears(part)) and worn.ridges.size() == (2 if wears.has(&"ridges") else 0) and worn.banners.size() == (2 if wears.has(&"banners") else 0) and worn.charms.size() == (2 if wears.has(&"charms") else 0) and worn.candles.size() == (2 if wears.has(&"candles") else 0) and worn.wicks.size() == worn.candles.size() * RouteGateView.WICKS.size() and worn.pylons.size() == (2 if wears.has(&"pylons") else 0), "A %s's gate wears what its kind's row says, and nothing else" % kind)
		worn.free()
	check(RouteGateView.DRESS[RouteGateView.FIELD].is_empty() and RouteGateView.DRESS[RouteGateView.ARENA] != RouteGateView.DRESS[RouteGateView.EVENT] and RouteGateView.DRESS[RouteGateView.BOSS].has(&"pylons") and not RouteGateView.DRESS[RouteGateView.ARENA].has(&"pylons"), "A field's gate stands bare; a trial's, an event's and the boss's each wear their own")
	var roof := RouteGateView.roof_of(load(RouteGateView.STONES % route.chapter.id))
	check(roof[0].x == 0.0 and roof[1].y < roof[0].y and roof[0].y < load(RouteGateView.STONES % route.chapter.id).get_height() * 0.4, "The slope of a gate's roof is read from its stone, for the spiked iron to lie on")
	# What stands in a gate lives, and a foe she has met shows a little of
	# itself before its gate is turned to (one not met stays a shape).
	var living := page.gates[1].figure.material as ShaderMaterial
	check(page.gates[1].alive and is_equal_approx(living.get_shader_parameter(&"alive"), 1.0) and is_equal_approx(living.get_shader_parameter(&"glimpse"), RouteGateView.GLIMPSE) and is_zero_approx(living.get_shader_parameter(&"seen")) and page.gates[1].mist != null, "What stands in a gate not turned to lives and, being known, is dimly seen; mist lies over its feet")
	for chapter in Chapters.ALL:
		var light_art: Texture2D = load(RouteGateView.LIGHTS % chapter.id)
		var stone_art: Texture2D = load(RouteGateView.STONES % chapter.id)
		var opening := RouteGateView.opening_in(light_art)
		check(stone_art.get_size() == light_art.get_size() and opening.size.x > stone_art.get_width() * 0.5 and opening.size.y > stone_art.get_height() * 0.6 and opening.end.y >= stone_art.get_height() - 1.0 and opening.position.x > 0.0 and opening.end.x < stone_art.get_width(), "%s has its own gate, its opening found within its stone" % chapter.id)
	var told := page.tell(first)
	check(told.name == first.area.display_name and told.kind == first.area.kind_name() and told.danger == first.area.difficulty and told.reward == first.reward and told.goal == first.area.condition and told.summary == first.area.foe_summary and told.state == "", "What waits behind a gate and what it gives are told: its name, kind, danger, reward and goal")
	check(told.foes.size() == Chapters.area_foes(first.area).size() and told.foes.size() > 0 and told.foes.all(func(entry: Array) -> bool: return entry[1]), "With its foes, all pictured when no record says otherwise")
	check(told.echo == (director.run.echo_reward(first.area.echo) if first.reward == AreaData.Reward.ECHO else director.run.clear_echo(first.area)) and told.echo > 0, "And the echo clearing it brings in all")
	var all_points: Array = []
	for index in route.size():
		all_points.append_array(route.nodes(index))
	check(all_points.all(func(point: RouteMap.Waypoint) -> bool: return page.mark(point) == (RouteGates.Mark.OPEN if point.layer == 0 else RouteGates.Mark.AHEAD)), "At the start the first layer is open and every area further on within reach")
	# The tablet over the hall: the whole route cut into it, a layer a step
	# along it, and its jewels lit as the gates are.
	var slab := page.tablet.rect()
	var step := page.thread_spot(route.nodes(1)[0]).x - page.thread_spot(route.nodes(0)[0]).x
	check(is_equal_approx(step, (slab.size.x - RouteTablet.INSET * 2.0) / route.size()) and all_points.all(func(point: RouteMap.Waypoint) -> bool: return slab.grow(-RouteTablet.SOCKET).has_point(page.thread_spot(point))) and is_equal_approx(page.thread_spot(null).x, slab.position.x + RouteTablet.INSET) and page.tablet.slab.texture == load(RouteTablet.SLAB), "The whole route is cut into the tablet, a layer a step along it")
	check(float(page.tablet._held[first]) > float(page.tablet._held[route.nodes(0)[1]]) * 1.5 and float(page.tablet._held[route.nodes(0)[1]]) > float(page.tablet._held[route.nodes(1)[0]]) and float(page.tablet._held[route.nodes(1)[0]]) > 0.0, "On it the gate turned to shines brightest, the other ways open less, the areas further on faintly")
	# What an area is to her is told by its socket's size: the gate turned
	# to the largest, the other ways open next, the areas further on smaller.
	check(is_equal_approx(float(page.tablet._sized[first]), RouteTablet.CHOSEN) and is_equal_approx(float(page.tablet._sized[route.nodes(0)[1]]), RouteTablet.OPEN) and is_equal_approx(float(page.tablet._sized[route.nodes(1)[0]]), RouteTablet.SOCKET) and RouteTablet.CHOSEN > RouteTablet.OPEN and RouteTablet.OPEN > RouteTablet.SOCKET and RouteTablet.SOCKET > RouteTablet.TAKEN and RouteTablet.HERE > RouteTablet.TAKEN, "The sockets tell by their size what an area is to her")
	# A way runs straight out of its area, aslant, and straight into the next.
	var groove := page.tablet.way(route.nodes(0)[0], (route.nodes(0)[0] as RouteMap.Waypoint).next[0])
	check(groove.size() == 4 and is_equal_approx(groove[0].y, groove[1].y) and is_equal_approx(groove[2].y, groove[3].y) and is_equal_approx(groove[1].x - groove[0].x, RouteTablet.STUB) and groove[0] == page.thread_spot(route.nodes(0)[0]) and page.tablet.along(null, first, 1.0).is_equal_approx(page.thread_spot(first)) and page.tablet.along(null, first, 0.0).is_equal_approx(page.thread_spot(null)), "A way on the tablet runs straight out of its area, aslant, and straight into the next")
	# What stands in a gate: the area's leading foe painted, or an event's object.
	var fights: Array = all_points.filter(func(point: RouteMap.Waypoint) -> bool: return not point.area.is_event())
	check(fights.all(func(point: RouteMap.Waypoint) -> bool: return page.portrait_of(point.area) != null and page.portrait_of(point.area) == EnemySprites.codex_portrait(RouteStage.leader(point.area).visual_id)), "A fight's gate holds its leading foe, painted")
	var events: Array = all_points.filter(func(point: RouteMap.Waypoint) -> bool: return point.area.is_event())
	check(not events.is_empty() and events.all(func(point: RouteMap.Waypoint) -> bool:
		var stop := page.tell(point)
		return page.portrait_of(point.area) == RouteStage.prop_for(point.area.event) and stop.danger == 0 and stop.reward == -1 and stop.reward_words == point.area.condition and stop.foes.is_empty()), "An event's gate holds its object instead, and tells its trade")
	# A foe not met stays a shape in its gate; an event's object and the boss
	# (whose coming out is the meeting) are seen.
	check(all_points.all(func(point: RouteMap.Waypoint) -> bool: return page.figure_known(point)), "With no record every gate's figure is seen once turned to")
	page.meta = MetaProgress.new()
	check(not page.figure_known(first) and page.tell(first).foes.all(func(entry: Array) -> bool: return not entry[1]), "A leading foe not met stays a shape, as its picture among the foes does")
	check(events.all(func(point: RouteMap.Waypoint) -> bool: return page.figure_known(point)) and page.figure_known(route.nodes(route.size() - 1)[0]), "An event's object and the boss are seen all the same")
	page.meta.met[String(RouteStage.leader(first.area).id)] = true
	check(page.figure_known(first), "Once met, it is seen")
	page.meta = null
	var field: AreaData = fights.map(func(point: RouteMap.Waypoint) -> AreaData: return point.area).filter(func(area: AreaData) -> bool: return area.spawn_table != null)[0]
	var heaviest: SpawnEntry = field.spawn_table.entries[0]
	for entry: SpawnEntry in field.spawn_table.entries:
		if entry.weight > heaviest.weight:
			heaviest = entry
	check(RouteStage.leader(field) == heaviest.foe and RouteStage.company(field) != null and RouteStage.company(field) != heaviest.foe, "A field is shown by the kind met most, another coming with it")
	var boss_point: RouteMap.Waypoint = route.nodes(route.size() - 1)[0]
	var hidden := page.tell(boss_point)
	check(page.veiled(boss_point) and hidden.name == RouteGates.VEILED_NAME and hidden.goal == RouteGates.VEILED_NOTE and hidden.reward == -1 and hidden.foes.is_empty() and hidden.danger == 0, "The boss waits in the dark: it names nothing, only that something waits")
	# Reading the tablet: any area can be read, only an open one gone to.
	var later: RouteMap.Waypoint = route.nodes(1)[0]
	page._point([&"node", later])
	check(page.read() == later and page.tell(later).name == later.area.display_name and page.tell(later).state == RouteGates.AHEAD_NOTE, "A later area can be read on the thread")
	page._press([&"node", later])
	page.pick(later)
	view._choose(later)
	check(view.visible and director.area == null and not page.asked, "Not entered, nor asked for")
	page._point(null)
	check(page.read() == null, "Pointing away reads nothing")
	page._take_key(_key(KEY_UP))
	check(page.threading and page.read() == first, "Up takes the keys to the thread, on the gate's own area")
	page._take_key(_key(KEY_RIGHT))
	check(page.read() != null and page.read().layer == 1, "The arrows go along it, a layer on")
	page._take_key(_key(KEY_ESCAPE))
	check(not page.threading and page.read() == null and not director.map_menu.visible, "Esc there comes back to the gates, not to the run's menu")
	# What is told, and when: every gate its danger and what it gives, the gate
	# turned to its goal, foes and ways on, and the rest on the tablet's card.
	for point: RouteMap.Waypoint in page.open:
		var short := page.tell(point)
		check(page._gives(short) == ("残響 %s" % UIFormat.amount(short.echo) if point.reward == AreaData.Reward.ECHO else short.reward_words) and not page._gives(short).is_empty(), "Under every gate stands what it gives, the echo with its amount")
	check(page._goal_of(told) == first.area.condition and page.block_height(first) > RouteGates.BLOCK_TOP + RouteGates.TILE + RouteGates.ONWARD_LINE, "Under the gate turned to stand its goal, its foes and the ways on")
	check(page._goal_of(page.tell(events[0])) == (events[0] as RouteMap.Waypoint).area.condition and page._gives(page.tell(events[0])) == "イベント", "An event tells its trade there, in place of a goal")
	check(page.guide.get_child_count() == 4, "At the gates the keys tell the four things they do")
	(page.guide.get_child(2) as Button).pressed.emit()
	check(page.threading and page.read() == first and page.guide.get_child_count() == 2, "The details can be opened from the keys' hint too: the card of the gate turned to")
	page.choose(1)
	check(page.threading and page.read() == page.open[1], "And the card follows the gate turned to")
	(page.guide.get_child(1) as Button).pressed.emit()
	page.choose(0)
	check(not page.threading and page.cursor == 0 and page.read() == null, "Its hint closes it again")
	for point: RouteMap.Waypoint in page.open:
		var lost := page.closes(point)
		check(lost.keys().all(func(other: RouteMap.Waypoint) -> bool: return page.reach.has(other) and not page.reach_from([point]).has(other) and not page.open.has(other)) and lost.size() + page.reach_from([point]).size() + page.open.size() - 1 == page.reach.size(), "A pick closes just the areas further on that no way from it leads to")
	page._take_key(_key(KEY_RIGHT))
	check(page.cursor == 1 and not page.asked, "Right turns to the next gate")
	page._take_key(_key(KEY_LEFT))
	page._take_key(_key(KEY_LEFT))
	check(page.cursor == 0, "Left turns back, and no further than the first")
	var start: Vector2 = page.hero.position
	page._press([&"gate", 0])
	check(page.asked and not page.traveling and director.area == null and view.visible, "A press on the gate turned to first asks whether to go there")
	check(page.guide.get_child_count() == 2, "Asked, the keys tell only going and taking it back")
	# The grilles come down in the gates not chosen, and go up again.
	await create_timer(0.8).timeout
	check(is_zero_approx(page._drop[0]) and is_equal_approx(page._drop[1], 1.0) and is_equal_approx(page._drop[2], 1.0) and page._landed[1] >= 0.0 and page.gates[1].bars.visible and page.gates[1].power() < page.gates[0].power() * 0.25, "Asked, a grille has fallen in each gate not chosen and its light is all but out")
	check(page._answered and is_zero_approx(page._run[1]) and is_zero_approx(page._run[2]) and is_equal_approx(page.grille_of(page.open[1]), 1.0) and float(page.tablet._held[page.open[1]]) < 0.15 and float(page.tablet._held[page.open[0]]) > 1.0 and page._eye_zoom > 1.0, "The gate chosen has answered; the others' causeways and their jewels on the tablet have gone dark, and the view leans in")
	page._take_key(_key(KEY_ESCAPE))
	check(not page.asked and view.visible and not director.map_menu.visible, "Esc takes the question back and stays at the fork")
	await create_timer(RouteGates.LIFT_TIME + 0.2).timeout
	check(is_zero_approx(page._drop[1]) and is_zero_approx(page._drop[2]) and not page.gates[1].bars.visible and is_equal_approx(page._eye_zoom, 1.0), "Taken back, the grilles are drawn up again and the view stands back")
	page._take_key(_key(KEY_2))
	check(page.cursor == 1 and page.asked, "A number key turns to its gate and asks at once")
	page._press([&"gate", 0])
	check(page.cursor == 0 and not page.asked, "Turning to another gate takes the question back")
	page._take_key(_key(KEY_ENTER))
	page._take_key(_key(KEY_ENTER))
	check(page.traveling and director.area == null and view.visible, "Enter asks and again goes: she walks into the gate's light, entering nothing yet")
	page._take_key(_key(KEY_2))
	await create_timer(RouteGates.TRAVEL_TIME * 0.5).timeout
	check(page.hero.position != start and page.hero.rig.animation_player.current_animation == CharacterRig.WALK and director.area == null and page.cursor == 0, "She walks, and a key on the way does nothing")
	check(page._eye_zoom > 1.05 and page._eye.x < RouteGates.DESIGN.x * 0.5 and page.gates[0].near > 0.0 and is_zero_approx(page.leaving()), "The view goes after her toward her gate, the screen not dark yet")
	page._take_key(_key(KEY_ENTER))
	check(page.traveling and page.going() >= RouteGates.CURTAIN_FROM - 0.02 and director.area == null, "Enter on the way hurries her to where the screen goes dark")
	await create_timer(RouteGates.TRAVEL_TIME * (1.0 - RouteGates.CURTAIN_FROM) * 0.75).timeout
	check(page.traveling and director.map_view.curtain.layer > director.map_view.layer and director.map_view._dark.color.a > 0.5, "As she goes through the gate the screen goes dark, over everything")
	var exit := page.exit_point()
	check(page.hero.position.y < RouteGates.FLOOR and page.hero.scale.y < RouteGates.FAR_SIZE and page._crossed and exit.x > 0.0 and exit.x < 1.0 and exit.y > 0.0 and exit.y < 1.0 and ((director.map_view._dark.material as ShaderMaterial).get_shader_parameter(&"centre") as Vector2).distance_to(exit) < 0.05, "She has crossed the threshold and walks on into the place beyond, the dark closing on its far light")
	await create_timer(RouteGates.TRAVEL_TIME * 0.5 + 0.15).timeout
	check(director.area != null and director.area.data == first.area and not director.map_view.visible, "A choice enters its area")
	await create_timer(RouteMapView.LIFT_TIME + 0.1).timeout
	check(director.map_view._lifting != null and is_zero_approx(director.map_view._dark.color.a), "And the dark she walked into has lifted off the area")
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
	# A three-way trial on the last layer has no ways to open: it gives echo instead.
	var trial: AreaData = load("res://data/areas/sanctum_trial.tres")
	var arena_plain: AreaData = load("res://data/areas/pillar_arena.tres")
	var last_layer := director.run.route.size() - 2
	check(director.run.trial_echo(trial, last_layer) == roundi(trial.echo * RunState.LAST_TRIAL_SHARE) and director.run.trial_echo(trial, last_layer - 1) == 0 and director.run.trial_echo(arena_plain, last_layer) == 0, "A three-way trial on the last layer gives echo in place of ways")
	var carried := director.run.hp
	var after_first: RouteMap.Waypoint = director.run.taken[0]
	check(director.map_view.current == after_first.next and after_first.next.size() <= after_first.area.branches.y, "Past the first layer, only the paths from the area taken are open")
	var gates := director.map_view.page
	check(gates.mark(after_first) == RouteGates.Mark.TAKEN and gates.here() == after_first and gates.tell(after_first).state == RouteGates.PASSED_NOTE, "The area she cleared is the way walked")
	var shut := director.run.route.nodes(1).filter(func(point: RouteMap.Waypoint): return not after_first.next.has(point))
	check(shut.all(func(point: RouteMap.Waypoint): return gates.mark(point) == RouteGates.Mark.SHUT and gates.tell(point).state == RouteGates.SHUT_NOTE), "The rest of that layer is shut")
	var forgone := director.run.route.nodes(0).filter(func(point: RouteMap.Waypoint): return point != after_first)
	check(forgone.all(func(point: RouteMap.Waypoint): return gates.mark(point) == RouteGates.Mark.PASSED and gates.tell(point).state == RouteGates.PASSED_NOTE), "The first layer's other areas are passed by")
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
	check(ended[0].fallen_to == null and journey.ended_at == 2 and journey.spots.size() == director.run.route.size() + 1 and not (journey.figure is DirectionalRig) and journey.caption.text == "%sに倒された" % RouteStage.leader(last_area).display_name, "A blow that names no foe leaves the area's foe standing where she fell")
	var dummy := Foe.new()
	dummy.data = RouteStage.leader(last_area)
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
	check(director.run.route.size() == 5 and director.map_view.page.title_text.contains("風哭きの樹海"), "The run lays out the chapter it was given")
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
	await create_timer(BossIntro.total_time() + 0.5, true, false, true).timeout
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
	check(director.run.route.size() == 5 and director.map_view.page.title_text.contains("紫晶の霊廟"), "The third chapter lays out four layers and its boss")
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
	await create_timer(BossIntro.total_time() + 0.5, true, false, true).timeout
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
	check(director.run.route.size() == 5 and director.map_view.page.title_text.contains("残響の深淵"), "The last chapter lays out four layers and its boss")
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
	await create_timer(BossIntro.total_time() + 0.5, true, false, true).timeout
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
	check(director.choice.visible and director.choice.declinable and not stop.visible and director.run.echo == 100, "The merchant's cards are shown before the echo is paid")
	var shown: Array[BoonData] = director.choice.offers.duplicate()
	director.choice.armed = true
	director.choice._decline()
	await process_frame
	check(not director.choice.visible and stop.visible and director.run.echo == 100 and not stop.buttons[0].disabled, "Left untaken, they cost nothing and the merchant is still there")
	stop.buttons[0].pressed.emit()
	await process_frame
	check(director.choice.offers == shown, "Looked at again, the cards are the same")
	var owned := director.run.build.owned().size()
	director.choice._select(0)
	await process_frame
	check(director.run.echo == 100 - RunDirector.MERCHANT_BOON_PRICE, "A boon taken is paid for in echo")
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
	check(director.map_view.page.note_text.contains("行商人"), "The map tells what the stop gave")

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
	check(director.run.hp == 0 and director.choice.visible and director.choice.declinable, "The altar shows its cards before her health is given")
	director.choice._select(0)
	await process_frame
	check(director.run.hp == director.max_hp() - director.altar_cost(), "Her health is given as the boon is taken")
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
	check(director.run.curses.is_empty() and director.choice.visible and director.choice.declinable, "The stone shows its cards before the curse is laid")
	director.choice._select(0)
	await process_frame
	check(director.run.curses == [curse] and not stop.visible and director.run.layer == 3, "The curse is taken with a boon, and the stop ends")
	check(director.run.echo_reward(100) == echo_without + roundi(100 * RunState.CURSE_ECHO), "A curse raises the echo rewards")
	check(director.map_view.page.curses_text.contains(RunState.CURSES[curse][0]), "The map shows the curses she carries")
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
	check(stop.ids.size() == 3 and trade >= 0 and stop.buttons[trade].text.contains("剣速 2") and stop.buttons[trade].text.contains("2つ") and stop.ids.has(&"give:brute_force"), "The shelf offers to trade each boon held, with its rank and the picks it gives")
	stop.buttons[trade].pressed.emit()
	await process_frame
	check(director.run.build.rank(&"blade_speed") == 2 and director.choice.visible and director.choice.declinable and not director.choice.offers.has(blade) and director.choice.offers.size() == director.run.card_count(), "A card of other boons is shown before the boon is given up")
	director.choice._select(0)
	await process_frame
	check(director.run.build.rank(&"blade_speed") == 0 and director.choice.visible and not director.choice.declinable and not director.choice.offers.has(blade), "Given up with its two ranks, it owes a second pick")
	director.choice._select(0)
	await process_frame
	var ranks_held := 0
	for held: BoonData in director.run.build.owned():
		ranks_held += director.run.build.rank(held.id)
	check(not stop.visible and ranks_held == 3 and director.run.build.rank(&"blade_speed") == 0 and director.map_view.page.note_text.contains("剣速"), "A pick for each rank given up ends the stop, and the map tells the trade")
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

	# The run's menu over the map: the build, where the run stands with the
	# curses told, the controls, and the way out with the echo kept.
	director = RunDirector.new()
	director.seed_value = 29
	root.add_child(director)
	ended.clear()
	director.finished.connect(func(result: Dictionary): ended.append(result))
	await wait(RouteGates.RISE_TIME + 0.6)
	director.run.build.take(director.run.build.find(&"blade_speed"))
	director.run.take_curse(&"frailty")
	director.run.echo = 40
	director.map_view.page._take_key(_key(KEY_ESCAPE))
	await process_frame
	var map_menu := director.map_menu
	check(map_menu.visible and director.map_view.covered and map_menu.resume_button.caption == "分かれ道に戻る" and map_menu.resume_button.has_focus(), "Esc on the map opens the run's menu")
	var state_lines: Array = map_menu.state_box.get_children().map(func(line: Label) -> String: return line.text)
	check(state_lines.size() == 3 and (state_lines[0] as String).contains(director.chapter.display_name) and (state_lines[0] as String).contains("第1層") and (state_lines[1] as String).contains("脆さ") and state_lines[2] == RunState.CURSES[&"frailty"][1], "It tells the chapter, the layer and each curse with what it does")
	check(map_menu.build_grid.get_child_count() == 1 and map_menu.build_name.text == "剣速", "And the build, as the fight's menu does")
	director.map_view.pick(director.map_view.current[0])
	check(not director.map_view.page.asked, "Nothing is picked at the fork under the menu")
	map_menu.controls_button.pressed.emit()
	await process_frame
	check(map_menu.showing_settings() and map_menu.settings_page.help_shown and map_menu.settings_page.selected_topic == HubSettings.TOPIC_CONTROLS, "The controls open straight from the menu")
	map_menu._unhandled_input(_key(KEY_ESCAPE))
	await process_frame
	check(map_menu.visible and not map_menu.showing_settings() and not map_menu.settings_page.help_shown, "Back from them leads to the menu")
	check(map_menu.controls_button.has_focus(), "With the focus back on the controls entry (focus: %s)" % root.gui_get_focus_owner())
	map_menu.open_settings()
	await process_frame
	check(map_menu.settings_page.has_focus() and not map_menu.settings_page.shown_rows().has(HubSettings.LANGUAGE_ROW) and map_menu.settings_page.shown_rows().size() == 9, "The settings open over a run with the focus on their list, without the language")
	map_menu.back()
	map_menu.controls_button.grab_focus()
	map_menu._unhandled_input(_key(KEY_ESCAPE))
	await process_frame
	check(not map_menu.visible and not director.map_view.covered, "Esc again lifts the menu off the map")
	director.open_map_menu()
	map_menu.abort_button.pressed.emit()
	await process_frame
	check(director.map_prompt.visible and not map_menu.visible, "Leaving the run from the map is asked first")
	director.map_prompt.confirmed.emit()
	await process_frame
	check(ended.size() == 1 and ended[0].abandoned and not ended[0].cleared and ended[0].echo == 40 and director.end_view.visible, "Left from the map, the run ends with its echo kept")
	director.free()
	await process_frame
	print("Run flow tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
