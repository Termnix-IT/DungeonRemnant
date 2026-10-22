extends SceneTree

# The whole cycle from the base: set out, take every layer to the boss and
# win, the result recorded and saved, back to the base with the echo; then
# a run lost in its first area and one left from the menu, each keeping its
# echo and bringing the player home.

const FRAME := 1.0 / 60.0
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func wait(seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		await physics_frame


func set_out(main: Node) -> RunDirector:
	main.get_node("Hub").home_page.activated.emit(&"departure")
	await process_frame
	var run: RunDirector = main.active_run
	if run.choice.visible:
		run.choice._select(0)
		await process_frame
	return run


# Meets the area's goal and takes its reward (the first card when it is boons).
func clear_area(run: RunDirector) -> void:
	var area := run.area
	area.hero.controlled = false
	if area.data.boss != null:
		# The boss comes in, then falls.
		await wait(BattleArea.BOSS_DELAY + BattleArea.BOSS_MARK_TIME + 0.3)
		area.boss_foe.receive(DamageInfo.make(100000.0, Vector2.UP))
	elif area.data.kind == AreaData.Kind.FIELD and area.data.survive_time > 0.0:
		area.elapsed = area.data.survive_time
	else:
		area.clear()
	for attempt in 4:
		await wait(BattleArea.CLEAR_PAUSE * 0.5)
		while area != null and is_instance_valid(area) and area.choosing():
			area.choice._select(0)
			await process_frame
	await wait(BattleArea.CLEAR_PAUSE)
	if run.choice.visible:
		run.choice._select(0)
	await process_frame


func run_tests() -> void:
	var folder := "res://.godot/cycle-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var main: Node = load("res://game/main.tscn").instantiate()
	main.store.path = folder + "/progress.json"
	main.run_seed = 21
	root.add_child(main)
	await process_frame
	var hub = main.get_node("Hub")

	# A won run.
	var run := await set_out(main)
	for layer in run.run.route.size():
		run.map_view._choose(run.run.route.nodes(layer)[0])
		await process_frame
		await clear_area(run)
	check(not run.result.is_empty() and run.result.cleared, "Every layer cleared, the boss beaten: the run is won")
	check(run.end_view.visible and run.end_view._button.text == "拠点へ戻る", "The result offers the way home")
	var summary := run.end_view
	check(summary._button.has_focus() and summary.pages[0].visible and not summary.pages[1].visible, "The summary opens on the run's figures, the way on focused")
	check(summary._button.get_index() == summary._button.get_parent().get_child_count() - 1, "The way on is at the foot of the window")
	summary.tabs.step(1)
	check(summary.pages[1].visible and not summary.pages[0].visible, "The tab switches to the boons taken")
	check(summary._tiles.get_child_count() == 4 and summary._boons.get_child_count() == run.result.emblems.size() and run.result.emblems.size() == run.run.build.owned().size(), "The summary shows the run's figures as tiles and every boon as its emblem and name")
	summary.tabs.step(1)
	check(summary.pages[0].visible, "And back")
	check(summary.total_label.visible, "The purse's total stands beside the echo")
	check(run.result.record and run.result.first_clear, "The first win goes deeper than before and is the first clear")
	await create_timer(RunEndView.STAMP_DELAY + RunEndView.STAMP_TIME + RunEndView.COUNT_DELAY + summary.count_time() + 0.4).timeout
	check(summary.counted and summary.total_label.text == "所持 残響 %s" % UIFormat.amount(run.result.echo_before + run.result.echo), "The echo has counted up, and so has the purse")
	check(summary.seal.visible and summary.seal.texture == RunEndView.SEALS[&"clear"] and summary.seal.scale.is_equal_approx(Vector2.ONE), "The win's seal is stamped beside the heading")
	check(summary.record_label.visible and summary.record_label.modulate.a > 0.95 and summary.record_label.text == "初めての踏破", "And the first clear is told in gold")
	check(summary._art.texture == run.CHAPTER.illustration and summary._echo.text == UIFormat.amount(run.result.echo), "The summary lies over the chapter's illustration, the echo counted up to what was brought home")
	var echo: int = run.result.echo
	check(main.meta.runs == 1 and main.meta.clears == 1 and main.meta.echo == echo and echo > 0, "The win is recorded with its echo")
	check(main.meta.best_layer == run.run.route.size() and main.meta.has_met(&"ruin_king"), "The deepest layer and the foes met are recorded")
	var reader := MetaStore.new()
	reader.path = main.store.path
	check(reader.load_progress().echo == echo, "The result is saved before the way home is taken")
	run.end_view._button.pressed.emit()
	await process_frame
	check(main.active_run == null and hub.visible and hub.page == "home" and not paused, "The way home returns to the lobby")
	check(hub.echo_label.text == UIFormat.amount(echo) and hub.home_page.best_value.text.begins_with("踏破"), "The base shows the echo brought home and the clear")

	# A lost run keeps its echo.
	run = await set_out(main)
	run.map_view._choose(run.run.route.nodes(0)[0])
	await process_frame
	run.area.hero.controlled = false
	run.run.echo = 25
	run.area.hero.health.hp = 1
	run.area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await wait(RunDirector.FALL_PAUSE + 0.3)
	check(not run.result.cleared and not run.result.abandoned and main.meta.echo == echo + 25 and main.meta.runs == 2, "A lost run is recorded, its echo kept")
	run.end_view._button.pressed.emit()
	await process_frame
	check(main.active_run == null and hub.visible, "A lost run comes home too")

	# A run left from the menu.
	run = await set_out(main)
	run.map_view._choose(run.run.route.nodes(0)[0])
	await process_frame
	var area := run.area
	area.hero.controlled = false
	run.run.echo = 10
	area.open_menu()
	check(paused and area.menu.visible, "The menu stops the fight")
	area.menu.abort_requested.emit()
	check(area.prompt.visible and not area.menu.visible, "Leaving asks first")
	check(area.prompt.cancel_button.has_focus() and area.prompt.accept_button.theme_type_variation == &"DangerButton", "Leaving cannot be undone: the way ahead is red, the focus waits on the way back")
	area.prompt.confirmed.emit()
	await process_frame
	await process_frame
	check(run.result.abandoned and main.meta.echo == echo + 35 and main.meta.runs == 3, "A run left is recorded as left, its echo kept")
	check(run.area == null and run.end_view.visible and not paused, "Leaving ends the run on its result")
	run.end_view._button.pressed.emit()
	await process_frame
	check(main.active_run == null and hub.visible, "A run left comes home too")
	main.free()
	await process_frame
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + name)
	DirAccess.remove_absolute(folder)
	print("Run cycle tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
