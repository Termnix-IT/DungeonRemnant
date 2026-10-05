extends SceneTree

# Omniscient deterministic test driver, not gameplay AI or a difficulty estimate.
var failures := 0
# The reference loop covers 1F to 10F: defeat the tenth floor guardian, the
# first checkpoint of a fifty floor stage, then leave through its exit.
const LOOP_FLOOR := 10
const DETOUR_STEPS := 8


func _initialize() -> void:
	call_deferred("run_tests")


func path_to(run: Node2D, target: Vector2i, fight_through: bool = false) -> Array[Vector2i]:
	var grid: GridState = run.dungeon.grid
	var finder := AStarGrid2D.new()
	finder.region = Rect2i(Vector2i.ZERO, grid.size)
	finder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	finder.update()
	for cell: Vector2i in grid.walls:
		finder.set_point_solid(cell)
	for cell: Vector2i in grid.occupants:
		if not fight_through and cell != run.turns.player.cell and cell != target:
			finder.set_point_solid(cell)
	# A discovered monster house is avoided, as the spec expects of players,
	# unless the route starts inside it.
	if _avoids_house(run):
		var house: Rect2i = run.dungeon.monster_house
		for x in range(house.position.x, house.end.x):
			for y in range(house.position.y, house.end.y):
				var cell := Vector2i(x, y)
				if cell != target and grid.in_bounds(cell):
					finder.set_point_solid(cell)
	return finder.get_id_path(run.turns.player.cell, target)


func _avoids_house(run: Node2D) -> bool:
	return run.dungeon.house_discovered and not run.dungeon.monster_house.has_point(run.turns.player.cell)


func _in_house(run: Node2D, cell: Vector2i) -> bool:
	return _avoids_house(run) and run.dungeon.monster_house.has_point(cell)


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
	# Summoners are a source objective: do not farm their endlessly replenished guards.
	for enemy: Node2D in run.turns.enemies:
		if enemy.hp <= 0 or enemy.stats.behavior != EnemyStats.Behavior.SUMMONER:
			continue
		var route := path_to(run, enemy.cell, true)
		if route.size() > 1 and run.dungeon.grid.occupants.has(route[1]):
			return run.turns.submit("attack", route[1] - player.cell)
		if route.size() > 2:
			return run.turns.submit("move", route[1] - player.cell)
	for enemy: Node2D in run.turns.enemies:
		if enemy.hp > 0 and run.dungeon.grid.can_step(player.cell, enemy.cell):
			return run.turns.submit("attack", enemy.cell - player.cell)
	# Let a warned charge approach instead of orbiting a target that overshoots.
	for enemy: Node2D in run.turns.enemies:
		if enemy.hp > 0 and enemy.stats.behavior == EnemyStats.Behavior.CHARGER and enemy.detects(run.dungeon.grid, player.cell):
			var delta: Vector2i = enemy.cell - player.cell
			if delta.x == 0 or delta.y == 0 or absi(delta.x) == absi(delta.y):
				return run.turns.submit("attack", Vector2i(signi(delta.x), signi(delta.y)))
	# After the guardian falls, the loop ends by walking out of the exit.
	if run.floor_number == LOOP_FLOOR and run.exit_cell != Vector2i(-1, -1):
		var out := path_to(run, run.exit_cell, true)
		if out.size() > 1:
			if run.dungeon.grid.occupants.has(out[1]):
				return run.turns.submit("attack", out[1] - player.cell)
			return run.turns.submit("move", out[1] - player.cell)
	# Reinforcements keep arriving, so chasing every enemy never ends. Detour
	# only for nearby items and enemies; otherwise take the stairs. Boss floors
	# have no stairs until the boss falls, so they still hunt every enemy.
	var best: Array[Vector2i] = []
	for cell: Vector2i in run.dungeon.ground_items:
		if player.inventory.entries.size() < 40 and not _in_house(run, cell):
			best = _shorter(best, path_to(run, cell), DETOUR_STEPS)
	for enemy: Node2D in run.turns.enemies:
		if enemy.hp > 0 and not _in_house(run, enemy.cell):
			best = _shorter(best, path_to(run, enemy.cell), DETOUR_STEPS if run.dungeon.has_stairs else 100000)
	if best.is_empty() and run.dungeon.has_stairs:
		# Enemies in a corridor would block the route; walk into them instead.
		best = _shorter(best, path_to(run, run.dungeon.stairs_cell, true), 100000)
	if best.is_empty():
		return false
	if run.dungeon.grid.occupants.has(best[1]):
		return run.turns.submit("attack", best[1] - player.cell)
	return run.turns.submit("move", best[1] - player.cell)


func _shorter(best: Array[Vector2i], path: Array[Vector2i], limit: int) -> Array[Vector2i]:
	if path.size() > 1 and path.size() <= limit and (best.is_empty() or path.size() < best.size()):
		return path
	return best


func run_tests() -> void:
	for seed_value in [47, 81, 123]:
		var save_path := "res://.godot/playthrough-%d-%d.json" % [seed_value, Time.get_ticks_usec()]
		var main := preload("res://game/main.tscn").instantiate()
		main.save_store.path = save_path
		main.run_seed = seed_value
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
		var cleared: bool = run.result.get("safe_return", false) and run.result.get("floor", 0) == LOOP_FLOOR
		print("Playthrough seed %d: returned from 10F=%s floor=%d level=%d HP=%d turns=%d Gold=%d" % [seed_value, cleared, run.floor_number, run.progression.level, run.turns.player.hp, run.turns.turn_count, run.turns.gold])
		if not cleared:
			failures += 1
			push_error("Reference playthrough did not defeat the 10F guardian and return")
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
