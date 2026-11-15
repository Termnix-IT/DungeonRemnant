extends SceneTree

# The three prototypes drawn for real: each at 1920x1080 in six states (as
# it opens, a chapter cleared, a sealed one, a difficulty step chosen, the
# highest step open, the moment of setting out), and as it opens at
# 1280x720. Images go to .godot/sortie_<name>_<state>_<width>.png.
# Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --script res://prototypes/sortie_redesign/capture_proto.gd

const STATES: Array[StringName] = [&"initial", &"other", &"sealed", &"steps", &"limit", &"depart"]


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	var main: Control = load("res://prototypes/sortie_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	main._switch.hide()
	var only := OS.get_cmdline_user_args()
	for index in main.screens.size():
		var name: String = ProtoMain.names()[index]
		if not only.is_empty() and not only.has(name):
			continue
		main.show_screen(index)
		for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(size)
			root.size = size
			await create_timer(0.3).timeout
			for state in STATES:
				if size.x != 1920 and state != &"initial":
					continue
				main.screens[index].pose(state)
				await create_timer(0.7).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/sortie_%s_%s_%d.png" % [name, state, size.x])
	print("captured")
	quit()
