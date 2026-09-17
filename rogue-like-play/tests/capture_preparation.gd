extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("capture")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func settle() -> void:
	await create_timer(0.2).timeout
	await process_frame
	await RenderingServer.frame_post_draw


func shot(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png("res://.godot/preparation_%s.png" % name) == OK, "Capture " + name)


func click(control: Control, offset: Vector2 = Vector2(-1, -1)) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center() if offset.x < 0 else control.get_global_rect().position + offset
	event.position = root.get_final_transform() * event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await settle()


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await settle()


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 120
	main.state.inventory.add(ItemCatalog.POTION, 6)
	for index in 6:
		main.state.storage.add(ItemCatalog.floor_item(index))
	root.add_child(main)
	var hub = main.get_node("Hub")
	await shot("home")
	# Navigate from the initial focus without programmatically choosing a target.
	await key(KEY_ENTER)
	check(hub.page == "stages", "Initial keyboard focus activates departure")
	await key(KEY_TAB)
	await key(KEY_ENTER)
	check(hub.page == "confirm", "Native Tab navigation reaches stage action")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await click(hub.equipment_button)
	await click(hub.equipment_page.slots[2])
	await shot("equipment")
	await click(hub.equipment_page.equip_button)
	check(main.state.equipment.slots[2] != null, "Mouse equips warehouse armor")
	await click(hub.equipment_page.slots[0])
	await shot("weapon_comparison")
	hub.open_warehouse()
	await shot("warehouse")
	await key(KEY_ESCAPE)
	check(hub.page == "equipment" and not hub.warehouse_panel.visible, "Esc closes only warehouse")
	await key(KEY_ESCAPE)
	check(hub.page == "home", "Esc returns home")
	await click(hub.sell_button)
	await click(hub.sell_page.item_list, Vector2(35, 25))
	await shot("sale")
	var gold_before: int = main.state.gold
	await click(hub.sell_page.sell_button)
	check(main.state.gold > gold_before, "Mouse sale credits Gold")
	await key(KEY_ESCAPE)
	await click(hub.start_button)
	check(main.active_run == null and hub.page == "stages", "Mouse departure stops at selection")
	await shot("stages")
	await click(hub.departure_page.next_button)
	check(main.active_run == null and hub.page == "confirm", "Mouse selection stops at confirmation")
	await shot("confirmation")
	await key(KEY_ESCAPE)
	check(hub.page == "stages", "Esc cancels confirmation")
	await click(hub.departure_page.next_button)
	# Exercise native keyboard focus activation at the final transition.
	hub.departure_page.confirm_button.grab_focus()
	await key(KEY_ENTER)
	check(main.active_run != null and not hub.visible, "Keyboard confirms departure")
	await shot("dungeon")
	main.active_run.finish_run(true)
	await settle()
	await click(main.active_run.result_panel.accept)
	check(hub.visible and hub.page == "home", "Mouse result returns home")
	# Check scaled hub layout and native input at a smaller window.
	root.size = Vector2i(1152, 720)
	await shot("home_720")
	await click(hub.equipment_button)
	await shot("equipment_720")
	check(hub.page == "equipment", "Scaled home hit targets work")
	main.free()
	print("Preparation render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
