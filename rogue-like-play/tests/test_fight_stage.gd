extends SceneTree

# The fight shown outside a run, and that it stays apart from the game: the
# stage (FightStage) plays a real fight in its own window, stops only itself
# on a hit, runs while the game is stopped, starts every showing on a fresh
# area and leaves nothing behind when hidden; the bestiary's watch leaf
# shows a met foe's ways and nothing of an unmet one, and a page opened is
# no longer new (kept in the save, with old saves reading as nothing new);
# the help's demonstrations play and stop with the page; the settings try a
# setting with the fight, a battle tune or the field's air, each stopped on
# leaving its row; and the practice ground keeps nothing of what is done in
# it. None of them touches the progress, the save or a run.

var failures := 0
var checks := 0
var folder := ""


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func make_main(echo: int, save_path: String = "") -> Node:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.show_opening = false
	main.saving_enabled = not save_path.is_empty()
	if not save_path.is_empty():
		main.store.path = save_path
	root.add_child(main)
	if save_path.is_empty():
		main.meta.echo = echo
		main.get_node("Hub").refresh(main.meta)
	return main


func frames(count: int) -> void:
	for frame in count:
		await physics_frame


func run_tests() -> void:
	folder = "res://.godot/stage-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await _stage()
	await _codex()
	await _help_and_settings()
	await _practice()
	print("Fight stage: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# The stage itself.
func _stage() -> void:
	var host := Control.new()
	host.size = Vector2(800.0, 450.0)
	root.add_child(host)
	var stage := FightStage.new()
	host.add_child(stage)
	stage.size = host.size
	await process_frame
	check(not stage.playing() and stage.viewport.get_child_count() == 0, "A stage given nothing shows nothing")
	stage.show_scene(StageScenes.scene(&"strike"))
	var first := stage.area
	check(stage.playing() and first.hero != null and first.foes.size() == 2 and not first.hero.controlled, "A scene puts the fight's own hero and foes in the stage's area, she steered by the scene")
	check(first.get_viewport() == stage.viewport and first.get_world_2d() != root.get_world_2d(), "The area stands in the stage's own world, apart from the game's")
	var slowed := false
	var stopped := false
	var hurt := false
	var began := Time.get_ticks_msec()
	while stage.area == first and Time.get_ticks_msec() - began < 9000:
		await physics_frame
		slowed = slowed or not is_equal_approx(Engine.time_scale, 1.0)
		stopped = stopped or paused
		if is_instance_valid(first):
			hurt = hurt or first.kills > 0 or first.foes.any(func(foe: Foe) -> bool: return foe.health.hp < foe.health.max_hp)
	check(hurt, "Her blows land on the stage's foes as in a fight")
	check(not slowed and not stopped, "A hit shown on the stage stops only the stage: the engine's time and the game go on")
	await frames(30)
	check(stage.area != null and stage.area != first and not is_instance_valid(first), "Its period over, the scene starts again on a fresh area and the old one is gone")
	# It runs while the game is stopped.
	paused = true
	var clock: float = stage.area._clock
	await frames(20)
	check(stage.area._clock > clock, "The stage plays while the game is stopped")
	paused = false
	# Every scene of the help and the settings plays.
	var ids: Array[StringName] = [&"shake", &"sounds"]
	for entry: Array in StageScenes.CONTROLS:
		ids.append(entry[0])
	var played := true
	var seen := true
	for id in ids:
		stage.show_scene(StageScenes.scene(id))
		await frames(40)
		played = played and stage.area != null and stage.area.hero != null and stage.area._clock > 0.3 and stage.area.period > 0.0
		# One scene straight after another: the view is the new area's.
		seen = seen and stage.viewport.get_camera_2d() == stage.area.camera and stage.area.camera.global_position.distance_to(stage.area.middle()) < 1.0
	check(played and ids.size() == StageScenes.CONTROLS.size() + 2, "Each scene of the help's moves and the settings' trials builds and plays")
	check(seen, "A scene put on straight after another is looked at by its own camera, over the room's middle")
	# Hidden, nothing of it is left; shown again, it plays again.
	stage.hide()
	await process_frame
	check(stage.area == null and stage.viewport.get_child_count() == 0 and stage.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden, the stage frees its area and draws nothing")
	stage.show()
	await process_frame
	check(stage.playing(), "Shown again, it plays its scene again")
	stage.halt()
	stage.show_scene(StageScenes.scene(&"move"))
	stage.halt()
	check(not stage.playing() and stage.viewport.get_child_count() == 0 and is_equal_approx(Engine.time_scale, 1.0) and not paused, "Halted, nothing is left running")
	host.free()
	await process_frame


# The bestiary's watch leaf and its new marks.
func _codex() -> void:
	var path := folder + "/progress.json"
	var main := make_main(0, path)
	await process_frame
	var hub = main.get_node("Hub")
	var rat: FoeData = load("res://data/foes/dashing_rat.tres")
	var king: FoeData = load("res://data/foes/ruin_king.tres")
	main.meta.met[rat.id] = true
	main.meta.met[king.id] = true
	check(main.meta.is_new(rat.id) and main.meta.is_new(king.id) and not main.meta.is_new(&"wandering_sentinel"), "A foe met and not yet looked up is new; one not met is not")
	hub.refresh(main.meta)
	hub.show_page("codex")
	await process_frame
	var codex: HubCodex = hub.codex_page
	var unmet := codex.listed.find(load("res://data/foes/wandering_sentinel.tres"))
	codex.go_to(codex.listed.find(load("res://data/foes/mud_swell.tres")))
	codex.go_to(unmet)
	codex.turn_leaf()
	check(codex.leaf == 0 and not codex.stage.playing() and codex._motions.is_empty(), "A foe not met has no watch leaf: nothing of how it moves or strikes is shown")
	codex.go_to(codex.listed.find(rat))
	check(codex.told.fresh and not main.meta.is_new(rat.id), "Opening a new foe's page marks it on that page, and it is new no longer")
	codex.turn_leaf()
	await frames(4)
	check(codex.leaf == 1 and codex.stage.playing() and codex.stage.area.foes.size() == 1 and codex.stage.area.foes[0].data == rat and codex.stage.area.hero != null, "A met foe's watch leaf puts the foe itself on the stage, beside her")
	var ways := HubCodex.motions_of(rat)
	check(ways.size() == 2 + rat.attacks.size() + rat.phase_two_attacks.size() and ways[0][0] == &"hunt" and ways[1][0] == &"still" and ways[2][3] == rat.attacks[0], "Its ways to be watched are hunting, standing, and each of its own attacks")
	codex.choose_motion(2)
	await frames(4)
	var striker: Foe = codex.stage.area.foes[0]
	var struck := false
	for frame in 240:
		await physics_frame
		if is_instance_valid(striker) and striker.attack == rat.attacks[0]:
			struck = true
			break
	check(struck, "Watching an attack, the foe makes that attack with its own data")
	var king_ways := HubCodex.motions_of(king)
	check(king_ways.any(func(way: Array) -> bool: return way[4]) and HubCodex.motion_name(king_ways[-1]).ends_with("（怒り）"), "A boss's attacks of its rage are listed as such")
	var echo_before: int = main.meta.echo
	var runs_before: int = main.meta.runs
	hub.show_page("home")
	await process_frame
	check(not codex.stage.playing() and codex.leaf == 0, "Leaving the bestiary stops what it was showing")
	check(main.meta.echo == echo_before and main.meta.runs == runs_before and main.active_run == null, "Watching changed nothing of the progress and began no run")
	# The pages opened are kept; an old save reads as nothing new.
	var reader := MetaStore.new()
	reader.path = path
	var saved := reader.load_progress()
	check(saved.noted.has(rat.id) and not saved.is_new(rat.id) and saved.is_new(king.id), "The pages opened are saved when the bestiary is left, and the others stay new")
	var old := MetaCodec.encode(main.meta)
	old.erase("noted")
	var read := MetaCodec.decode(old)
	check(read != null and not read.is_new(king.id) and read.has_met(king.id), "A save from before the marks reads with nothing new")
	main.free()
	await process_frame


# The help's demonstrations and the settings' trials.
func _help_and_settings() -> void:
	var main := make_main(0)
	await process_frame
	var hub = main.get_node("Hub")
	hub.show_page("settings")
	await process_frame
	var page: HubSettings = hub.settings_page
	var before := [page.settings.volume, page.settings.music_volume, page.settings.effects_volume, page.settings.ambience_volume, page.settings.shake_level]
	# The trials follow the cursor.
	page.choose(0)
	await frames(3)
	check(page.stage.playing() and page.stage.visible and page._staged == &"sounds", "On a volume the fight plays in the stage, to be heard")
	page.choose(HubSettings.MUSIC_ROW)
	await frames(3)
	check(not page.stage.playing() and page._tuning and GameMusic.find(main).track == &"battle", "On the music's volume a battle tune plays, and the fight stops")
	page.choose(HubSettings.AMBIENCE_ROW)
	await frames(3)
	check(not page._tuning and GameMusic.find(main).track == &"hub" and page._air != null and page._air.bus == GameSettings.AMBIENCE_BUS, "On the ambience's the base's tune is back and the field's air sounds on its bus")
	page.choose(HubSettings.SHAKE_ROW)
	await frames(3)
	var air_gone := page._air == null
	check(air_gone and page.stage.playing() and page._staged == &"shake" and is_equal_approx(page.stage.area.shake_scale, page.settings.shake_scale()), "On the shake, blows are given and taken at the strength set")
	# From one trial straight to another (no row without one between).
	page.choose(0)
	await frames(6)
	page.choose(HubSettings.SHAKE_ROW)
	await frames(30)
	check(page._staged == &"shake" and page.stage.viewport.get_camera_2d() == page.stage.area.camera, "A trial put on straight after another is still looked at by its own camera")
	var shaking := page.stage.area
	page.put(HubSettings.SHAKE_ROW, 2)
	await frames(3)
	check(page.stage.area != shaking and is_equal_approx(page.stage.area.shake_scale, 0.0), "A change of the shake is tried at once, from the start")
	page.put(HubSettings.SHAKE_ROW, int(before[4]))
	page.choose(HubSettings.DISPLAY_ROW)
	await frames(3)
	check(not page.stage.playing() and not page.stage.visible, "A setting with nothing to try shows no fight")
	# Leaving the page stops everything.
	page.choose(HubSettings.MUSIC_ROW)
	await frames(3)
	hub.show_page("home")
	await frames(3)
	check(not page._tuning and GameMusic.find(main).track == &"hub" and not page.stage.playing() and page._air == null, "Leaving the settings ends the trial: the base's tune, no fight, no air")
	check([page.settings.volume, page.settings.music_volume, page.settings.effects_volume, page.settings.ambience_volume, page.settings.shake_level] == before, "Trying changed no setting")
	# The help's demonstrations.
	hub.open_help(HubSettings.TOPIC_DEMOS)
	await frames(3)
	var help: HelpView = page.help_view
	check(HelpView.shows_demos(help.topic) and help.stage.playing() and help.stage.visible and not page.stage.playing(), "The help's demonstrations play a move in their window")
	var shown := help.stage.area
	help.choose_demo(3)
	await frames(3)
	check(help.demo == 3 and help.stage.area != shown, "Another move is another scene")
	shown = help.stage.area
	help.choose_demo(3)
	await frames(3)
	check(help.stage.area != shown, "The same move asked for again plays from its start")
	# The fight's own action slots stand in the window for the move shown,
	# and follow the stage's hero as the HUD follows the fight's.
	check(help.slots[&"dash"].visible and not help.slots[&"skill"].visible and not help.slots[&"special"].visible and help.slots[&"dash"] is ActionSlot, "The dash is shown with the HUD's own dash slot, and no other")
	help.choose_demo(4)
	var waited := false
	for frame in 200:
		await physics_frame
		if help.stage.area != null and help.stage.area._clock > 1.1:
			waited = true
			break
	await process_frame
	check(waited and help.slots[&"skill"].visible and help.slots[&"skill_2"].visible and help.slots[&"skill"].share < 1.0 and not help.slots[&"skill"].note_label.text.is_empty() and is_equal_approx(help.slots[&"skill_2"].share, 1.0), "A skill used, its slot darkens and counts its wait down; the other stays ready")
	help.choose(0)
	await frames(3)
	check(not help.stage.playing() and help.slots.values().all(func(slot: ActionSlot) -> bool: return not slot.visible), "Another topic stops the window and takes its slots away")
	help.choose(HubSettings.TOPIC_DEMOS)
	await frames(3)
	check(help.stage.playing() and help.allows_practice, "Back on the demonstrations it plays again, and the base's help offers the practice ground")
	page.close_help()
	hub.show_page("home")
	await frames(3)
	check(not help.stage.playing() and is_equal_approx(Engine.time_scale, 1.0) and not paused, "The help closed, nothing of it is left running")
	main.free()
	await process_frame


# The practice ground keeps nothing.
func _practice() -> void:
	var path := folder + "/practice.json"
	var main := make_main(0, path)
	await process_frame
	var hub = main.get_node("Hub")
	main.meta.echo = 120
	main.store.save_progress(main.meta)
	var saved_before := FileAccess.get_file_as_string(path)
	var met_before: int = main.meta.met.size()
	hub.open_help(HubSettings.TOPIC_DEMOS)
	await frames(3)
	main.open_practice()
	await frames(6)
	var room: PracticeRoom = main.practice
	check(room != null and not hub.visible and main.active_run == null and room.hero != null and room.hero.controlled, "The practice ground opens over the base, hers to play, with no run begun")
	check(not hub.settings_page.help_view.stage.playing(), "The help's window stops while she practises")
	room._crowd(2)
	await frames(90)
	check(room.foes.size() > 0, "Foes come as in a field")
	for foe in room.foes.duplicate():
		foe.receive(DamageInfo.make(100000.0, Vector2.RIGHT))
	await frames(10)
	room._on_gems(room.run.progression.required_exp() - room.run.progression.exp)
	await frames(4)
	check(room.kills > 0 and (room.run.progression.level > 1 or room.run.progression.pending_choices > 0 or room.choosing()), "They fall and a level comes, as in a run")
	while room.choosing() and room.choice.visible and room.choice.armed:
		room.choice._select(0)
		await frames(2)
	for attempt in 200:
		if not room.choosing():
			break
		await physics_frame
		if room.choice.visible and room.choice.armed:
			room.choice._select(0)
	room.hero.health.hp = 1
	await frames(4)
	check(room.hero.health.alive() and room.hero.health.hp == room.hero.health.max_hp, "She cannot fall there: low, she is mended")
	room.abandoned.emit()
	await frames(6)
	check(main.practice == null and hub.visible and not paused and is_equal_approx(Engine.time_scale, 1.0) and hub.settings_page.help_shown and hub.settings_page.help_view.topic == HubSettings.TOPIC_DEMOS, "Leaving it comes back to the help's demonstrations, the game unstopped")
	check(main.meta.echo == 120 and main.meta.runs == 0 and main.meta.met.size() == met_before and main.meta.clears == 0, "Nothing of the practice is kept: no echo, no run, no foe met")
	check(FileAccess.get_file_as_string(path) == saved_before, "And the save is as it was")
	main.free()
	await process_frame
