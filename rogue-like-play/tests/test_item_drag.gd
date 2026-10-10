extends SceneTree

# The shared drag grammar (ItemDrag, docs/MVP_SPEC.md 個別画面のUI文法):
# drops that can be undone act at once, drops where Gold would move only
# choose and wait on the trade, and the places that would take what is held
# light up while it is held.

const ARMOR := preload("res://data/items/leather_armor.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run_tests() -> void:
	check(ItemDrag.item_of({"item": ARMOR}) == ARMOR and ItemDrag.item_of("nothing") == null, "A drag's data names its item")
	await test_preparation()
	await test_shop()
	await test_inventory()
	print("Item drag tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_preparation() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.storage.add(ARMOR)
	main.state.inventory.add(ItemCatalog.POTION, 2)
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.show_page("prepare")
	await process_frame
	var page: HubPrepare = hub.prepare_page
	var armor_at: int = page.storage.entries.find_custom(func(entry: Dictionary): return entry.item == ARMOR)
	var armor_cell: ItemCell = page.storage.cells[armor_at]
	# Holding the armor lights the slot it fits and the other grid, not the others.
	armor_cell.force_drag(armor_cell, null)
	await process_frame
	check(page.slots[Equipment.Slot.ARMOR].drop_ready and not page.slots[Equipment.Slot.MAIN].drop_ready, "Holding gear lights the slot it fits and no other")
	check(page.carried.cells.all(func(cell: ItemCell): return cell.drop_ready), "Holding a stored item lights the carried grid")
	root.gui_cancel_drag()
	await process_frame
	check(not page.slots[Equipment.Slot.ARMOR].drop_ready, "Letting go puts the lights out")
	# Dropped on the column, it is chosen and waits on the action.
	page._dropped_on_column(armor_cell)
	check(page.storage.cells[armor_at].button_pressed and page.primary_button.has_focus() and main.state.equipment.slots[Equipment.Slot.ARMOR] == null, "Dropped on the column, gear is chosen and waits on the action")
	# Dropped on its slot, it is worn at once: wearing can be undone.
	page.slots[Equipment.Slot.ARMOR]._drop_data(Vector2.ZERO, page.storage.cells[armor_at])
	check(main.state.equipment.slots[Equipment.Slot.ARMOR] == ARMOR, "Dropped on its slot, gear is worn")
	page.storage._drop_here(Vector2.ZERO, page.slots[Equipment.Slot.ARMOR])
	check(main.state.equipment.slots[Equipment.Slot.ARMOR] == null, "A worn icon dropped on a grid comes off")
	main.free()
	await process_frame


func test_shop() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.show_page("sell")
	await process_frame
	var shop: HubSell = hub.sell_page
	shop.set_buying(true)
	var cell: ItemCell = shop.grid.cells[1]
	check(shop._counter_takes(cell) and not shop._counter_takes("other"), "The shop's column takes goods from its list")
	shop._dropped_on_counter(cell)
	check(shop.chosen_place() == 1 and shop.sell_button.has_focus() and main.state.gold == 300, "Dropped goods are chosen and wait on the trade; no Gold moves")
	main.free()
	await process_frame


func test_inventory() -> void:
	var run := preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	root.add_child(run)
	var player: Node2D = run.turns.player
	player.inventory.add(ARMOR)
	var panel = run.inventory_panel
	panel.present(player)
	var index: int = player.inventory.entries.find_custom(func(entry: InventoryEntry): return entry.item == ARMOR)
	var row: Variant = panel._pick_row(index)
	check(row.item == ARMOR and panel._slot_takes(row, Equipment.Slot.ARMOR) and not panel._slot_takes(row, Equipment.Slot.MAIN), "A carried item fits only its own slot")
	var turns_before: int = run.turns.turn_count
	panel._dropped_on_slot(row, Equipment.Slot.ARMOR)
	check(player.equipment.slots[Equipment.Slot.ARMOR] == ARMOR and run.turns.turn_count == turns_before, "Dropped on its slot, it is worn without a turn")
	var worn: ItemCell = panel.slot_cells[Equipment.Slot.ARMOR]
	check(worn.item == ARMOR and worn.draggable, "A worn slot shows its item and can be picked up")
	check(panel._list_takes(worn) and not panel._list_takes(panel.slot_cells[Equipment.Slot.MAIN]) and not panel._list_takes(row), "The list takes worn gear back, except the main weapon")
	panel._dropped_on_list(worn)
	check(player.equipment.slots[Equipment.Slot.ARMOR] == null, "Dropped on the list, worn gear comes off")
	check(not panel._list_takes(worn), "An emptied slot has nothing to give back")
	var main_weapon: ItemData = player.equipment.slots[Equipment.Slot.MAIN]
	var sub: ItemCell = panel.slot_cells[Equipment.Slot.SUB]
	check(panel._slot_takes(sub, Equipment.Slot.MAIN) and panel.slot_cells[Equipment.Slot.MAIN].can_accept.call(sub) and not panel._slot_takes(sub, Equipment.Slot.ARMOR), "The weapons take each other, and only each other")
	panel._dropped_on_slot(sub, Equipment.Slot.MAIN)
	check(player.equipment.slots[Equipment.Slot.SUB] == main_weapon, "Weapons dropped on each other swap")
	run.free()
	await process_frame
