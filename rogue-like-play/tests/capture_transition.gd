extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_capture")


func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://.godot/transition_%s.png" % label) != OK:
		failures += 1
		push_error("Capture " + label)


func run_capture() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	for frame in 3:
		await process_frame
	var hub = main.get_node("Hub")
	hub.show_page("sell")
	await create_timer(0.06).timeout
	await snapshot("page_entering")
	hub.show_page("stages")
	await create_timer(0.3).timeout
	main.start_run()
	await create_timer(0.1).timeout
	await snapshot("departure_cover")
	await create_timer(0.45).timeout
	await snapshot("departure_reveal")
	await create_timer(0.6).timeout
	main.active_run.finish_run(true)
	main.active_run.retry_run()
	await create_timer(0.1).timeout
	await snapshot("return_cover")
	print("Transition capture: ", "passed" if failures == 0 else "FAILED")
	quit(1 if failures else 0)
