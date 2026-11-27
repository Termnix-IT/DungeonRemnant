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


# From the lobby to where to set out, and out to the chapter it offers.
func set_out(main: Node) -> RunDirector:
	var hub = main.get_node("Hub")
	hub.home_page.activated.emit(&"departure")
	hub.sortie_page.set_out()
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
		await create_timer(BossIntro.total_time() + 0.5, true, false, true).timeout
		area.boss_foe.receive(DamageInfo.make(100000.0, Vector2.UP))
	elif area.data.kind == AreaData.Kind.FIELD and area.data.survive_time > 0.0:
		area.elapsed = area.data.survive_time
	else:
		area.clear()
	# The area is left once its clearing has been told and any level's cards
	# are answered (a boss's hall later: its fall is told first).
	for attempt in 60:
		if run.area == null:
			break
		await wait(0.2)
		while is_instance_valid(area) and area.choosing() and area.choice.visible:
			area.choice._select(0)
			await process_frame
	await wait(0.2)
	if run.choice.visible:
		run.choice._select(0)
	await process_frame


func run_tests() -> void:
	var folder := "res://.godot/cycle-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.show_opening = false
	main.store.path = folder + "/progress.json"
	main.run_seed = 21
	root.add_child(main)
	await process_frame
	var hub = main.get_node("Hub")

	# A won run.
	var run := await set_out(main)
	for layer in run.run.route.size():
		run.map_view._choose(run.map_view.current[0])
		await process_frame
		await clear_area(run)
	check(not run.result.is_empty() and run.result.cleared, "Every layer cleared, the boss beaten: the run is won")
	check(run.end_view.visible and run.end_view._button.text == "拠点へ戻る", "The result offers the way home")
	var summary := run.end_view
	check(summary.outcome == &"clear" and not summary.settled and not summary._button.has_focus(), "The won run's scene plays first: the way on takes no press yet")
	var sheet: Rect2 = summary._panel.get_global_rect()
	var way_on: Rect2 = summary._button.get_global_rect()
	check(sheet.encloses(way_on) and way_on.get_center().x > sheet.get_center().x + sheet.size.x * 0.2 and way_on.get_center().y > sheet.get_center().y + sheet.size.y * 0.3, "The way on stands at the lower right of the scene")
	check(summary.hero != null and summary.hero.is_visible_in_tree() and not summary._foe.visible, "She stands before the door of a run won")
	check(not summary.retry_button.visible and summary._button.focus_neighbor_left == summary._button.get_path(), "A run won offers only the way home: its ending and what it opens are told there")
	check(summary.found.size() == run.result.discovered.size() and summary.found.size() > 0 and summary.found.any(func(foe: FoeData) -> bool: return foe.id == &"ruin_king"), "The foes this run recorded for the first time are shown")
	check(summary.figures.size() == 4 and summary._boons.visible and summary._boons.get_child_count() == run.result.build.size() and run.result.build.size() == run.run.build.owned().size() and run.result.build.size() > 0, "The run's figures and every boon taken are in view at once, without tabs")
	var first_boon: BoonData = run.result.build[0][0]
	check(summary._boon_name.text == first_boon.display_name and summary._boon_cells[0].lit and summary._button.focus_neighbor_top == summary._boon_cells[0].get_path(), "The first boon is told under the grid, and up from the way on reaches it")
	summary._boon_cells[-1].grab_focus()
	var last_boon: BoonData = run.result.build[-1][0]
	check(summary._boon_name.text == last_boon.display_name and summary._boon_cells[-1].lit and summary._boon_cells[-1].focus_neighbor_bottom == summary._button.get_path(), "Focusing a boon tells it, and down from the last row goes back to the way on")
	summary._button.grab_focus()
	var journey := summary.journey
	check(journey.spots.size() == run.run.route.size() + 1 and journey.ended_at == run.run.route.size() and journey.figure is DirectionalRig and journey.figure.position.distance_to(journey.spots[-1]) < 20.0, "The way the run went ends with her on the boss's stage")
	check(journey.caption.text == "%sを倒した" % run.run.route.nodes(run.run.route.size() - 1)[0].area.boss.display_name, "And says whom she beat")
	check(summary.total_label.visible, "The purse's total stands beside the echo")
	check(run.result.record and run.result.first_clear, "The first win goes deeper than before and is the first clear")
	await create_timer(RunEndView.STAMP_DELAY + RunEndView.STAMP_TIME + RunEndView.COUNT_DELAY + summary.count_time() + 0.4).timeout
	check(summary.counted and summary.total_label.text == "所持 残響 %s" % UIFormat.amount(run.result.echo_before + run.result.echo), "The echo has counted up, and so has the purse")
	check(summary.seal.visible and summary.seal.texture == RunEndView.SEALS[&"clear"] and summary.seal.scale.is_equal_approx(Vector2.ONE), "The win's seal is stamped beside the heading")
	check(summary.record_label.visible and summary.record_label.modulate.a > 0.95 and summary.record_label.text == "初めての踏破", "And the first clear is told in gold")
	check(summary._art.texture == RunEndView.PAINTINGS[&"clear"] and summary._echo.text == UIFormat.amount(run.result.echo), "The scene is the dawn at the last hall's door, the echo counted up to what was brought home")
	check(summary.settled and summary._button.has_focus() and is_equal_approx(summary._button.modulate.a, 1.0), "Once the scene is all in, the way on is focused")
	var echo: int = run.result.echo
	check(main.meta.runs == 1 and main.meta.clears == 1 and main.meta.echo == echo and echo > 0, "The win is recorded with its echo")
	check(main.meta.best_layer == run.run.route.size() and main.meta.has_met(&"ruin_king"), "The deepest layer and the foes met are recorded")
	var reader := MetaStore.new()
	reader.path = main.store.path
	check(reader.load_progress().echo == echo, "The result is saved before the way home is taken")
	run.end_view._button.pressed.emit()
	await process_frame
	check(main.active_run == null and hub.visible and hub.page == "home" and not paused, "The way home returns to the lobby")
	check(hub.echo_label.text == UIFormat.amount(echo) and hub.sortie_page.state_of(0).begins_with("踏破"), "The base shows the echo brought home and the clear")
	check(hub.chapter.id == &"gale_woods" and hub.home_page.title_label.text == hub.chapter.display_name, "The chapter the clear opened is the one offered next")

	# A lost run keeps its echo.
	run = await set_out(main)
	run.map_view._choose(run.run.route.nodes(0)[0])
	await process_frame
	run.area.hero.controlled = false
	run.run.echo = 25
	run.area.hero.health.hp = 1
	# Felled by a foe's shot: the result names the foe that shot it.
	var shooter: FoeData = load("res://data/foes/gale_warden.tres")
	var shot := Projectile.new()
	shot.shooter = shooter
	run.area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT, 0.0, shot))
	shot.free()
	await wait(RunDirector.FALL_PAUSE + 0.3)
	check(not run.result.cleared and not run.result.abandoned and main.meta.echo == echo + 25 and main.meta.runs == 2, "A lost run is recorded, its echo kept")
	var fallen := run.end_view
	check(fallen.outcome == &"defeat" and fallen._art.texture == RunEndView.PAINTINGS[&"defeat"] and fallen.hero == null and fallen.felled_by == shooter and fallen._foe.visible and fallen._foe.texture == EnemySprites.codex_portrait(shooter.visual_id), "A lost run's scene is another: her sword in the dark, and who felled her standing over it")
	check(fallen.found.is_empty() or not fallen.found.any(func(foe: FoeData) -> bool: return foe.id == &"ruin_king"), "A foe already recorded is not told as new again")
	# A press while the scene plays brings it all in; it does not leave.
	check(not fallen.settled and fallen.count_time() < 0.6, "It plays quietly, the echo counted quickly")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	await process_frame
	check(fallen.settled and fallen.counted and main.active_run == run and fallen.visible and fallen._button.has_focus(), "A press during the scene shows all of it at once and stays on the result")
	check(fallen.retry_button.visible and is_equal_approx(fallen.retry_button.modulate.a, 1.0), "A run lost offers the same chapter again")
	root.push_input(enter)
	await process_frame
	check(main.active_run == run, "A second press straight after does not leave either")
	check(fallen._echo.text == UIFormat.amount(25) and fallen.seal.visible and fallen.seal.texture == RunEndView.SEALS[&"defeat"], "All of it is in: the echo kept, the seal of a fall")
	check(run.result.fallen_to == shooter and run.end_view.journey.ended_at == 1 and not (run.end_view.journey.figure is DirectionalRig) and run.end_view.journey.caption.text == "%sに倒された" % shooter.display_name, "The way ends on the stage she fell on, the foe that felled her standing there")
	await create_timer(RunEndView.LEAVE_GUARD + 0.1).timeout
	root.push_input(enter)
	await process_frame
	await process_frame
	check(main.active_run == null and hub.visible, "A moment later the press takes the way on: a lost run comes home too")

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
	check(area.prompt.cancel_button.has_focus() and area.prompt.accept_button.theme_type_variation == &"BandDangerButton", "Leaving cannot be undone: the way ahead is red, the focus waits on the way back")
	area.prompt.confirmed.emit()
	await process_frame
	await process_frame
	check(run.result.abandoned and main.meta.echo == echo + 35 and main.meta.runs == 3, "A run left is recorded as left, its echo kept")
	check(run.area == null and run.end_view.visible and not paused, "Leaving ends the run on its result")
	check(run.result.fallen_to == null and run.end_view.journey.figure is DirectionalRig and run.end_view.journey.caption.text.ends_with("で引き返した"), "A run left ends with her where she turned back")
	check(run.end_view.outcome == &"return" and run.end_view._art.texture == RunEndView.PAINTINGS[&"return"] and run.end_view.hero == null and not run.end_view._foe.visible and run.end_view.felled_by == null, "Its scene is the corridor back, with no one in it")
	# The same chapter again, straight from the result of a run lost or left.
	var left_view := run.end_view
	left_view.settle()
	check(left_view.retry_button.visible and left_view._button.has_focus() and left_view._button.focus_neighbor_left == left_view.retry_button.get_path() and left_view.retry_button.focus_neighbor_right == left_view._button.get_path(), "A run left offers the same chapter again beside the way home, which keeps the focus")
	var chapter_before: ChapterData = run.chapter
	var step_before: int = run.step
	var runs_before: int = main.meta.runs
	var echo_before: int = main.meta.echo
	left_view.retry_button.pressed.emit()
	await process_frame
	await process_frame
	var again: RunDirector = main.active_run
	check(again != null and again != run and not is_instance_valid(run) or run.is_queued_for_deletion(), "Taking it ends the old run")
	check(again != null and again.chapter == chapter_before and again.step == step_before and again.result.is_empty() and again.returns_to_base and not hub.visible and not paused, "And sets out for the same chapter at the same step, without the base")
	check(main.meta.runs == runs_before and main.meta.echo == echo_before, "The run that ended was recorded once, before; setting out again adds nothing")
	if again.choice.visible:
		again.choice._select(0)
		await process_frame
	again.map_view._choose(again.run.route.nodes(0)[0])
	await process_frame
	check(again.area != null, "The new run is played as any other")
	again.area.hero.controlled = false
	again.area.open_menu()
	again.area.menu.abort_requested.emit()
	again.area.prompt.confirmed.emit()
	await process_frame
	await process_frame
	check(again.result.abandoned and main.meta.runs == runs_before + 1, "And is recorded when it ends")
	again.end_view._button.pressed.emit()
	await process_frame
	check(main.active_run == null and hub.visible, "A run left comes home too")
	main.free()
	await process_frame
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + name)
	DirAccess.remove_absolute(folder)

	# A player's first setting out plays the prologue first: three stills
	# without a roll, then the run; never again once a run is on record.
	var first: Node = load("res://game/main.tscn").instantiate()
	first.saving_enabled = false
	first.show_opening = false
	first.run_seed = 21
	root.add_child(first)
	await process_frame
	var first_hub = first.get_node("Hub")
	check(first.show_prologue and first.prologue_due(), "With no run on record, the prologue is due")
	first.start_run()
	var prologue: EndingView = first.prologue_view
	check(first.active_run == null and prologue != null and prologue.visible and prologue.scenes == EndingView.PROLOGUE and not prologue.rolls and prologue.scene == 0 and first_hub.visible, "Setting out the first time plays the prologue before the run")
	check(prologue.line.text == EndingView.PROLOGUE[0][1] and EndingView.PROLOGUE.size() == 3, "Its first still tells its line")
	first.start_run()
	check(first.active_run == null and prologue.scene == 0, "Nothing sets out while it plays")
	for still in EndingView.PROLOGUE.size():
		prologue._ready_at = 0.0
		prologue.advance()
	await process_frame
	check(not prologue.visible and not prologue.rolling and first.active_run != null and not first_hub.visible, "After its last still the run sets out, with no staff roll")
	check(first.active_run.run.guided, "And that first run teaches the controls")
	check(not first.prologue_due(), "It is not played twice in a sitting")
	first.meta.runs = 1
	first._prologue_played = false
	check(not first.prologue_due(), "Nor once a run is on record")
	first.free()
	await process_frame
	print("Run cycle tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
