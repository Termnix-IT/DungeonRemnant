extends SceneTree

var checks := 0
var failures := 0
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const FAST := preload("res://data/enemies/fast_enemy.tres")
const SUMMONER := preload("res://data/enemies/summoner_enemy.tres")
const AXE := preload("res://data/weapons/axe.tres")


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func make_run() -> Node2D:
	var run := preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	run.dungeon_settings.reinforcement_total_cap = 0
	root.add_child(run)
	run.dungeon.grid.walls.clear()
	run.dungeon.grid.pillars.clear()
	run.dungeon.grid.occupants.clear()
	run.dungeon.grid.place(run.turns.player, Vector2i(3, 3))
	run.dungeon.has_stairs = false
	return run


func spawn(run: Node2D, stats: EnemyStats, cell: Vector2i) -> Node2D:
	var enemy := ENEMY.instantiate()
	enemy.stats = stats
	run.dungeon.get_node("Actors").add_child(enemy)
	run.dungeon.grid.place(enemy, cell)
	run.turns.enemies.append(enemy)
	return enemy


func test_enemies() -> void:
	var run := make_run()
	var player: Node2D = run.turns.player
	var fast := spawn(run, FAST, Vector2i(8, 3))
	fast.take_turn(run.dungeon.grid, player)
	check(fast.cell == Vector2i(5, 3), "Fast enemy moves three cells")
	var hp: int = player.hp
	fast.take_turn(run.dungeon.grid, player)
	check(player.hp == hp - 1 and fast.cell == Vector2i(4, 3), "Fast enemy closes and attacks only once")
	fast.take_turn(run.dungeon.grid, player)
	check(player.hp == hp - 2, "Adjacent fast enemy attacks exactly once")
	run.free()
	run = make_run()
	var summoner := spawn(run, SUMMONER, Vector2i(10, 10))
	for turn in 6:
		run.turns.submit("attack", Vector2i.LEFT)
	check(summoner.cell == Vector2i(10, 10) and run.turns.enemies.size() == 2, "Immobile summoner spawns on interval")
	var charge: Node2D = run.turns.enemies.back()
	check(charge.stats.exp_reward == 1 and charge.stats.gold_reward == 0 and charge.shot_direction == Vector2i.ZERO, "Summon reward fixed; no action on spawn turn")
	for attempt in 12:
		run._summon_enemy(summoner)
	check(run.turns.enemies.size() == 7, "Summoned live count capped")
	charge.hp = 0
	run.dungeon.grid.remove_actor(charge)
	run._summon_enemy(summoner)
	check(run.turns.enemies.size() == 8, "Killed summon can be replenished indefinitely")
	run.free()
	run = make_run()
	charge = spawn(run, preload("res://data/enemies/charge_enemy.tres"), Vector2i(6, 3))
	charge.take_turn(run.dungeon.grid, run.turns.player)
	check(charge.cell == Vector2i(6, 3) and charge.shot_direction == Vector2i.LEFT, "Charger warns before rushing")
	hp = run.turns.player.hp
	charge.take_turn(run.dungeon.grid, run.turns.player)
	check(charge.cell == Vector2i(4, 3) and run.turns.player.hp == hp - 2, "Charger rushes along warning and attacks once")
	run.free()


func test_axe_and_loot() -> void:
	var run := make_run()
	var player: Node2D = run.turns.player
	player.weapon = AXE
	player.gain_ability(preload("res://data/abilities/spear_range.tres"))
	check(player.effective_weapon().reach == 2 and AXE.damage_bonus > preload("res://data/weapons/sword.tres").damage_bonus, "Axe trades fixed two-cell reach for higher damage")
	spawn(run, FAST, Vector2i(4, 3))
	spawn(run, FAST, Vector2i(5, 3))
	check(CombatRules.attack_cells(run.dungeon.grid, player.cell, Vector2i.RIGHT, player.effective_weapon()).size() == 2, "Axe strikes both forward cells")
	check(CombatRules.attack(run.dungeon.grid, player, Vector2i.RIGHT, player.effective_weapon()) == 10, "Axe hits both enemies")
	run.dungeon.grid.walls[Vector2i(4, 3)] = true
	check(CombatRules.attack_cells(run.dungeon.grid, player.cell, Vector2i.RIGHT, AXE).is_empty(), "Axe cannot hit through walls")
	var elite := ENEMY.instantiate()
	elite.stats = FAST
	run.dungeon_settings.elite_chance = 1.0
	run._make_elite(elite)
	check(elite.stats.elite and elite.stats.max_hp > FAST.max_hp and not FAST.elite, "Elite strengthens per-instance stats without mutating definitions")
	run.dungeon.get_node("Actors").add_child(elite)
	elite.cell = Vector2i(8, 8)
	run.dungeon_settings.accessory_drop_chance = 1.0
	run._drop_enemy_loot(elite)
	check(run.dungeon.ground_items.has(elite.cell) and not run.dungeon.ground_items[elite.cell].item.effect_id.is_empty(), "Elite drops consumable accessory")
	for index in 100:
		var item := ItemCatalog.ground_item(index)
		check(item.effect_id.is_empty() and item.kind != ItemData.Kind.ACCESSORY, "Accessories are absent from normal floor loot")
	var state := RunCarryover.new()
	state.gold = 1000
	check(state.buy_item(false, &"exp_talisman", 2), "Accessory can be bought")
	state.inventory.add(ItemData.from_weapon(AXE))
	var decoded := SaveCodec.decode(SaveCodec.encode(state))
	check(decoded != null and decoded.inventory.entries.size() == 2, "Axe and consumable accessories survive save roundtrip")
	run.free()


func test_effects() -> void:
	var run := make_run()
	var player: Node2D = run.turns.player
	var items := ItemCatalog.talismans()
	for item in items:
		player.inventory.add(item, 2)
	check(run.turns.submit_inventory("use", 0), "Accessory usable at full health")
	check(player.effective_weapon().damage_bonus == 3 and player.active_effects.effects[&"damage"].remaining == 30, "Attack effect applied with full duration")
	var turn: int = run.turns.turn_count
	check(not run.turns.submit_inventory("use", 0) and player.inventory.entries[0].count == 1 and run.turns.turn_count == turn, "Duplicate effect costs no item or turn")
	for index in range(1, 5):
		check(run.turns.submit_inventory("use", index), "Distinct buffs can stack")
	check(player.active_effects.buff_count() == 5 and player.stats.defense == 2 and player.vision_range == 11, "Five simultaneous buffs apply")
	turn = run.turns.turn_count
	check(not run.turns.submit_inventory("use", 5) and player.inventory.entries[5].count == 2 and run.turns.turn_count == turn, "Sixth buff rejected without consuming")
	check(run.turns.submit_inventory("use", 6) and player.active_effects.buff_count() == 5, "Floor effect ignores five-buff cap")
	check(not run.turns.submit_inventory("use", 6), "Floor effect cannot stack with itself")
	var target := spawn(run, FAST, Vector2i(4, 3))
	target.hp = 1
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.progression.level == 2 and run.progression.exp == 5, "Floor EXP effect increases a ten-point kill to fifteen")
	while not run.turns.offered_abilities.is_empty():
		var choices: Array = run.turns.offered_abilities
		var selected: AbilityData = choices[0]
		for ability: AbilityData in choices:
			if ability.effect not in [AbilityData.Effect.DEFENSE, AbilityData.Effect.VISION]:
				selected = ability
				break
		run.turns.choose_ability(selected.id)
	var base_defense: int = player.stats.defense - 2
	var base_vision: int = player.vision_range - 3
	run.floor_number = 2
	run._load_floor()
	check(player.active_effects.amount(&"exp") == 0 and player.active_effects.buff_count() == 5, "Floor change clears only floor effects")
	for index in 60:
		player.active_effects.tick()
	player.refresh_equipment_effects()
	check(player.active_effects.effects.is_empty() and player.stats.defense == base_defense and player.vision_range == base_vision, "Expiry restores stats without drift")
	player.active_effects.add(items[0])
	player.active_effects.add(items[6])
	run.finish_run(false, true)
	check(player.active_effects.effects.is_empty(), "Return clears every temporary effect")
	run.free()


func run_tests() -> void:
	test_enemies()
	test_axe_and_loot()
	test_effects()
	print("Content tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
