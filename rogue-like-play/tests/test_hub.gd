extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func ignores_pointer(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not ignores_pointer(child):
			return false
	return true


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run_tests() -> void:
	var state := RunCarryover.new()
	check(not state.purchase_upgrade() and state.gold == 0 and state.hp_upgrade_level == 0, "Insufficient funds do not mutate state")
	state.gold = 29
	check(not state.purchase_upgrade() and state.gold == 29, "Price boundary below cost")
	state.gold = 180
	for expected in range(1, 4):
		check(state.purchase_upgrade() and state.hp_upgrade_level == expected, "Purchase advances one level")
	check(state.gold == 0 and state.upgrade.hp_bonus(3) == 3, "All three prices total 180 for HP +3")
	state.gold = 999
	for attempt in 10:
		check(not state.purchase_upgrade() and state.gold == 999 and state.hp_upgrade_level == 3, "Repeated purchase cannot exceed cap or spend Gold")
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub: CanvasLayer = main.get_node("Hub")
	var lobby: HubLobby = hub.home_page
	var hero: LobbyHero = lobby.get_node("Hero")
	var viewport := root.get_visible_rect().size
	# The texture keeps a clear margin above her for swaying hair.
	var figure := hero.size.y * (1.0 - 40.0 / hero.texture.get_height())
	check(figure >= viewport.y * 0.74 and figure <= viewport.y * 0.82, "Lobby heroine stands about 78% of the screen tall")
	check(hero.get_global_rect().end.x <= viewport.x + 1, "Heroine and her swaying hair stay on screen")
	# Idle: breathing, lean, blinks every 3-7 s, glances of 1-2°, hair trailing.
	var blinks := 0
	var was_closed := false
	var widest_angle := 0.0
	var widest_hair := 0.0
	for step in 1200:
		hero.advance(0.025)
		if hero.blink_amount > 0.5 and not was_closed:
			blinks += 1
		was_closed = hero.blink_amount > 0.5
		widest_angle = maxf(widest_angle, absf(rad_to_deg(hero.head_angle)))
		widest_hair = maxf(widest_hair, hero.hair_shift.length())
	check(blinks >= 4 and blinks <= 11, "She blinks every 3-7 s over 30 s: %d" % blinks)
	check(widest_angle > 0.5 and widest_angle <= 2.01, "Glances turn her head by up to 2°: %.2f" % widest_angle)
	check(widest_hair > 1.0 and widest_hair <= LobbyHero.HAIR_REACH + 0.01, "Hair sways within its reach: %.2f" % widest_hair)
	var material := hero.material as ShaderMaterial
	check(material.get_shader_parameter(&"breath") is float and material.get_shader_parameter(&"blink_texture") != null and material.get_shader_parameter(&"motion_mask") != null, "Idle drives the shader with the blink and motion textures")
	# The hair follows the body late: right after a sudden head turn it has
	# barely moved, and it has caught up a few tenths of a second later.
	var rest_hair := hero.hair_shift
	hero.react()
	hero.advance(0.016)
	check(hero.scale.y > 1.0, "A click lifts her in a small hop")
	var early := (hero.hair_shift - rest_hair).length()
	hero.advance(0.2)
	check((hero.hair_shift - rest_hair).length() > early * 3.0, "Hair trails the hop a moment late")
	hero.advance(LobbyHero.REACT_TIME)
	check(is_equal_approx(hero.scale.y, 1.0) and is_equal_approx(hero.scale.x, 1.0), "The hop settles back to rest")
	check(hero.get_rect().get_center().x > viewport.x * 0.66, "Heroine stands on the right side of the lobby")
	check(lobby.buttons.map(func(button: Button): return button.text) == ["出撃", "装備", "倉庫", "ショップ", "強化", "設定"], "Lobby menu lists the six entries in order")
	check(lobby.selected_id() == &"departure" and hub.start_button.has_focus(), "Lobby starts on departure with focus")
	for button in lobby.buttons:
		check(button.get_global_rect().end.x <= viewport.x * 0.22, "Menu entry stays within about a fifth of the width: " + button.text)
	check(not hub.title_label.is_visible_in_tree() and hub.gold_label.is_visible_in_tree() and hub.find_children("SettingsButton", "", true, false).is_empty(), "Lobby top shows only Gold; settings live in the menu")
	for label in hub.find_children("*", "Label", true, false):
		check(not (label.is_visible_in_tree() and label.text.contains("Lv")), "Lobby shows no level: " + label.text)
	var ambience: HubAmbience = hub.get_children().filter(func(child: Node): return child is HubAmbience)[0]
	check(ambience.get_index() < hub.get_node("Content").get_index() and ambience.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Ambience sits beneath the panels and ignores the pointer")
	ambience.size = Vector2(1600, 900)
	check(ambience.light_rect(Vector2(0.5, 0.5), 10.0).get_center().is_equal_approx(Vector2(800, 450)), "Lights follow the covered background")
	hub.hide()
	check(not ambience.dust.emitting, "Hidden hub stops the dust")
	hub.show()
	# Choosing and entering are separate: one press chooses, the next enters.
	await create_timer(HubAmbience.FOCUS_TIME + 0.1).timeout
	check(ambience.focus_id == &"departure" and ambience.focus_strength > 0.9, "Departure lights the gate")
	hub.equipment_button.pressed.emit()
	check(hub.page == "home" and lobby.selected_id() == &"equipment" and hub.decide_button.text == "装備を整える", "First press chooses equipment without leaving")
	await create_timer(HubAmbience.FOCUS_TIME + 0.1).timeout
	check(ambience.focus_id == &"equipment", "Choosing equipment lights the weapon rack")
	check(lobby.equipment_label.is_visible_in_tree() and not lobby.carried_label.is_visible_in_tree(), "Panel shows only the chosen entry's information")
	hub.equipment_button.pressed.emit()
	check(hub.page == "equipment", "Pressing the chosen entry enters it")
	await create_timer(HubAmbience.FOCUS_TIME + 0.1).timeout
	check(ambience.focus_id == &"", "Pages away from the lobby clear the hall light")
	hub.show_page("home")
	check(lobby.selected_id() == &"equipment" and hub.equipment_button.has_focus(), "Returning home keeps the chosen entry")
	hub.decide_button.pressed.emit()
	check(hub.page == "equipment", "Panel button enters the chosen entry")
	hub.show_page("home")
	# Keyboard and gamepad focus chooses directly.
	hub.warehouse_button.grab_focus()
	check(lobby.selected_id() == &"storage" and lobby.stored_label.is_visible_in_tree(), "Focus chooses an entry")
	# Settings open as their own page, entered like the others.
	var settings_entry: Button = lobby.buttons[-1]
	settings_entry.pressed.emit()
	check(lobby.selected_id() == &"settings" and hub.decide_button.visible and hub.decide_button.text == "設定を開く" and lobby.volume_value.text == "100%" and lobby.display_value.text == "ウィンドウ", "Settings entry shows current values and an open button")
	settings_entry.pressed.emit()
	var page: HubSettings = hub.settings_page
	check(hub.page == "settings" and page.visible and not lobby.visible and page.volume_slider.has_focus(), "Settings slide in as a page with the volume bar focused")
	var master := AudioServer.get_bus_index(&"Master")
	page.volume_slider.value = 50
	check(is_equal_approx(hub.settings.volume, 0.5) and is_equal_approx(AudioServer.get_bus_volume_linear(master), 0.5) and page.volume_value.text == "50%", "Volume bar sets the master volume")
	var step_right := InputEventAction.new()
	step_right.action = &"ui_right"
	step_right.pressed = true
	root.push_input(step_right)
	check(page.volume_slider.value == 55 and hub.settings.volume_percent() == 55, "Right on the focused bar raises the volume one step")
	page.volume_slider.value = 0
	check(AudioServer.is_bus_mute(master), "Silent mutes the master bus")
	page.volume_slider.value = 100
	check(not AudioServer.is_bus_mute(master) and is_equal_approx(AudioServer.get_bus_volume_linear(master), 1.0), "Loudest restores full volume")
	page.display_cycler.grab_focus()
	root.push_input(step_right)
	check(hub.settings.fullscreen and page.display_cycler.text == "全画面" and page.display_cycler.has_focus(), "Right on the selector steps to fullscreen and keeps focus")
	page.display_cycler.pressed.emit()
	check(not hub.settings.fullscreen and page.display_cycler.text == "ウィンドウ", "Confirming the selector wraps back to window")
	page.volume_slider.value = 80
	hub.go_back()
	check(hub.page == "home" and lobby.selected_id() == &"settings" and lobby.volume_value.text == "80%", "Back returns to the lobby with the new values")
	page.volume_slider.value = 100
	hub.start_button.grab_focus()
	check(not hub.hero_speech.visible, "Home speech starts hidden")
	hub.hero_button.pressed.emit()
	check(hub.hero_speech.visible, "Clicking hero opens speech")
	var speech_rect: Rect2 = hub.hero_speech.get_global_rect()
	check(root.get_visible_rect().encloses(speech_rect) and not speech_rect.intersects(lobby.panel.get_global_rect()) and speech_rect.end.x <= hero.get_global_rect().position.x + hero.size.x * HubLobby.FACE.x, "Speech sits beside her face, on screen and clear of the panel")
	var first_line: String = lobby.speech_label.text
	hub.hero_button.pressed.emit()
	check(hub.hero_speech.visible and lobby.speech_label.text != first_line, "Clicking again moves to her next line")
	await create_timer(HubLobby.SPEECH_TIME + 0.2).timeout
	check(not hub.hero_speech.visible, "Speech fades by itself after a while")
	hub.hero_button.pressed.emit()
	hub.show_page("stages")
	hub.show_page("home")
	check(not hub.hero_speech.visible, "Returning home resets speech")
	hub.hero_button.pressed.emit()
	hub.open_warehouse()
	check(not hub.hero_speech.visible, "Warehouse closes speech")
	hub.warehouse_panel.close()
	check(hub.visible and main.active_run == null and hub.purchase_button.disabled, "Game starts in Hub with no active dungeon")
	check(hub.get_child(hub.get_child_count() - 1) == hub.warehouse_panel, "Warehouse modal is last in GUI input order")
	check(hub.gold_label.text.contains("0") and hub.equipment_label.text.contains("剣"), "Hub displays initial Gold and equipment")
	main.state.gold = 101
	main.state.inventory.add(ItemCatalog.POTION, 10)
	main.state.inventory.add(preload("res://data/items/leather_armor.tres"))
	main.state.equipment.slots[3] = preload("res://data/items/vital_charm.tres")
	hub.warehouse_panel.present(main.state)
	check(hub.warehouse_panel.visible and hub.warehouse_panel.get_node("%InventoryList").item_count == 2, "Warehouse opens with carried inventory")
	hub.warehouse_panel.get_node("%InventoryList").item_selected.emit(1)
	hub.warehouse_panel.get_node("%Deposit").pressed.emit()
	check(main.state.storage.entries.size() == 1 and main.state.inventory.entries.size() == 1, "Hub UI deposits one equipment item")
	hub.warehouse_panel.get_node("%StorageList").item_selected.emit(0)
	hub.warehouse_panel.get_node("%Withdraw").pressed.emit()
	check(main.state.storage.entries.is_empty() and main.state.inventory.entries.size() == 2, "Hub UI withdraws deposited item")
	main.state.inventory.remove(1)
	main.state.storage.add(ItemCatalog.POTION, 12)
	hub.warehouse_panel.close()
	check(main.purchase_upgrade() and main.state.gold == 71 and main.state.hp_upgrade_level == 1, "Hub purchase updates shared state")
	main.start_run()
	var run: Node2D = main.active_run
	var player: Node2D = run.turns.player
	check(not hub.visible and run.turns.gold == 71 and run.progression.level == 1, "Start initializes new run with remaining Gold")
	check(player.stats.max_hp == 29 and player.hp == 29, "Base HP plus permanent upgrade plus equipment")
	main.start_run()
	var runs := main.get_children().filter(func(child: Node): return child.has_method("finish_run"))
	check(main.active_run == run and runs.size() == 1, "Repeated start cannot create duplicate run")
	check(main.transition.visible and not main.transition.title.text.is_empty() and run.turns.player.input_enabled, "Departure covers the cut while the run is already live")
	var cell_before: Vector2i = player.cell
	var step := InputEventAction.new()
	step.pressed = true
	for candidate: Array in [["move_e", Vector2i.RIGHT], ["move_w", Vector2i.LEFT], ["move_s", Vector2i.DOWN], ["move_n", Vector2i.UP]]:
		if run.dungeon.grid.can_step(cell_before, cell_before + candidate[1]):
			step.action = candidate[0]
			break
	check(not step.action.is_empty(), "Start cell has a walkable neighbour for the input check")
	root.push_input(step)
	check(player.cell == cell_before and run.turns.turn_count == 0, "Input is swallowed while the cover is up")
	check(main.transition.root.mouse_filter == Control.MOUSE_FILTER_STOP, "Cover blocks pointer input while covering")
	await create_timer(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.1).timeout
	check(not main.transition.visible and not main.transition.covering and main.transition.root.modulate.a == 1.0, "Transition reveals itself and resets")
	check(ignores_pointer(main.transition.root), "Revealed transition releases pointer input")
	# Control case: the same input moves the player once the cover is gone.
	root.push_input(step)
	var release := InputEventAction.new()
	release.action = step.action
	root.push_input(release)
	check(player.cell != cell_before, "The swallowed input would have moved the player")
	if run.presentation.playing:
		await run.presentation.finished
	await process_frame
	check(not main.purchase_upgrade() and main.state.gold == 71, "Purchases blocked during adventure")
	main.return_to_hub()
	check(main.active_run == run, "Cannot return without finishing run")
	player.gain_ability(preload("res://data/abilities/max_hp.tres"))
	check(player.stats.max_hp == 32, "Ability stacks with permanent and equipped HP")
	player.apply_permanent_hp(1)
	check(player.stats.max_hp == 32, "Permanent bonus application is idempotent")
	run.floor_number = 2
	run._load_floor()
	check(player.stats.max_hp == 32, "Floor transition does not multiply HP bonus")
	run.finish_run(false)
	check(run.result_panel.accept.text.contains("拠点") and run.turns.gold == 36, "Result offers Hub return after one loss")
	run.retry_run()
	check(main.active_run == null and hub.visible and main.state.gold == 36, "Result returns to Hub with surviving Gold")
	check(main.transition.visible and main.transition.title.text == "旅支度の間" and not main.transition.art.visible, "Return to Hub is covered by its own heading")
	check(main.state.hp_upgrade_level == 1 and main.state.inventory.entries.is_empty() and main.state.equipment.slots[3] != null, "Death preserves upgrade and gear, halves inventory")
	check(main.state.storage.entries[0].count == 12, "Death leaves warehouse untouched")
	main.return_to_hub()
	check(main.state.gold == 36, "Duplicate Hub return cannot apply loss")
	for cycle in 3:
		main.start_run()
		run = main.active_run
		player = run.turns.player
		check(player.stats.max_hp == 29 and player.hp == 29 and player.abilities.levels.is_empty(), "Next adventure resets ability, retains permanent HP exactly once")
		check(run.progression.level == 1 and run.progression.exp == 0 and run.turns.earned_gold == 0, "New adventure counters reset")
		run.finish_run(true)
		run.retry_run()
		check(main.state.gold == 36 and main.state.inventory.entries.is_empty(), "Clear round trip preserves possessions")
	main.state.gold = 150
	check(main.purchase_upgrade() and main.state.gold == 90 and main.state.hp_upgrade_level == 2, "Next price is 60")
	check(main.purchase_upgrade() and main.state.gold == 0 and main.state.hp_upgrade_level == 3, "Final price is 90")
	check(hub.purchase_button.disabled and hub.purchase_button.text.contains("上限"), "UI displays cap")
	main.start_run()
	check(main.active_run.turns.player.stats.max_hp == 31, "Maximum upgrade applies +3 alongside gear")
	check(preload("res://data/player_stats.tres").max_hp == 24, "Shared base Resource remains unchanged")
	main.free()
	# Settings live apart from progress and fall back to defaults when unreadable.
	var stored := GameSettings.new()
	stored.path = "res://.godot/settings-test.cfg"
	stored.volume = 0.35
	stored.fullscreen = true
	check(stored.save_settings(), "Settings save to their own file")
	var loaded := GameSettings.new()
	loaded.path = stored.path
	loaded.load_settings()
	check(is_equal_approx(loaded.volume, 0.35) and loaded.fullscreen, "Settings survive a restart")
	var broken := FileAccess.open(stored.path, FileAccess.WRITE)
	broken.store_string("[audio\nvolume = ")
	broken.close()
	var fallback := GameSettings.new()
	fallback.path = stored.path
	fallback.load_settings()
	check(is_equal_approx(fallback.volume, 1.0) and not fallback.fullscreen, "Unreadable settings fall back to full volume in a window")
	# The first settings files stored five volume steps.
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "volume_step", 2)
	legacy.save(stored.path)
	var upgraded := GameSettings.new()
	upgraded.path = stored.path
	upgraded.load_settings()
	check(is_equal_approx(upgraded.volume, 0.5), "Old volume steps load as their level")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored.path))
	print("Hub tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
