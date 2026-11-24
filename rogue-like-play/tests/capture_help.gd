extends SceneTree

# The help's demonstrations and the practice ground drawn for real: each of
# the fight's moves in the demonstrations' window at a telling moment (at
# 1600x900), the window at 1280x720 and 1920x1080 and in English, the
# demonstrations opened over a stopped fight from a run's menu (where the
# practice ground is not offered), and the practice ground itself: as it
# opens, with a swarm called in, a level's cards, the question on leaving,
# and the help it comes back to. Images go to .godot/help_<state>_<width>.png.
# Look at them: whether the move shown is plain to see, the keys beside it,
# the list of moves and which is chosen, cut text, and that the practice
# ground reads as the fight. Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/help-capture.log --script res://tests/capture_help.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]
# When each move's scene shows what it is about (seconds into the scene).
const MOMENTS := {&"move": 1.0, &"strike": 1.5, &"charge": 2.0, &"dash": 1.55, &"skill": 0.95, &"special": 1.5, &"shards": 3.45}
var shots := {}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	_size(SIZES[0])
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.show_opening = false
	main.saving_enabled = false
	main.meta.echo = 240
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	hub.open_help(HubSettings.TOPIC_DEMOS)
	await _wait(UIMotion.WINDOW_TIME + 0.5)
	var help: HelpView = hub.settings_page.help_view
	for index in StageScenes.CONTROLS.size():
		var id: StringName = StageScenes.CONTROLS[index][0]
		help.choose_demo(index)
		await _stage_at(help.stage, MOMENTS[id])
		await _grab("help_demo_%s_1600" % id)
	for size in [SIZES[1], SIZES[2]]:
		_size(size)
		await _wait(0.4)
		help.choose_demo(1)
		await _stage_at(help.stage, MOMENTS[&"strike"])
		await _grab("help_demo_strike_%d" % size.x)
	_size(SIZES[0])
	await _wait(0.3)
	TranslationServer.set_locale("en")
	hub.settings_page.close_help()
	hub.show_page("home")
	hub.refresh(main.meta)
	hub.open_help(HubSettings.TOPIC_DEMOS)
	await _wait(UIMotion.WINDOW_TIME + 0.5)
	help = hub.settings_page.help_view
	help.choose_demo(3)
	await _stage_at(help.stage, MOMENTS[&"dash"])
	await _grab("help_demo_english_1600")
	TranslationServer.set_locale("ja")
	hub.settings_page.close_help()
	hub.show_page("home")
	hub.refresh(main.meta)
	# The practice ground, from the demonstrations.
	hub.open_help(HubSettings.TOPIC_DEMOS)
	await _wait(UIMotion.WINDOW_TIME + 0.4)
	main.open_practice()
	await _wait(1.4)
	var room: PracticeRoom = main.practice
	await _grab("help_practice_open_1600")
	room.hero.controlled = false
	room._crowd(2)
	await _wait(2.6)
	await _fight(room, 2.4)
	await _grab("help_practice_swarm_1600")
	_size(SIZES[2])
	await _fight(room, 0.8)
	await _grab("help_practice_swarm_1920")
	_size(SIZES[0])
	await _fight(room, 0.3)
	room._on_gems(room.run.progression.required_exp() - room.run.progression.exp)
	for frame in 400:
		await process_frame
		if room.choice.visible and room.choice.armed:
			break
	await _wait(0.4)
	await _grab("help_practice_level_1600")
	room.choice._select(0)
	await _wait(0.8)
	room.open_menu()
	await _wait(0.5)
	await _grab("help_practice_menu_1600")
	room.menu.abort_requested.emit()
	await _wait(0.5)
	await _grab("help_practice_leave_1600")
	room.prompt.confirmed.emit()
	await _wait(1.0)
	await _grab("help_practice_back_1600")
	hub.settings_page.close_help()
	hub.show_page("home")
	# Over a stopped fight, from a run's menu: no practice ground from here.
	main.run_seed = 4
	hub.show_page("sortie")
	hub.sortie_page.set_out()
	await _wait(1.6)
	var run = main.active_run
	if run.choice.visible:
		run.choice._select(0)
		await _wait(0.4)
	run.map_view._choose(run.map_view.current[0])
	await _wait(2.4)
	run.area.open_menu()
	await _wait(0.4)
	run.area.menu.open_settings()
	await _wait(UIMotion.WINDOW_TIME + 0.3)
	run.area.menu.settings_page.open_help(HubSettings.TOPIC_DEMOS)
	await _wait(UIMotion.WINDOW_TIME + 0.4)
	var in_run: HelpView = run.area.menu.settings_page.help_view
	in_run.choose_demo(5)
	await _stage_at(in_run.stage, MOMENTS[&"special"])
	await _grab("help_demo_in_run_1600")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the help: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


# Waits until the stage's scene has played `time` seconds.
func _stage_at(stage: FightStage, time: float) -> void:
	for frame in 1200:
		await process_frame
		if stage.area != null and stage.area._clock >= time and stage.area._clock < time + 0.5:
			return


# She fights the nearest foe for a while, as a player would.
func _fight(room: PracticeRoom, seconds: float) -> void:
	var until := Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		var aim := Vector2.RIGHT
		var near := INF
		for foe in room.foes:
			var gap: Vector2 = foe.global_position - room.hero.global_position
			if gap.length() < near:
				near = gap.length()
				aim = gap.normalized()
		room.hero.step(HeroInput.make(aim if near > 60.0 else Vector2.ZERO, aim, true), 1.0 / 60.0)
		await physics_frame


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
