class_name CombatRules
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP, Vector2i(1, -1), Vector2i.RIGHT, Vector2i(1, 1),
	Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1),
]


static func attack_cells(grid: GridState, origin: Vector2i, direction: Vector2i, weapon: WeaponData = null) -> Array[Vector2i]:
	if weapon != null and weapon.sweeps_sides:
		var cells: Array[Vector2i] = []
		var direction_index := DIRECTIONS.find(direction)
		if direction_index < 0:
			return cells
		for offset in [0, -1, 1]:
			var sweep_direction: Vector2i = DIRECTIONS[(direction_index + offset + DIRECTIONS.size()) % DIRECTIONS.size()]
			cells.append_array(ray_cells(grid, origin, sweep_direction, weapon.reach, weapon.pierces))
		return cells
	return ray_cells(grid, origin, direction, weapon.reach if weapon != null else 1, weapon.pierces if weapon != null else false)


static func ray_cells(grid: GridState, origin: Vector2i, direction: Vector2i, reach: int, pierces: bool = false) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var previous := origin
	for distance in range(1, reach + 1):
		var destination := origin + direction * distance
		if not grid.can_step(previous, destination):
			break
		cells.append(destination)
		if grid.occupants.has(destination) and not pierces:
			break
		previous = destination
	return cells


static func attack(grid: GridState, attacker: Node2D, direction: Vector2i, weapon: WeaponData = null) -> int:
	grid.visual_events.append({"kind": "attack", "actor": attacker, "origin": attacker.cell, "direction": direction, "weapon": weapon})
	var cells := attack_cells(grid, attacker.cell, direction, weapon)
	if cells.is_empty():
		return 0
	var bonus := weapon.damage_bonus if weapon != null else 0
	# Snapshot targets before knockback or deaths can change cell occupancy.
	var targets: Array[Node2D] = []
	for cell in cells:
		var target: Node2D = grid.occupants.get(cell)
		if target != null and target != attacker and target.hp > 0:
			targets.append(target)
	var total_damage := 0
	for target in targets:
		total_damage += damage_target(grid, attacker, target, bonus)
		if target.hp > 0 and weapon != null:
			for step in weapon.knockback_distance:
				if not grid.move_actor(target, target.cell + direction):
					break
	return total_damage


static func damage_target(grid: GridState, attacker: Node2D, target: Node2D, bonus: int = 0) -> int:
	var damage: int = maxi(1, attacker.stats.attack + bonus - target.stats.defense)
	var actual_damage: int = mini(target.hp, damage)
	target.hp = maxi(0, target.hp - damage)
	grid.visual_events.append({"kind": "hit", "actor": target, "source": attacker, "origin": target.cell, "direction": target.cell - attacker.cell, "damage": actual_damage, "dead": target.hp == 0})
	if target.hp == 0:
		grid.remove_actor(target)
	target.queue_redraw()
	return actual_damage
