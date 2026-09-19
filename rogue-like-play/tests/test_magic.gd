extends SceneTree

const STAFF := preload("res://data/weapons/staff.tres")
const BOLT := preload("res://data/items/bolt_scroll.tres")
const FLAME := preload("res://data/items/flame_scroll.tres")
const HEAL := preload("res://data/items/heal_scroll.tres")
const MANA := preload("res://data/items/mana_potion.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func test_socket_and_save() -> void:
	var state := RunCarryover.new()
	state.equipment.slots[0] = ItemData.from_weapon(STAFF)
	var original := state.equipment.slots[0]
	state.inventory.add(BOLT)
	check(state.equipment.socket(state.inventory, 0, 0), "Equip scroll into staff")
	check(state.inventory.entries.is_empty() and original.socketed_scroll == null, "Socket moves item without mutating shared definitions")
	check(not state.equipment.socket(state.inventory, -1, 0) and not state.equipment.can_socket(1), "Invalid slot/index rejected")
	state.inventory.add(HEAL)
	check(state.equipment.socket(state.inventory, 0, 0) and state.inventory.entries[0].item == BOLT, "Swap returns previous scroll")
	var loaded := SaveCodec.decode(SaveCodec.encode(state))
	check(loaded != null and loaded.equipment.slots[0].socketed_scroll.id == HEAL.id, "Equipped spell survives serialization")
	state.equipment.slots[1] = ItemData.from_weapon(STAFF)
	state.equipment.socket(state.inventory, 0, 1)
	state.equipment.unequip(state.inventory, 1)
	state.transfer_item(state.inventory, state.storage, 0)
	loaded = SaveCodec.decode(SaveCodec.encode(state))
	check(loaded.storage.entries[0].item.socketed_scroll.id == BOLT.id, "Stored staff retains spell")
	check(not state.sell_item(true, 0, 1), "Socketed staff cannot accidentally be sold")
	state.storage.add(ItemData.from_weapon(STAFF))
	check(state.sell_item(true, 1, 1) and state.storage.entries.size() == 1 and state.storage.entries[0].item.socketed_scroll != null, "Grouped sale preserves socketed copies")
	var data := SaveCodec.encode(RunCarryover.new())
	data.version = 1
	check(SaveCodec.decode(data) != null, "Version 1 migrates")
	data.equipment[0] = {"id": "weapon_0", "scroll": "bolt_scroll"}
	check(SaveCodec.decode(data) == null, "Invalid socket on sword rejected")
	data.equipment[0] = {"id": "weapon_4", "scroll": "healing_potion"}
	check(SaveCodec.decode(data) == null, "Non-scroll socket rejected")
	state.inventory = Inventory.new(1)
	state.inventory.add(MANA)
	check(not state.equipment.unsocket(state.inventory, 0) and state.equipment.slots[0].socketed_scroll == HEAL, "Full inventory cannot lose detached scroll")
	var rng := RandomNumberGenerator.new()
	state.inventory = Inventory.new()
	state.inventory.add(BOLT)
	RunLoss.apply(state.inventory, 0, rng)
	check(state.inventory.entries.is_empty() and state.equipment.slots[0].socketed_scroll == HEAL, "Loose scroll lost; equipped scroll protected")


func test_casting() -> void:
	var run := preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	run.dungeon_settings.reinforcement_total_cap = 0
	root.add_child(run)
	var player: Node2D = run.turns.player
	check(run.hud.mp_bar.value == player.mp and run.hud.mp_bar.max_value == player.stats.max_mp, "HUD starts with full MP gauge")
	var grid: GridState = run.dungeon.grid
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	grid.place(player, Vector2i(3, 3))
	player.weapon = STAFF
	check(player.effective_weapon().damage_bonus == -3 and player.effective_weapon().sweeps_sides, "Empty staff uses low-damage sword-like swing")
	player.inventory.add(BOLT)
	check(run.turns.submit_inventory("socket", 0, 0) and run.turns.turn_count == 0, "Socketting costs no turn")
	var enemy := preload("res://actors/enemy/enemy.tscn").instantiate()
	enemy.stats = EnemyStats.new()
	enemy.stats.max_hp = 100
	enemy.stats.detection_range = 1
	run.dungeon.get_node("Actors").add_child(enemy)
	grid.place(enemy, Vector2i(6, 3))
	run.turns.enemies.append(enemy)
	check(run.turns.submit("attack", Vector2i.RIGHT) and player.mp == 17 and enemy.hp == 92, "Ranged spell damages and spends MP once")
	check(run.hud.mp_bar.value == 17 and run.hud.mp_value.text == "17 / 20", "Casting updates MP gauge and number")
	player.mp = 0
	check(not run.turns.submit("attack", Vector2i.RIGHT) and run.turns.turn_count == 1 and enemy.hp == 92, "Insufficient MP costs no turn or damage")
	run._refresh()
	check(run.hud.mp_bar.value == 0 and run.hud.mp_value.text == "0 / 20", "Empty MP gauge shows zero")
	player.inventory.add(MANA)
	check(run.turns.submit_inventory("use", 0) and player.mp == 10, "Mana potion restores MP and spends turn")
	check(run.hud.mp_bar.value == 10 and run.hud.mp_value.text == "10 / 20", "Mana potion updates MP gauge and number")
	player.inventory.add(FLAME)
	run.turns.submit_inventory("socket", 0, 0)
	check(CombatRules.attack_cells(grid, player.cell, Vector2i.RIGHT, player.effective_weapon()).size() == 6, "Flame attacks three two-cell rays")
	player.inventory.add(HEAL)
	run.turns.submit_inventory("socket", 1, 0)
	player.hp = 1
	check(run.turns.submit("attack", Vector2i.RIGHT) and player.hp == 13 and player.mp == 5, "Heal restores health and consumes MP")
	player.hp = player.stats.max_hp
	var turns: int = run.turns.turn_count
	check(not run.turns.submit("attack", Vector2i.RIGHT) and player.mp == 5 and run.turns.turn_count == turns, "Full-health healing consumes nothing")
	run.floor_number = 2
	run._load_floor()
	check(player.mp == 5 and player.equipment.slots[0].socketed_scroll.id == HEAL.id, "Floor transition preserves MP and spell")
	run.finish_run(false, true)
	run.retry_run()
	check(run.turns.player.mp == run.turns.player.stats.max_mp and run.turns.player.equipment.slots[0].socketed_scroll.id == HEAL.id, "Departure restores MP and retained staff")
	run.free()


func test_hub() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	main.state.equipment.slots[0] = ItemData.from_weapon(STAFF)
	main.state.inventory.add(BOLT)
	main.get_node("Hub").refresh(main.state)
	check(main.equip_item(false, 0, 0) and main.state.equipment.slots[0].socketed_scroll == BOLT, "Hub equips selected scroll")
	check(main.unsocket_scroll(0) and main.state.inventory.entries[0].item == BOLT, "Hub detaches scroll")
	main.saving_enabled = true
	main.save_store.path = "res://.godot/nonexistent-magic-dir/save.json"
	check(not main.equip_item(false, 0, 0) and main.state.inventory.entries[0].item == BOLT and main.state.equipment.slots[0].socketed_scroll == null, "Failed save rolls back socket transaction")
	main.free()


func run_tests() -> void:
	test_socket_and_save()
	test_casting()
	test_hub()
	print("Magic tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
