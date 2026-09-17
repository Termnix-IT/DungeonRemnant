extends SceneTree

# Omniscient deterministic test driver, not gameplay AI or a difficulty estimate.
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func path_to(run: Node2D, target: Vector2i) -> Array[Vector2i]:
	var grid: GridState = run.dungeon.grid
	var finder := AStarGrid2D.new()
	finder.region = Rect2i(Vector2i.ZERO, grid.size)
	finder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	finder.update()
	for cell: Vector2i in grid.walls:
		finder.set_point_solid(cell)
	for cell: Vector2i in grid.occupants:
		if cell != run.turns.player.cell and cell != target:
			finder.set_point_solid(cell)
	return finder.get_id_path(run.turns.player.cell, target)


func act(run: Node2D) -> bool:
	if not run.transition_kind.is_empty():
		run.resolve_transition(true)
		return true
	var player: Node2D = run.turns.player
	if not run.turns.offered_abilities.is_empty():
		var priorities := [AbilityData.Effect.DEFENSE, AbilityData.Effect.ATTACK, AbilityData.Effect.KILL_HEAL, AbilityData.Effect.MAX_HP, AbilityData.Effect.SWORD_DAMAGE]
		for effect in priorities:
			for ability: AbilityData in run.turns.offered_abilities:
				if ability.effect == effect:
					return run.turns.choose_ability(ability.id)
		return run.turns.choose_ability(run.turns.offered_abilities[0].id)
	for index in player.inventory.entries.size():
		var item: ItemData = player.inventory.entries[index].item
		if item.heal_amount > 0 and player.hp <= player.stats.max_hp - item.heal_amount:
			return run.turns.submit_inventory("use", index)
		if item.kind == ItemData.Kind.ARMOR:
			var armor: ItemData = player.equipment.slots[2]
			if armor == null or item.defense_bonus > armor.defense_bonus:
				return run.turns.submit_inventory("equip", index, 2)
		if item.kind == ItemData.Kind.ACCESSORY:
			for slot in [3, 4]:
				if player.equipment.slots[slot] == null:
					return run.turns.submit_inventory("equip", index, slot)
	for enemy: Node2D in run.turns.enemies:
		if enemy.hp > 0 and run.dungeon.grid.can_step(player.cell, enemy.cell):
			return run.turns.submit("attack", enemy.cell - player.cell)
	var destinations: Array[Vector2i] = []
	for cell: Vector2i in run.dungeon.ground_items:
		if player.inventory.entries.size() < 40:
			destinations.append(cell)
	for enemy: Node2D in run.turns.enemies:
		if enemy.hp > 0:
			destinations.append(enemy.cell)
	if destinations.is_empty():
		destinations.append(run.dungeon.stairs_cell)
	var best: Array[Vector2i] = []
	for target in destinations:
		var path := path_to(run, target)
		if path.size() > 1 and (best.is_empty() or path.size() < best.size()):
			best = path
	if best.is_empty():
		return false
	return run.turns.submit("move", best[1] - player.cell)


func run_tests() -> void:
	for seed_value in [47, 81, 123]:
		var save_path := "res://.godot/playthrough-%d-%d.json" % [seed_value, Time.get_ticks_usec()]
		var main := preload("res://game/main.tscn").instantiate()
		main.save_store.path = save_path
		root.add_child(main)
		main.start_run()
		var run: Node2D = main.active_run
		run.rng.seed = seed_value
		run.turns.player.abilities.rng.seed = seed_value
		run._load_floor()
		var actions := 0
		while run.result.is_empty() and actions < 6000:
			if not act(run):
				break
			actions += 1
		var cleared: bool = run.result.get("cleared", false)
		print("Playthrough seed %d: cleared=%s floor=%d level=%d HP=%d turns=%d Gold=%d" % [seed_value, cleared, run.floor_number, run.progression.level, run.turns.player.hp, run.turns.turn_count, run.turns.gold])
		if not cleared:
			failures += 1
			push_error("Reference playthrough did not clear")
		if cleared:
			var expected := SaveCodec.encode(run.carryover)
			run.retry_run()
			main.free()
			main = preload("res://game/main.tscn").instantiate()
			main.save_store.path = save_path
			root.add_child(main)
			if SaveCodec.encode(main.state) != expected:
				failures += 1
			main.start_run()
			if main.active_run.progression.level != 1 or not main.active_run.turns.player.abilities.levels.is_empty():
				failures += 1
		main.free()
	print("Playthrough tests: 3 seeds, %d failures" % failures)
	quit(0 if failures == 0 else 1)
