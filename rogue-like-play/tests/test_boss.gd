extends SceneTree

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
	for seed_value in range(1, 21):
		var run := preload("res://game/run/run.tscn").instantiate()
		run.generation_seed = seed_value
		root.add_child(run)
		check(not run.turns.enemies.any(func(enemy): return enemy.stats.is_boss), "No boss before 10F")
		run.floor_number = 10
		run._load_floor()
		run._refresh()
		var bosses: Array = run.turns.enemies.filter(func(enemy): return enemy.stats.is_boss)
		check(bosses.size() == 1 and not run.dungeon.has_stairs, "Exactly one boss on final floor")
		var boss: Node2D = bosses[0]
		check(LayoutUtils.distances(run.dungeon.grid, run.turns.player.cell).has(boss.cell) and boss.cell != run.turns.player.cell, "Boss reachable, separated from start")
		check(run.dungeon.grid.occupants[boss.cell] == boss and not run.dungeon.ground_items.has(boss.cell), "Boss does not overlap enemies or drops")
		var grid: GridState = run.dungeon.grid
		grid.walls.clear()
		grid.pillars.clear()
		grid.occupants.clear()
		grid.place(run.turns.player, Vector2i(3, 3))
		grid.place(boss, Vector2i(4, 3))
		var bystander: Node2D = run.turns.enemies[0]
		grid.place(bystander, Vector2i(3, 4))
		for index in range(1, run.turns.enemies.size() - 1):
			grid.place(run.turns.enemies[index], Vector2i(20, 20 + index))
		boss.hp = 1
		run.turns.player.hp = 1
		run._refresh()
		check(run.hud.get_node("Boss").text.contains("深層の守護者"), "Visible boss name and HP in HUD")
		run.turns.submit("attack", Vector2i.RIGHT)
		check(run.result.get("cleared", false) and run.turns.player.hp == 1, "Boss killing blow clears before enemy counterattack")
		check(run.turns.gold == 60 and run.result.gold_lost == 0, "Boss reward claimed before lossless clear")
		check(not run.ability_choice.visible and not run.turns.busy and run.turns.ended, "No ability choice or enemy phase after clear")
		check(not run.turns.submit("attack", Vector2i.RIGHT) and run.turns.gold == 60, "No duplicate boss reward")
		run.free()
	print("Boss tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
