extends SceneTree

# The settings' list and stage drawn for real, state by state: as the page
# opens (at 1600x900, 1280x720 and 1920x1080), then at 1600x900 a volume
# turned down, everything silenced, the shake in the moment it is struck,
# the screen, the language, the controls guide on and off, the help's row,
# the end of the game, the page in English, and the page over a run from
# the dungeon's menu. Images go to .godot/settings_<state>_<width>.png.
# Look at them: whether the row under the cursor stands out, whether the
# stage shows what the setting does, whether the words read on the hall and
# over the field, and any cut text. Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/settings-capture.log --script res://tests/capture_settings.gd

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
	main.show_prologue = false
	main.show_opening = false
	main.saving_enabled = false
	main.meta.echo = 240
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	var page: HubSettings = hub.settings_page
	for size in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		await create_timer(0.3).timeout
		hub.show_page("settings")
		await create_timer(UIMotion.WINDOW_TIME + 0.7).timeout
		await _grab("settings_open_%d" % size.x)
	DisplayServer.window_set_size(SIZES[0])
	root.size = SIZES[0]
	hub.show_page("settings")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	page.choose(1)
	page.put(1, 55)
	await create_timer(0.5).timeout
	await _grab("settings_volume_1600")
	page.put(1, 80)
	page.choose(0)
	page.put(0, 0)
	await create_timer(0.5).timeout
	await _grab("settings_muted_1600")
	page.put(0, 100)
	# The shake, caught just after the frame is struck.
	page.choose(HubSettings.SHAKE_ROW)
	page._clock = 1.3 * 20.0 - 0.02
	await create_timer(0.1).timeout
	await _grab("settings_shake_1600")
	page.choose(HubSettings.DISPLAY_ROW)
	await create_timer(0.5).timeout
	await _grab("settings_screen_1600")
	page.choose(HubSettings.LANGUAGE_ROW)
	await create_timer(0.5).timeout
	await _grab("settings_language_1600")
	page.choose(HubSettings.CONTROLS_ROW)
	await create_timer(0.5).timeout
	await _grab("settings_guide_1600")
	page.put(HubSettings.CONTROLS_ROW, 1)
	await create_timer(0.5).timeout
	await _grab("settings_guide_off_1600")
	page.put(HubSettings.CONTROLS_ROW, 0)
	page.choose(HubSettings.HELP_ROW)
	await create_timer(0.5).timeout
	await _grab("settings_help_1600")
	page.choose(HubSettings.QUIT_ROW)
	await create_timer(0.5).timeout
	await _grab("settings_quit_1600")
	TranslationServer.set_locale("en")
	hub.show_page("home")
	hub.refresh(main.meta)
	hub.show_page("settings")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	hub.settings_page.choose(HubSettings.CONTROLS_ROW)
	await create_timer(0.5).timeout
	await _grab("settings_english_1600")
	TranslationServer.set_locale("ja")
	# Over a run, from the dungeon's menu: no veil of its own, no language.
	main.run_seed = 4
	hub.show_page("sortie")
	hub.sortie_page.set_out()
	await create_timer(1.6).timeout
	var run = main.active_run
	var menu: DungeonMenu = run.map_menu
	menu.open()
	menu.open_settings()
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	menu.settings_page.choose(HubSettings.QUIT_ROW)
	await create_timer(0.5).timeout
	await _grab("settings_run_1600")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the settings: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
