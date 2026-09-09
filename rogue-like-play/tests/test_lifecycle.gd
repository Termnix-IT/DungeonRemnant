extends SceneTree

const RUN := preload("res://game/run/run.tscn")
const POTION := preload("res://data/items/healing_potion.tres")
const ARMOR := preload("res://data/items/leather_armor.tres")
const VITAL := preload("res://data/items/vital_charm.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func count_items(inventory: Inventory) -> int:
	var total := 0
	for entry in inventory.entries:
		total += entry.count
	return total


func make_run() -> Node2D:
	var run := RUN.instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	root.add_child(run)
	return run


func run_tests() -> void:
	root.add_child(load("res://game/main.gd").new())
	var rng := RandomNumberGenerator.new()
	for seed_value in range(100):
		rng.seed = seed_value
		for size in [0, 1, 2, 3, 49, 50]:
			var inv := Inventory.new()
			inv.add(POTION, size)
			var loss := RunLoss.apply(inv, size, rng)
			check(count_items(inv) == size - size / 2, "Half units lost, rounded down")
			check(loss.gold_lost == size / 2 and loss.item_count_lost == size / 2, "Gold and report rounding")
	var armor_losses := 0
	for seed_value in range(500):
		rng.seed = seed_value
		var inv := Inventory.new()
		inv.add(POTION, 9)
		inv.add(ARMOR)
		var loss := RunLoss.apply(inv, 101, rng)
		check(count_items(inv) == 5 and loss.gold_lost == 50, "Mixed gear and stack loss")
		armor_losses += int(loss.items_lost.get(ARMOR.display_name, 0))
	check(armor_losses > 180 and armor_losses < 320, "Gear has individual-unit probability, not slot probability")
	var run := make_run()
	var player: Node2D = run.turns.player
	player.inventory.add(POTION, 9)
	player.inventory.add(ARMOR, 2)
	player.equipment.slots[2] = ARMOR
	player.equipment.slots[3] = VITAL
	player.equipment.slots[4] = VITAL
	player.refresh_equipment_effects()
	player.gain_ability(preload("res://data/abilities/max_hp.tres"))
	player.gain_ability(preload("res://data/abilities/attack.tres"))
	run.progression.gain_exp(10)
	run.turns.gold = 101
	run.turns.earned_gold = 41
	run.floor_number = 4
	var slots: Array = player.equipment.slots.duplicate()
	run.request_abort()
	check(run.result_panel.visible and run.turns.paused and not player.input_enabled, "Abort is modal")
	check(not run.turns.submit_inventory("switch") and run.turns.turn_count == 0, "Confirmation blocks actions")
	run._cancel_abort()
	check(not run.result_panel.visible and player.input_enabled and run.turns.gold == 101, "Cancel costs nothing")
	player.hp = 0
	run.turns.ended = true
	run._on_turn_finished()
	check(run.result_panel.visible and run.turns.gold == 51 and count_items(player.inventory) == 6, "Death applies half loss")
	check(run.result.floor == 4 and run.result.earned_gold == 41, "Result captures run stats")
	check(player.equipment.slots == slots, "All five equipped slots protected")
	run.finish_run(false)
	run.finish_run(true)
	check(run.turns.gold == 51 and count_items(player.inventory) == 6 and not run.result.cleared, "Repeated finish cannot change outcome or lose twice")
	run.retry_run()
	player = run.turns.player
	check(run.floor_number == 1 and run.turns.turn_count == 0 and run.progression.level == 1 and run.progression.exp == 0, "Retry resets floor, turns, level and EXP")
	check(player.abilities.levels.is_empty() and player.stats.attack == 4 and player.stats.max_hp == 32 and player.hp == 32, "Retry resets growth, restores gear bonuses and full HP")
	check(player.equipment.slots == slots and run.turns.gold == 51 and count_items(player.inventory) == 6, "Retry retains remaining possessions")
	check(run.turns.earned_gold == 0 and player.input_enabled and run.result.is_empty(), "Retry starts active clean run")
	run.retry_run()
	check(run.turns.player == player, "Retry outside results is ignored")
	run.floor_number = 10
	run.finish_run(true)
	check(run.result.cleared and run.result.gold_lost == 0 and run.result.item_count_lost == 0 and run.turns.gold == 51, "Clear preserves everything")
	run.retry_run()
	check(count_items(run.turns.player.inventory) == 6 and run.turns.player.equipment.slots == slots, "Clear retry preserves gear and inventory")
	run.request_abort()
	run.result_panel.accept.pressed.emit()
	check(not run.result_panel.confirming and run.turns.gold == 26 and count_items(run.turns.player.inventory) == 3, "Confirmed abort shares death result")
	run.result_panel.accept.pressed.emit()
	check(run.result.is_empty() and run.turns.gold == 26, "Result button retries without second loss")
	run.free()
	run = make_run()
	var enemy := preload("res://actors/enemy/enemy.tscn").instantiate()
	enemy.stats = EnemyStats.new()
	enemy.stats.exp_reward = 0
	enemy.stats.gold_reward = 17
	run.dungeon.get_node("Actors").add_child(enemy)
	enemy.hp = 0
	run.turns.enemies.append(enemy)
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.turns.gold == 17 and run.turns.earned_gold == 17, "Enemy data supplies Gold reward")
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.turns.gold == 17, "Dead enemy reward claimed once")
	run.floor_number = 2
	run._load_floor()
	check(run.turns.gold == 17, "Gold persists across floors")
	run.free()
	run = make_run()
	var grid: GridState = run.dungeon.grid
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	grid.place(run.turns.player, Vector2i(3, 3))
	run.dungeon.has_stairs = true
	run.dungeon.stairs_cell = Vector2i(4, 3)
	enemy = preload("res://actors/enemy/enemy.tscn").instantiate()
	run.dungeon.get_node("Actors").add_child(enemy)
	grid.place(enemy, Vector2i(5, 3))
	run.turns.enemies.append(enemy)
	run.turns.player.hp = 1
	run.turns.gold = 11
	run.turns.submit("move", Vector2i.RIGHT)
	check(run.turns.player.hp == 0 and run.result_panel.visible and run.turns.gold == 6, "Enemy lethal action opens result with losses")
	check(run.floor_number == 1 and run.result.floor == 1, "Death takes precedence over stair transition")
	check(not run.turns.submit_inventory("switch") and not run.turns.player.input_enabled, "Result disables subsequent actions")
	run.free()
	print("Lifecycle tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
