extends SceneTree

var failures := 0
var checks := 0


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
	run.final_floor = 20
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	run.dungeon_settings.reinforcement_total_cap = 0
	root.add_child(run)
	run.dungeon.grid.walls.clear()
	run.dungeon.grid.pillars.clear()
	run.dungeon.grid.occupants.clear()
	run.dungeon.grid.place(run.turns.player, Vector2i(2, 2))
	run.dungeon.stairs_cell = Vector2i(3, 2)
	return run


func run_tests() -> void:
	var run := make_run()
	run.turns.floor_turn_count = 4999
	run.turns.submit("move", Vector2i.RIGHT)
	check(run.floor_number == 1 and run.turns.paused and run.result.is_empty(), "Stair confirmation precedes timeout")
	check(not run.turns.submit("attack", Vector2i.RIGHT), "Confirmation blocks actions")
	run.resolve_transition(true)
	check(run.floor_number == 2 and run.turns.floor_turn_count == 0 and run.result.is_empty(), "Confirmed descent resets deadline")
	run.free()
	run = make_run()
	run.turns.submit("move", Vector2i.RIGHT)
	var count: int = run.turns.turn_count
	run.resolve_transition(false)
	check(run.floor_number == 1 and run.turns.turn_count == count, "Cancel is free")
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.transition_kind.is_empty(), "No repeated prompt while standing on stairs")
	run.turns.submit("move", Vector2i.LEFT)
	run.turns.submit("move", Vector2i.RIGHT)
	check(run.transition_kind == "stairs", "Reentering stairs prompts again")
	run.turns.floor_turn_count = 5000
	run.resolve_transition(false)
	check(run.result.get("forced_return", false), "Declining descent at deadline forces return")
	run.free()
	run = make_run()
	for remaining in [1500, 1000, 500, 100]:
		run.turns.floor_turn_count = 5000 - remaining - 1
		run.turns.submit("attack", Vector2i.RIGHT)
		check(run.turns.last_message.contains(str(remaining)), "Warning at %d remaining" % remaining)
	run.turns.floor_turn_count = 4999
	run.turns.player.inventory.add(preload("res://data/items/healing_potion.tres"), 10)
	run.turns.gold = 101
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.result.get("forced_return", false) and run.turns.gold == 51 and run.turns.player.inventory.entries.is_empty(), "Timeout applies whole-slot loss and half gold")
	check(run.turns.player.equipment.slots[0] != null, "Equipped weapon protected")
	run.free()
	run = make_run()
	run.floor_number = 10
	run._load_floor()
	var boss: Node2D = run.turns.enemies.back()
	run.dungeon.grid.walls.clear()
	run.dungeon.grid.pillars.clear()
	run.dungeon.grid.occupants.clear()
	run.dungeon.grid.place(run.turns.player, Vector2i(2, 2))
	run.dungeon.grid.place(boss, Vector2i(3, 2))
	boss.hp = 1
	run.turns.floor_turn_count = 4999
	run.turns.submit("attack", Vector2i.RIGHT)
	while not run.turns.offered_abilities.is_empty():
		run.turns.choose_ability(run.turns.offered_abilities[0].id)
	check(run.result.is_empty() and run.floor_limit == 5150 and run.exit_cell == run.dungeon.start_cell, "Boss at deadline grants grace and creates exit")
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.floor_limit == 5150, "Grace is awarded once")
	run.dungeon.grid.place(run.turns.player, run.exit_cell)
	run.turns.moved_this_turn = true
	run.turns.floor_turn_count = 5150
	run._on_turn_finished()
	check(run.transition_kind == "exit", "Exit available on final grace turn")
	run.resolve_transition(true)
	check(run.result.get("safe_return", false) and not run.result.cleared and run.result.gold_lost == 0, "Safe exit precedes timeout without claiming dungeon clear")
	run.free()
	print("Floor limit tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
