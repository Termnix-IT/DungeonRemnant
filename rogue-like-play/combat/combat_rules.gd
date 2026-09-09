class_name CombatRules
extends RefCounted


static func attack_cells(grid: GridState, origin: Vector2i, direction: Vector2i, weapon: WeaponData = null) -> Array[Vector2i]:
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
		if target.hp > 0 and weapon != null and weapon.knockback:
			grid.move_actor(target, target.cell + direction)
	return total_damage


static func damage_target(grid: GridState, attacker: Node2D, target: Node2D, bonus: int = 0) -> int:
	var damage: int = maxi(1, attacker.stats.attack + bonus - target.stats.defense)
	target.hp = maxi(0, target.hp - damage)
	if target.hp == 0:
		grid.remove_actor(target)
	target.queue_redraw()
	return damage
