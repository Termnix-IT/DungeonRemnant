extends "res://tests/capture_preparation.gd"


func down() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_DOWN
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func selection_shot(name: String, targets: Array[Control]) -> void:
	await create_timer(0.04).timeout
	await RenderingServer.frame_post_draw
	for target in targets:
		check(target.modulate.a > 0.65 and target.modulate.a < 1.0, "Selected content fades: " + name)
		check(is_equal_approx(target.modulate.a, targets[0].modulate.a), "Selected content stays synchronized: " + name)
	check(root.get_texture().get_image().save_png("res://.godot/selection_%s.png" % name) == OK, "Capture " + name)


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 60
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	main.state.inventory.add(ItemCatalog.POTION, 2)
	main.state.storage.add(preload("res://data/items/leather_armor.tres"))
	main.state.storage.add(ItemCatalog.POTION, 4)
	root.add_child(main)
	var hub = main.get_node("Hub")
	var before := SaveCodec.encode(main.state)
	for resolution in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		hub.show_page("sell")
		var shop: HubSell = hub.sell_page
		shop.set_buying(true)
		shop.grid.cells[0].grab_focus()
		await settle()
		check(shop.chosen_place() == 0, "Keyboard focus chooses the icon")
		await selection_shot("shop_%d" % resolution.y, [shop.showcase, shop.possession])
		hub.show_page("equipment")
		await settle()
		var equipment: HubEquipment = hub.equipment_page
		var position := equipment.slots[Equipment.Slot.ARMOR].get_global_rect().get_center()
		var event := InputEventMouseButton.new()
		event.position = root.get_final_transform() * position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		Input.parse_input_event(event)
		var release := event.duplicate() as InputEventMouseButton
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
		check(equipment.selected_slot == Equipment.Slot.ARMOR, "Native mouse slot selection")
		await shot("equipment_%d" % resolution.y)
		hub.open_warehouse()
		var warehouse: HubWarehouse = hub.warehouse_page
		warehouse.storage.cells[0].grab_focus()
		await settle()
		check(warehouse.detail_name.text == warehouse.storage.entries[0].item.label(), "Keyboard focus names the warehouse icon")
		await selection_shot("warehouse_%d" % resolution.y, [warehouse.detail_name, warehouse.detail_note])
		hub.go_back()
	check(SaveCodec.encode(main.state) == before, "Selection captures do not change inventory or Gold")
	main.free()
	print("UI selection render/input: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
