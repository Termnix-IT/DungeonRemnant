extends RefCounted


static func arrange(run: Node2D) -> void:
	# Fixed geometry keeps Phase 1/2 rule tests independent of random generation.
	run.dungeon.grid.size = Vector2i(24, 15)
	run.dungeon.grid.walls.clear()
	run.dungeon.grid.pillars.clear()
	run.dungeon.fog.reset()
	run.dungeon.get_node("ExploredTerrain").clear()
	run.dungeon.grid.occupants.clear()
	run.dungeon.has_stairs = false
	run.dungeon.grid.place(run.turns.player, Vector2i(3, 3))
	var cells: Array[Vector2i] = [Vector2i(8, 3), Vector2i(18, 5), Vector2i(5, 11)]
	for index in run.turns.enemies.size():
		run.dungeon.grid.place(run.turns.enemies[index], cells[index])
	run._refresh()
