extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func snap(name: String) -> void:
	for frame in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/campaign_%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	main.state.gold = 3000
	main.state.record_boss(&"ancient_ruins", 10, false)
	main.state.record_boss(&"ancient_ruins", 50, true)
	main.state.record_boss(&"forest", 10, false)
	main.state.unlock_entry(preload("res://data/stages/forest.tres"), 11)
	var hub := main.get_node("Hub")
	hub.refresh(main.state)
	hub.show_page("upgrade")
	await snap("tree")
	hub.show_page("stages")
	hub.departure_page._select_stage(1)
	await snap("forest_selection")
	hub.show_page("confirm")
	hub.departure_page.start_choice.select(1)
	hub.departure_page.start_choice.item_selected.emit(1)
	await snap("confirm")
	main.start_run()
	await snap("forest")
	main.active_run.finish_run(false, true)
	main.active_run.retry_run()
	root.size = Vector2i(1152, 720)
	hub.show_page("upgrade")
	await snap("tree_small")
	print("Campaign capture complete")
	quit()
