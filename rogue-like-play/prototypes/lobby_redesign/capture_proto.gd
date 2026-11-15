extends SceneTree

# The three prototypes drawn for real, and the shipped lobby beside them on
# the same progress: each at 1920x1080 in six states (as it opens on the
# departure, the upgrades, the status, the encyclopedia, the settings, and
# her line just spoken), and as it opens at 1280x720. Images go to
# .godot/lobby_<name>_<state>_<width>.png, the shipped lobby's as
# lobby_current_<state>_<width>.png.
# Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --script res://prototypes/lobby_redesign/capture_proto.gd

const STATES: Array[StringName] = [&"initial", &"upgrade", &"status", &"codex", &"settings", &"talk"]
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720)]


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	var only := OS.get_cmdline_user_args()
	var main: Control = load("res://prototypes/lobby_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	main._switch.hide()
	for index in main.screens.size():
		var name: String = ProtoMain.names()[index]
		if not only.is_empty() and not only.has(name):
			continue
		main.show_screen(index)
		for size in SIZES:
			DisplayServer.window_set_size(size)
			root.size = size
			await create_timer(0.3).timeout
			for state in STATES:
				if size.x != 1920 and state != &"initial":
					continue
				main.screens[index].pose(state)
				await create_timer(0.7).timeout
				await _save("lobby_%s_%s_%d" % [name, state, size.x])
	main.queue_free()
	await process_frame
	if only.is_empty() or only.has("current"):
		await _current()
	print("captured")
	quit()


# The shipped lobby, on the progress the prototypes show.
func _current() -> void:
	var game: Node = load("res://game/main.tscn").instantiate()
	game.show_prologue = false
	game.saving_enabled = false
	game.meta = ProtoLobby.sample()
	root.add_child(game)
	var hub = game.get_node("Hub")
	hub.refresh(game.meta)
	var lobby: HubLobby = hub.home_page
	for size in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		await create_timer(0.4).timeout
		for state in STATES:
			if size.x != 1920 and state != &"initial":
				continue
			lobby.select(maxi(0, [&"initial", &"upgrade", &"status", &"codex", &"settings"].find(state)))
			lobby.focus_selected()
			if state == &"talk":
				lobby.talk()
			await create_timer(0.7).timeout
			await _save("lobby_current_%s_%d" % [state, size.x])


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/%s.png" % file_name)
