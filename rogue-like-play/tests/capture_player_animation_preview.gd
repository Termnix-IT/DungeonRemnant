extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	var preview := (load("res://tests/player_animation_preview.tscn") as PackedScene).instantiate()
	root.add_child(preview)
	preview.auto_cycle = false
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://.godot/player_animation_preview.png")
	for direction in preview.DIRECTIONS:
		preview._set_direction(direction)
		for walking in [false, true]:
			preview.walking = walking
			preview._refresh_animation()
			await create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			result |= root.get_texture().get_image().save_png("res://.godot/player_preview_%s_%s.png" % [direction, "walk" if walking else "idle"])
	print("Captured player animation preview.")
	quit(0 if result == OK else 1)
