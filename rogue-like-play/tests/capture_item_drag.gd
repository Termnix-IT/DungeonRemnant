extends "res://tests/capture_preparation.gd"

# Real mouse drags (press, move, release) on the preparation screen, the shop
# and the dungeon's inventory, with a shot while the item is held so the lit
# drop places can be seen. Writes .godot/drag_*.png.

const ARMOR := preload("res://data/items/leather_armor.tres")


func mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await process_frame


var _pointer := Vector2.ZERO


# The viewport starts a drag from the motion's relative distance, so each
# move carries it.
func move(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	var screen := root.get_final_transform() * at
	event.position = screen
	event.relative = screen - _pointer
	_pointer = screen
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await process_frame


# Picks up what is at from, carries it to to, takes a shot on the way when
# named, and lets go there.
func drag(from: Vector2, to: Vector2, shot_name: String = "") -> void:
	await move(from, false)
	await mouse(from, true)
	for step in range(1, 9):
		await move(from.lerp(to, step / 8.0), true)
	if not shot_name.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.godot/drag_%s.png" % shot_name) == OK, "Capture " + shot_name)
	await mouse(to, false)
	await settle()


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	main.state.storage.add(ARMOR)
	main.state.inventory.add(ItemCatalog.POTION, 3)
	root.add_child(main)
	root.size = Vector2i(1600, 900)
	var hub = main.get_node("Hub")
	hub.show_page("prepare")
	await create_timer(1.0).timeout
	var page: HubPrepare = hub.prepare_page
	var armor_at: int = page.storage.entries.find_custom(func(entry: Dictionary): return entry.item == ARMOR)
	await drag(page.storage.cells[armor_at].get_global_rect().get_center(), page.slots[Equipment.Slot.ARMOR].get_global_rect().get_center(), "prepare_held")
	check(main.state.equipment.slots[Equipment.Slot.ARMOR] == ARMOR, "Mouse: stored armor dropped on its slot is worn")
	await drag(page.slots[Equipment.Slot.ARMOR].get_global_rect().get_center(), page.carried.scroll.get_global_rect().get_center())
	check(main.state.equipment.slots[Equipment.Slot.ARMOR] == null and main.state.inventory.entries.any(func(entry: InventoryEntry): return entry.item == ARMOR), "Mouse: a worn icon dropped on the carried grid comes off")
	var potion_at: int = page.carried.entries.find_custom(func(entry: Dictionary): return entry.item == ItemCatalog.POTION)
	await drag(page.carried.cells[potion_at].get_global_rect().get_center(), page.storage.scroll.get_global_rect().get_center())
	check(main.state.storage.entries.any(func(entry: InventoryEntry): return entry.item == ItemCatalog.POTION), "Mouse: carried goods dropped on the warehouse move there")
	hub.show_page("sell")
	await create_timer(1.0).timeout
	var shop: HubSell = hub.sell_page
	shop.set_buying(true)
	await settle()
	var column := (shop.sell_button.get_parent() as Control).get_global_rect()
	await drag(shop.grid.cells[2].get_global_rect().get_center(), column.get_center(), "shop_held")
	check(shop.chosen_place() == 2 and shop.sell_button.has_focus() and main.state.gold == 300, "Mouse: goods dropped on the column are chosen; no Gold moves")
	main.free()
	await process_frame
	var run := preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	root.add_child(run)
	var player: Node2D = run.turns.player
	player.inventory.add(ARMOR)
	run._refresh()
	run.inventory_panel.present(player)
	await settle()
	var panel = run.inventory_panel
	var list: ItemCardList = panel.list
	var index: int = player.inventory.entries.find_custom(func(entry: InventoryEntry): return entry.item == ARMOR)
	var from: Vector2 = list.get_global_transform() * list.get_item_rect(index).get_center()
	var slot_row: Control = panel.slot_labels[Equipment.Slot.ARMOR].get_parent()
	await drag(from, slot_row.get_global_rect().get_center(), "inventory_held")
	check(player.equipment.slots[Equipment.Slot.ARMOR] == ARMOR, "Mouse: carried armor dropped on its row in the dungeon is worn")
	await drag(panel.slot_labels[Equipment.Slot.ARMOR].get_global_rect().get_center(), list.get_global_rect().get_center())
	check(player.equipment.slots[Equipment.Slot.ARMOR] == null, "Mouse: a worn row dropped on the list comes off")
	run.free()
	print("Item drag render/input: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
