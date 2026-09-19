extends "res://tests/capture_preparation.gd"


func frame_shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/motion_%s.png" % name) == OK, "Capture " + name)


func wait_motion(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame
	await RenderingServer.frame_post_draw


func pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func sample_cost(button: Button, animate: bool) -> void:
	var frame_times: Array[float] = []
	var started := Time.get_ticks_usec()
	var last_frame := started
	for frame in 120:
		if animate and frame % 12 == 0:
			button.mouse_entered.emit()
			UIMotion.of(button).pulse(1.04)
		elif animate and frame % 12 == 6:
			button.mouse_exited.emit()
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now - last_frame) / 1000.0)
		last_frame = now
	var fps := 120000000.0 / (Time.get_ticks_usec() - started)
	frame_times.sort()
	print("UI performance %s: p95 frame %.3f ms, observed %.1f FPS (60 FPS cap)" % ["animated" if animate else "idle", frame_times[113], fps])


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 60
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	main.state.storage.add(ItemCatalog.POTION, 5)
	main.state.storage.add(preload("res://data/items/leather_armor.tres"))
	root.add_child(main)
	var hub = main.get_node("Hub")
	await settle()
	await click(hub.sell_button)
	var shop: HubSell = hub.sell_page
	await click(shop.buy_tab)
	await click(shop.item_list, Vector2(35, 25))
	pointer(shop.sell_button.get_global_rect().get_center())
	await settle()
	check(shop.sell_button.scale.x > 1.01, "Real pointer produces hover motion")
	await frame_shot("hover")
	var target := shop.sell_button.get_global_rect().get_center()
	mouse_button(target, true)
	await wait_motion(0.11)
	check(shop.sell_button.scale.x < 0.99, "Real mouse down produces press motion")
	await frame_shot("press")
	mouse_button(target, false)
	check(main.state.gold == 280, "Mouse purchase is immediate")
	await wait_motion(0.06)
	await frame_shot("purchase")
	await settle()
	await click(shop.sell_tab)
	await click(shop.item_list, Vector2(35, 25))
	pointer(Vector2(5, 5))
	shop.sell_button.grab_focus()
	await settle()
	check(shop.sell_button.scale.x > 1.01, "Focus works without pointer hover")
	await frame_shot("focus")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	Input.parse_input_event(joy)
	Input.flush_buffered_events()
	await wait_motion(0.11)
	check(shop.sell_button.scale.x < 0.99, "Gamepad confirm has pressed feedback")
	joy = joy.duplicate()
	joy.pressed = false
	Input.parse_input_event(joy)
	Input.flush_buffered_events()
	check(main.state.gold == 285, "Gamepad confirm sells exactly once")
	await wait_motion(0.06)
	await frame_shot("sale")
	await settle()
	await key(KEY_ESCAPE)
	joy.button_index = JOY_BUTTON_DPAD_DOWN
	joy.pressed = true
	Input.parse_input_event(joy)
	Input.flush_buffered_events()
	joy = joy.duplicate()
	joy.pressed = false
	Input.parse_input_event(joy)
	Input.flush_buffered_events()
	check(hub.equipment_button.has_focus(), "Gamepad D-pad navigates from departure to equipment")
	await click(hub.equipment_button)
	await click(hub.equipment_page.slots[2])
	hub.equipment_page.equip_button.grab_focus()
	await key(KEY_ENTER)
	check(main.state.equipment.slots[2] != null, "Keyboard equip still works")
	# Replay only the visual response to capture its peak after the input check.
	UIMotion.of(hub.equipment_page.slots[2]).pulse()
	await wait_motion(0.05)
	await frame_shot("equip")
	await settle()
	await create_timer(1.0).timeout
	await sample_cost(hub.equipment_page.done_button, false)
	await sample_cost(hub.equipment_page.done_button, true)
	await create_timer(0.4).timeout
	check(get_processed_tweens().size() == 1, "Stress capture leaves only hero breathing")
	root.size = Vector2i(1152, 720)
	await key(KEY_ESCAPE)
	await click(hub.sell_button)
	await click(shop.buy_tab)
	await click(shop.item_list, Vector2(28, 20))
	shop.sell_button.grab_focus()
	await settle()
	check(shop.get_global_rect().encloses(shop.sell_button.get_global_rect()), "Animated focused button fits at 720p")
	await frame_shot("shop_720")
	var edge := shop.sell_button.get_global_transform() * Vector2(1, shop.sell_button.size.y * 0.5)
	var gold_before: int = main.state.gold
	pointer(edge)
	mouse_button(edge, true)
	await wait_motion(0.12)
	mouse_button(edge, false)
	check(main.state.gold == gold_before - 20, "Press near button edge still activates after compression")
	main.free()
	print("UI motion render/input: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
