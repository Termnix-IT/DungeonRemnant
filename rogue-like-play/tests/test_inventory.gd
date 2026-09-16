extends SceneTree

const RUN := preload("res://game/run/run.tscn")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const POTION := preload("res://data/items/healing_potion.tres")
const LEATHER := preload("res://data/items/leather_armor.tres")
const CHAIN := preload("res://data/items/chain_armor.tres")
const VITAL := preload("res://data/items/vital_charm.tres")
const VISION := preload("res://data/items/vision_charm.tres")
const POWER := preload("res://data/items/power_charm.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func press_inventory(run: Node2D) -> void:
	var event := InputEventAction.new()
	event.action = "inventory"
	event.pressed = true
	run._input(event)


func test_capacity_and_transactions() -> void:
	var inventory := Inventory.new()
	check(inventory.add(POTION, 49) == 0, "Add stack")
	check(inventory.add(POTION, 3) == 2 and inventory.entries[0].count == 50 and inventory.entries.size() == 1, "Stack cap 50 without spill to new slot")
	check(inventory.add(LEATHER, 39) == 0 and inventory.entries.size() == 40, "Equipment copies each use a slot")
	check(inventory.add(CHAIN) == 1 and inventory.entries.size() == 40, "Forty-entry capacity")
	check(inventory.remove(0) and inventory.add(POTION) == 0 and inventory.entries.size() == 40, "Existing stack fills even at full inventory")
	check(not inventory.remove(-1) and not inventory.remove(40), "Invalid removal cannot mutate inventory")
	var equipment := Equipment.new()
	check(equipment.slots.size() == 5 and equipment.slots[0].weapon.kind == WeaponData.Kind.SWORD and equipment.slots[1].weapon.kind == WeaponData.Kind.SPEAR, "Default equipment five slots, sword and spear")
	var previous_main: ItemData = equipment.slots[0]
	check(not equipment.equip(inventory, 1, Equipment.Slot.MAIN) and equipment.slots[0] == previous_main and inventory.entries.size() == 40, "Wrong-slot equip fails atomically")
	check(not equipment.unequip(inventory, Equipment.Slot.SUB) and equipment.slots[1] != null and inventory.entries.size() == 40, "Full inventory cannot unequip or lose sub weapon")
	check(equipment.equip(inventory, 1, Equipment.Slot.ARMOR) and inventory.entries.size() == 39, "Equipping removes item from inventory")
	inventory.add(CHAIN)
	check(equipment.equip(inventory, 39, Equipment.Slot.ARMOR) and inventory.entries.size() == 40 and equipment.slots[2] == CHAIN, "Full inventory swap uses vacated slot")
	check(inventory.entries.back().item == LEATHER, "Replaced armor safely stored")
	check(not equipment.unequip(inventory, Equipment.Slot.MAIN), "Main remains equipped")
	check(equipment.swap_weapons() and equipment.slots[0].weapon.kind == WeaponData.Kind.SPEAR and inventory.entries.size() == 40, "Weapon swap does not consume inventory capacity")
	inventory.remove(0, 50)
	check(equipment.unequip(inventory, Equipment.Slot.SUB) and equipment.slots[1] == null, "Unequip succeeds when space exists")
	check(not equipment.swap_weapons(), "Empty sub cannot swap")
	var draft := inventory.copy()
	draft.remove(0)
	check(draft.entries.size() == inventory.entries.size() - 1, "Transaction copy is independent")
	var state := RunCarryover.new()
	state.inventory.add(POTION, 50)
	check(state.transfer_item(state.inventory, state.storage, 0) == 50 and state.inventory.entries.is_empty(), "Whole consumable stack deposits")
	check(state.storage.max_entries == 120 and state.storage.max_stack == 999, "Warehouse has dedicated capacity")
	state.inventory.add(POTION, 49)
	check(state.transfer_item(state.storage, state.inventory, 0) == 1 and state.storage.entries[0].count == 49, "Withdrawal moves only destination capacity")
	check(state.transfer_item(state.storage, state.inventory, -1) == 0 and state.transfer_item(state.storage, state.storage, 0) == 0, "Invalid warehouse transfer does not mutate")


func new_run() -> Node2D:
	var run := RUN.instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	root.add_child(run)
	var grid: GridState = run.dungeon.grid
	grid.size = Vector2i(24, 24)
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	run.dungeon.ground_items.clear()
	run.dungeon.has_stairs = false
	grid.place(run.turns.player, Vector2i(2, 2))
	run._refresh()
	return run


func give_and_equip(run: Node2D, item: ItemData, slot: int) -> void:
	var index: int = run.turns.player.inventory.entries.size()
	check(run.turns.player.inventory.add(item) == 0, "Test equipment added")
	check(run.turns.submit_inventory("equip", index, slot), "Equip action accepted")


func test_effects() -> void:
	var run := new_run()
	var player: Node2D = run.turns.player
	give_and_equip(run, LEATHER, Equipment.Slot.ARMOR)
	check(player.stats.defense == 1, "Leather defense applied")
	give_and_equip(run, CHAIN, Equipment.Slot.ARMOR)
	check(player.stats.defense == 2, "Armor swap replaces rather than accumulates bonus")
	player.gain_ability(preload("res://data/abilities/defense.tres"))
	run.turns.submit_inventory("unequip", -1, Equipment.Slot.ARMOR)
	check(player.stats.defense == 1, "Unequip preserves ability defense")
	give_and_equip(run, VITAL, Equipment.Slot.ACCESSORY_1)
	check(player.stats.max_hp == 28 and player.hp == 24, "HP accessory raises cap without free healing")
	player.hp = 20
	run.turns.submit_inventory("unequip", -1, Equipment.Slot.ACCESSORY_1)
	check(player.stats.max_hp == 24 and player.hp == 20, "HP removal preserves missing health")
	give_and_equip(run, VITAL, Equipment.Slot.ACCESSORY_1)
	give_and_equip(run, VITAL, Equipment.Slot.ACCESSORY_2)
	check(player.stats.max_hp == 32 and player.hp == 20, "Two accessory slots apply independently")
	player.gain_ability(preload("res://data/abilities/max_hp.tres"))
	player.hp = 35
	run.turns.submit_inventory("unequip", -1, Equipment.Slot.ACCESSORY_1)
	run.turns.submit_inventory("unequip", -1, Equipment.Slot.ACCESSORY_2)
	check(player.stats.max_hp == 27 and player.hp == 27, "Removing cap clamps HP and preserves level ability")
	give_and_equip(run, VISION, Equipment.Slot.ACCESSORY_1)
	player.gain_ability(preload("res://data/abilities/vision.tres"))
	check(player.vision_range == 11, "Accessory and ability vision combine")
	run.turns.submit_inventory("unequip", -1, Equipment.Slot.ACCESSORY_1)
	check(player.vision_range == 9, "Vision reverts without losing ability")
	give_and_equip(run, POWER, Equipment.Slot.ACCESSORY_1)
	check(player.effective_weapon().damage_bonus == 1, "Power accessory increases weapon damage")
	run.turns.submit("switch", player.facing)
	check(player.weapon.kind == WeaponData.Kind.SPEAR and player.effective_weapon().damage_bonus == 1, "Power applies after switching weapons")
	check(preload("res://data/player_stats.tres").max_hp == 24 and LEATHER.defense_bonus == 1, "Definition Resources stay unchanged")
	var inv: Inventory = player.inventory
	var equipped: Equipment = player.equipment
	var count: int = inv.entries.size()
	run.floor_number = 2
	run._load_floor()
	run._refresh()
	check(player.inventory == inv and player.equipment == equipped and inv.entries.size() == count and player.weapon.kind == WeaponData.Kind.SPEAR, "Inventory and equipment persist across floors")
	run.free()
	run = new_run()
	check(run.turns.player.inventory.entries.is_empty() and run.turns.player.equipment.slots[2] == null and run.turns.player.weapon.kind == WeaponData.Kind.SWORD, "New run restores initial inventory and equipment")
	run.free()


func test_turns_and_ui() -> void:
	var run := new_run()
	var player: Node2D = run.turns.player
	player.inventory.add(POTION, 2)
	player.inventory.add(LEATHER)
	var enemy := ENEMY.instantiate()
	run.dungeon.get_node("Actors").add_child(enemy)
	run.dungeon.grid.place(enemy, Vector2i(2, 3))
	run.turns.enemies.append(enemy)
	press_inventory(run)
	check(run.inventory_panel.visible and not player.input_enabled and run.turns.turn_count == 0, "Opening inventory is free and disables movement")
	run.inventory_panel._select_item(1)
	check(run.inventory_panel.equip_buttons[2].visible and not run.inventory_panel.equip_buttons[0].visible, "UI shows compatible equipment actions only")
	check(player.hp == 24 and enemy.cell == Vector2i(2, 3), "Selecting item does not advance enemies")
	run.inventory_panel.equip_buttons[2].pressed.emit()
	check(run.inventory_panel.visible and not player.input_enabled and run.turns.turn_count == 0 and player.hp == 24, "Equip refreshes the open UI without spending a turn")
	player.hp = 10
	run.inventory_panel._select_item(0)
	run.inventory_panel.get_node("Panel/Use").pressed.emit()
	if run.presentation.playing:
		await run.presentation.finished
		await process_frame
	check(player.hp == 16 and player.inventory.entries[0].count == 1 and run.turns.turn_count == 1, "Potion heals eight then enemy attacks once")
	player.hp = player.stats.max_hp
	press_inventory(run)
	check(not run.turns.submit_inventory("use", 0) and player.inventory.entries[0].count == 1 and run.turns.turn_count == 1, "Full HP use does not consume item or turn")
	player.inventory.add(CHAIN, 39)
	run.inventory_panel.action_requested.emit("unequip", -1, Equipment.Slot.ARMOR)
	check(run.inventory_panel.visible and run.turns.turn_count == 1 and player.equipment.slots[2] == LEATHER, "Failed unequip retains modal, armor and turn")
	press_inventory(run)
	check(not run.inventory_panel.visible and player.input_enabled and run.turns.turn_count == 1, "Closing inventory is free")
	run.turns.submit("switch", Vector2i.RIGHT)
	check(player.weapon.kind == WeaponData.Kind.SPEAR and player.hp == 24 and run.turns.turn_count == 1, "Quick switch is free")
	run.turns.busy = true
	press_inventory(run)
	check(not run.inventory_panel.visible and not run.turns.submit_inventory("switch"), "No inventory actions during ability/enemy phase")
	run.turns.busy = false
	run.turns.ended = true
	check(not run.turns.submit_inventory("use", 0), "Dead run cannot use items")
	run.free()


func test_pickup_and_generation() -> void:
	var run := new_run()
	var player: Node2D = run.turns.player
	player.inventory.add(POTION, 49)
	var drop := Vector2i(3, 2)
	run.dungeon.ground_items[drop] = InventoryEntry.new(POTION, 4)
	run._refresh()
	check(run.dungeon.get_node("Items").visible_cells.has(drop), "Visible ground item has current visibility")
	run.turns.submit("move", Vector2i.RIGHT)
	check(player.inventory.entries[0].count == 50 and run.dungeon.ground_items[drop].count == 3 and run.turns.turn_count == 1, "Partial auto pickup leaves excess and costs no extra turn")
	run.turns.submit("move", Vector2i.LEFT)
	run.turns.submit("move", Vector2i.RIGHT)
	check(run.dungeon.ground_items[drop].count == 3 and player.inventory.entries.size() == 1, "Full stack does not spill to another slot")
	player.inventory.remove(0, 50)
	player.inventory.add(LEATHER, 40)
	run.turns.submit("move", Vector2i.LEFT)
	run.turns.submit("move", Vector2i.RIGHT)
	check(run.dungeon.ground_items[drop].count == 3 and player.inventory.entries.size() == 40, "Full inventory leaves pickup on floor")
	player.inventory.remove(0)
	run.turns.submit("move", Vector2i.LEFT)
	run.turns.submit("move", Vector2i.RIGHT)
	check(not run.dungeon.ground_items.has(drop) and player.inventory.entries.back().count == 3, "Freed slot accepts remaining stack")
	var hidden := Vector2i(20, 20)
	run.dungeon.ground_items[hidden] = InventoryEntry.new(VITAL)
	run._refresh()
	check(not run.dungeon.get_node("Items").visible_cells.has(hidden), "Items outside current vision are hidden")
	run.floor_number = 2
	run._load_floor()
	check(run.dungeon.ground_items.is_empty(), "Old ground items removed on floor change")
	run.free()
	for seed_value in range(1, 6):
		run = RUN.instantiate()
		run.generation_seed = seed_value
		root.add_child(run)
		for floor_value in range(1, 4):
			if floor_value != 1:
				run.floor_number = floor_value
				run._load_floor()
			var reachable := LayoutUtils.distances(run.dungeon.grid, run.dungeon.start_cell)
			check(run.dungeon.ground_items.size() == 6, "Configured floor item count")
			var valid := true
			for cell: Vector2i in run.dungeon.ground_items:
				valid = valid and reachable.has(cell) and not run.dungeon.grid.occupants.has(cell) and cell != run.dungeon.stairs_cell
			check(valid, "Drops reachable and do not overlap actors or stairs")
		run.free()


func run_tests() -> void:
	var input_setup := load("res://game/main.gd").new() as Node
	root.add_child(input_setup)
	test_capacity_and_transactions()
	test_effects()
	await test_turns_and_ui()
	test_pickup_and_generation()
	await process_frame
	print("Inventory tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
