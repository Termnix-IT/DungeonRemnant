extends SceneTree

# The base drawn for real at 1600x900, 1280x720 and 1920x1080: the lobby on
# its departure, where to set out, the lasting upgrades, the status, the
# encyclopedia and the settings; then, at 1600x900, a sealed chapter chosen
# where to set out, the help and the quit's question, a run's result
# offering the way home, the fight's menu and its leaving question. Images go to .godot/hub_<page>_<width>.png. Look at them: the
# hierarchy, the selected state, the main actions and any cut text. Needs a
# rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/hub-capture.log --script res://tests/capture_hub.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]
var shots := {}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	var main: Node = load("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.run_seed = 6
	main.meta.echo = 240
	main.meta.ranks["echo_lantern"] = 1
	main.meta.ranks["sturdy_body"] = 1
	main.meta.ranks["double_dash"] = 1
	main.meta.runs = 3
	main.meta.best_layer = 2
	main.meta.chapter_best[&"ash_corridor"] = 2
	main.meta.met[&"wandering_sentinel"] = true
	main.meta.met[&"dashing_rat"] = true
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	for size in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		await create_timer(0.3).timeout
		for page in ["home", "sortie", "upgrade", "status", "codex", "settings"]:
			hub.show_page(page)
			await create_timer(UIMotion.WINDOW_TIME + 0.3).timeout
			await _grab("hub_%s_%d" % [page, size.x])
	DisplayServer.window_set_size(SIZES[0])
	root.size = SIZES[0]
	# Where to set out, on the sealed chapter.
	hub.show_page("sortie")
	await create_timer(UIMotion.WINDOW_TIME + 0.3).timeout
	hub.sortie_page.cards[1].grab_focus()
	await create_timer(UIMotion.DETAIL_SLIDE_TIME + 0.3).timeout
	await _grab("hub_sortie_sealed_1600")
	# After the ending: the step row, set at step 3 of the three open.
	main.meta.chapter_clears[Chapters.ALL.back().id] = 1
	main.meta.chapter_steps[Chapters.ALL.back().id] = 2
	hub.refresh(main.meta)
	hub.show_page("sortie")
	await create_timer(UIMotion.WINDOW_TIME + 0.3).timeout
	hub.sortie_page.choose_step(3)
	await create_timer(UIMotion.DETAIL_SLIDE_TIME + 0.3).timeout
	await _grab("hub_sortie_steps_1600")
	hub.sortie_page.choose_step(0)
	main.meta.chapter_clears.erase(Chapters.ALL.back().id)
	main.meta.chapter_steps.clear()
	hub.refresh(main.meta)
	# The upgrade tree followed out to a branch's end, the root's side out of sight.
	hub.show_page("upgrade")
	await create_timer(UIMotion.WINDOW_TIME + 0.3).timeout
	(hub.upgrade_page.nodes[&"last_stand"] as Button).grab_focus()
	await create_timer(MetaUpgradePage.FOLLOW_TIME + 0.3).timeout
	await _grab("hub_upgrade_far_1600")
	# A new account sliding into the encyclopedia's column, mid-way.
	hub.show_page("codex")
	await create_timer(UIMotion.WINDOW_TIME + 0.3).timeout
	hub.codex_page._select(1)
	await create_timer(UIMotion.DETAIL_SLIDE_TIME * 0.35).timeout
	await _grab("hub_codex_slide_1600")
	await create_timer(0.3).timeout
		# The popups a click opens: the help, and the quit's question.
	hub.show_page("settings")
	await create_timer(UIMotion.WINDOW_TIME + 0.3).timeout
	hub.settings_page.open_help(HubSettings.TOPIC_RUN)
	await create_timer(UIMotion.WINDOW_TIME + 0.3).timeout
	await _grab("hub_help_1600")
	hub.settings_page.close_help()
	hub.settings_page.ask_quit()
	await create_timer(0.5).timeout
	await _grab("hub_quit_prompt_1600")
	hub.settings_page.quit_prompt.hide()
	hub.show_page("home")
	await create_timer(0.3).timeout
	main.start_run()
	await create_timer(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.2).timeout
	var run: RunDirector = main.active_run
	run.map_view._choose(run.run.route.nodes(0)[0])
	await create_timer(1.0).timeout
	run.area.hero.controlled = false
	run.area.open_menu()
	await create_timer(0.4).timeout
	await _grab("hub_run_menu_1600")
	run.area.menu.abort_requested.emit()
	await create_timer(0.5).timeout
	await _grab("hub_run_abandon_1600")
	run.area.prompt.canceled.emit()
	await create_timer(0.2).timeout
	run.area.menu.resume()
	run.run.echo = 60
	run.area.hero.health.hp = 1
	run.area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await create_timer(RunDirector.FALL_PAUSE + 0.6).timeout
	await _grab("hub_run_result_1600")
	run.end_view._button.pressed.emit()
	await create_timer(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.4).timeout
	await _grab("hub_after_run_1600")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the base: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
