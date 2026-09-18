extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func settle() -> void:
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	main.state.equipment.slots[0] = ItemData.from_weapon(preload("res://data/weapons/staff.tres"))
	main.state.inventory.add(preload("res://data/items/bolt_scroll.tres"))
	main.state.inventory.add(preload("res://data/items/flame_scroll.tres"))
	var hub := main.get_node("Hub")
	hub.refresh(main.state)
	hub.show_page("equipment")
	await settle()
	var ok := root.get_texture().get_image().save_png("res://.godot/magic_hub.png") == OK
	hub.equipment_page.equip_button.pressed.emit()
	ok = main.state.equipment.slots[0].socketed_scroll != null and ok
	main.start_run()
	var run: Node2D = main.active_run
	run.inventory_panel.present(run.turns.player)
	run.inventory_panel._select_item(0)
	run._refresh()
	await settle()
	ok = root.get_texture().get_image().save_png("res://.godot/magic_inventory.png") == OK and ok
	run.inventory_panel.equip_buttons[0].pressed.emit()
	ok = run.turns.player.equipment.slots[0].socketed_scroll.id == &"flame_scroll" and ok
	run._close_inventory()
	run.turns.player.aiming = true
	run._refresh()
	await settle()
	ok = root.get_texture().get_image().save_png("res://.godot/magic_aim.png") == OK and ok
	run.turns.submit("attack", Vector2i.RIGHT)
	if run.presentation.playing:
		await run.presentation.finished
	ok = run.turns.player.mp == 15 and ok
	print("Magic visual and UI interaction capture: ", ok)
	quit(0 if ok else 1)
