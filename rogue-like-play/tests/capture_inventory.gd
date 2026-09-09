extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func snapshot(path: String) -> bool:
	for frame in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(path) == OK


func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := load("res://game/main.gd").new() as Node
	var run = (load("res://game/run/run.tscn") as PackedScene).instantiate()
	main.add_child(run)
	run.generation_seed = 47
	root.add_child(main)
	var player: Node2D = run.turns.player
	for index in 6:
		player.inventory.add(ItemCatalog.floor_item(index))
	player.inventory.add(ItemCatalog.POTION, 3)
	key(KEY_I)
	for frame in 2:
		await process_frame
	run.inventory_panel.get_node("Panel/List").select(0)
	run.inventory_panel._select_item(0)
	var ok := await snapshot("res://.godot/inventory_weapons.png")
	if not run.inventory_panel.visible or player.input_enabled or run.turns.turn_count != 0:
		push_error("Inventory keyboard open/pause failed.")
		quit(1)
		return
	run.inventory_panel.get_node("Panel/List").select(2)
	run.inventory_panel._select_item(2)
	ok = await snapshot("res://.godot/inventory_accessories.png") and ok
	# Exercise the actual GUI mouse route, not just a signal emission.
	var button: Button = run.inventory_panel.equip_buttons[Equipment.Slot.ACCESSORY_1]
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	ok = await snapshot("res://.godot/inventory_equipped.png") and ok
	if not run.inventory_panel.visible or player.equipment.slots[3] == null or run.turns.turn_count != 0:
		push_error("GUI equip click failed.")
		quit(1)
		return
	key(KEY_I)
	await process_frame
	key(KEY_TAB)
	await process_frame
	if player.weapon.kind != WeaponData.Kind.SPEAR or run.turns.turn_count != 0:
		push_error("Tab weapon switch failed.")
		quit(1)
		return
	key(KEY_I)
	await process_frame
	key(KEY_ESCAPE)
	await process_frame
	if run.inventory_panel.visible or not player.input_enabled:
		push_error("Inventory cancel failed.")
		quit(1)
		return
	print("Captured inventory, accessory selection, and equip result. I, mouse equip, Tab and Esc passed.")
	quit(0 if ok else 1)
