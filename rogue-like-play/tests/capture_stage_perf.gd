extends SceneTree

# What the fight's window costs: the frame time of each screen that shows a
# real fight outside a run (FightStage), beside the same screen without it,
# and of the run's result. With vertical sync off, each state is run for
# MEASURE seconds and its mean and worst frame are printed (and written to
# .godot/stage-perf.txt). Read the numbers against the 16.7 ms of 60 fps.
# Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/stage-perf.log --script res://tests/capture_stage_perf.gd

const MEASURE := 4.0
const SETTLE := 1.2
var lines: Array[String] = []


func _initialize() -> void:
	call_deferred("measure")


func measure() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Measuring requires a rendering display driver.")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.show_opening = false
	main.saving_enabled = false
	for foe in FoeCatalog.FOES:
		main.meta.met[foe.id] = true
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	await create_timer(1.0).timeout
	await _state("拠点のロビー（基準）")
	# The bestiary: the plate, then the watch leaf.
	hub.show_page("codex")
	var codex: HubCodex = hub.codex_page
	codex.go_to(FoeCatalog.FOES.find(load("res://data/foes/ruin_king.tres")))
	await _state("図鑑：図版")
	codex.turn_leaf(1)
	codex.choose_motion(0)
	await _state("図鑑：観察（ボスの狩り）")
	codex.choose_motion(4)
	await _state("図鑑：観察（ボスの攻撃）")
	# The settings: a row with nothing to try, then the fight in the stage.
	hub.show_page("settings")
	hub.settings_page.choose(HubSettings.DISPLAY_ROW)
	await _state("設定：実演なしの行")
	hub.settings_page.choose(0)
	await _state("設定：全体の音量（戦闘の実演）")
	hub.settings_page.choose(HubSettings.SHAKE_ROW)
	await _state("設定：画面の揺れ（被弾と一撃の実演）")
	# The help: a page of words, then the demonstrations.
	hub.open_help(HubSettings.TOPIC_RUN)
	await _state("ヘルプ：文章の話題")
	hub.settings_page.select_topic(HubSettings.TOPIC_DEMOS)
	hub.settings_page.help_view.choose_demo(5)
	await _state("ヘルプ：実演（必殺技、敵9体）")
	hub.settings_page.help_view.choose_demo(4)
	await _state("ヘルプ：実演（スキル、敵7体）")
	hub.settings_page.close_help()
	hub.show_page("home")
	# The practice ground with a horde.
	hub.open_help(HubSettings.TOPIC_DEMOS)
	await create_timer(0.5).timeout
	main.open_practice()
	await create_timer(1.0).timeout
	main.practice.hero.controlled = false
	main.practice._crowd(3)
	await create_timer(4.0).timeout
	await _state("練習場（大群：敵50体まで）")
	main.practice.abandoned.emit()
	await create_timer(0.6).timeout
	hub.settings_page.close_help()
	hub.show_page("home")
	# The run's result, each of its scenes.
	for outcome: StringName in [&"clear", &"defeat", &"return"]:
		var run := RunDirector.new()
		run.seed_value = 31
		run.meta = main.meta
		run.returns_to_base = true
		root.add_child(run)
		await process_frame
		for index in 9:
			var offer := run.run.build.offer(run.run.rng, 3)
			if not offer.is_empty():
				run.run.build.take(offer[0])
		run.run.taken.append(run.run.route.nodes(0)[0])
		run.run.echo = 420
		if outcome == &"clear":
			for layer in range(1, run.run.route.size()):
				run.run.taken.append(run.run.route.nodes(layer)[0])
			run.run.layer = run.run.route.size()
		else:
			run.run.layer = 0
		if outcome == &"defeat":
			run.fallen_to = load("res://data/foes/raging_charger.tres")
		run.finish(outcome == &"clear", outcome == &"return")
		await _state("結果：%s" % {&"clear": "踏破", &"defeat": "敗北", &"return": "中断"}[outcome])
		run.free()
	var file := FileAccess.open("res://.godot/stage-perf.txt", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("\n".join(lines))
	quit(0)


# Lets the state settle, then measures its frames for MEASURE seconds.
func _state(label: String) -> void:
	await create_timer(SETTLE, true, false, true).timeout
	var began := Time.get_ticks_usec()
	var last := began
	var worst := 0
	var frames := 0
	var over := 0
	while Time.get_ticks_usec() - began < int(MEASURE * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		over += 1 if now - last > 16700 else 0
		last = now
		frames += 1
	var mean := (last - began) / 1000.0 / maxi(frames, 1)
	lines.append("%-38s 平均 %5.2f ms（%4d fps）　最悪 %5.1f ms　16.7msを超えたコマ %d / %d" % [label, mean, roundi(1000.0 / maxf(mean, 0.001)), worst / 1000.0, over, frames])
