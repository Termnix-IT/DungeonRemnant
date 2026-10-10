extends SceneTree

# The dungeon's menu: Esc (Start) opens it when nothing nearer needs backing
# out of, the run waits while it is open, Esc steps back one level, its
# settings are the hub's own and take effect at once, and leaving goes through
# the abort confirmation. The settings' 操作の案内 puts the HUD's actions card
# away and keeps the tag over the hero while aiming.
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)


func pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event)


func run_tests() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.run_seed = 47
	main.saving_enabled = false
	root.add_child(main)
	await process_frame
	main.start_run()
	await create_timer(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.1).timeout
	var run: Node2D = main.active_run
	var menu: DungeonMenu = run.menu
	var player: Node2D = run.turns.player
	var hud = run.hud
	check(run.settings == main.get_node("Hub").settings, "The run shares the hub's settings")

	# Esc backs out of an aim before it opens anything.
	player.aiming = true
	key(KEY_ESCAPE)
	await process_frame
	check(not player.aiming and not menu.visible, "Esc cancels an aim first")
	# And closes the inventory before it opens anything.
	key(KEY_I)
	await process_frame
	check(run.inventory_panel.visible, "I opens the inventory")
	key(KEY_ESCAPE)
	await process_frame
	check(not run.inventory_panel.visible and not menu.visible, "Esc closes the inventory first")

	key(KEY_ESCAPE)
	await process_frame
	check(menu.visible and run.turns.paused and menu.resume_button.has_focus(), "Esc on the floor opens the menu, the run waits, and 探索に戻る has focus")
	check(not player.input_enabled, "The hero takes no steps under the menu")
	key(KEY_I)
	await process_frame
	check(not run.inventory_panel.visible, "The inventory key does nothing under the menu")
	key(KEY_ESCAPE)
	await process_frame
	check(not menu.visible and not run.turns.paused, "Esc closes the menu and the run goes on")

	# Start on a gamepad opens it too.
	pad(JOY_BUTTON_START)
	await process_frame
	check(menu.visible and not run.result_panel.visible, "Start opens the menu, not the abort confirmation")
	menu.resume_button.pressed.emit()
	check(not menu.visible and not run.turns.paused, "探索に戻る resumes")

	# The settings: the hub's page, changes applied at once.
	run.open_menu()
	menu.settings_button.pressed.emit()
	await process_frame
	var page: HubSettings = menu.settings_page
	check(menu.showing_settings() and page.is_visible_in_tree(), "設定 shows the settings page")
	check(page.controls_cycler != null and page.controls_cycler.selected == 0, "The page has 操作の案内, on by default")
	check(hud.actions.visible, "The actions card shows by default")
	page.shake_cycler.item_selected.emit(2)
	check(is_zero_approx(run.shake_scale), "Turning the shake off takes effect in this run")
	page.controls_cycler.item_selected.emit(1)
	check(not run.settings.show_controls and not hud.actions.visible, "操作の案内 OFF puts the actions card away at once")
	page.help_button.pressed.emit()
	await process_frame
	check(page.help_shown and menu.settings_title.text == "ヘルプ", "The help opens from the settings")
	key(KEY_ESCAPE)
	await process_frame
	check(menu.showing_settings() and not page.help_shown, "Esc leaves the help for the settings")
	key(KEY_ESCAPE)
	await process_frame
	check(menu.visible and not menu.showing_settings() and menu.settings_button.has_focus(), "Esc leaves the settings for the menu")
	key(KEY_ESCAPE)
	await process_frame
	check(not menu.visible and not run.turns.paused, "Esc leaves the menu for the floor")

	# With the card away, aiming still shows the tag over the hero.
	player.aiming = true
	run._refresh()
	check(not hud.actions.visible and hud.aim_tag.visible, "Aiming keeps the tag over the hero with the card away")
	player.aiming = false
	run._refresh()

	# Leaving goes through the abort confirmation.
	run.open_menu()
	menu.abort_button.pressed.emit()
	await process_frame
	check(not menu.visible and run.result_panel.visible and run.result_panel.confirming, "冒険を中断する asks for confirmation first")
	run.result_panel.abort_cancelled.emit()
	await process_frame
	check(not run.result_panel.visible and not run.turns.paused, "Declining returns to the floor")
	# R stays the direct way to the confirmation.
	key(KEY_R)
	await process_frame
	check(run.result_panel.visible and run.result_panel.confirming and not menu.visible, "R goes straight to the abort confirmation")
	run.result_panel.abort_cancelled.emit()
	await process_frame

	# The setting is stored with the others.
	var stored := GameSettings.new()
	stored.path = "user://test_dungeon_menu_settings.cfg"
	stored.show_controls = false
	check(stored.save_settings(), "Settings save")
	var loaded := GameSettings.new()
	loaded.path = stored.path
	loaded.load_settings()
	check(not loaded.show_controls, "操作の案内 is stored and read back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored.path))

	main.free()
	await process_frame
	print("Dungeon menu: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
