extends SceneTree

const RUN := preload("res://game/run/run.tscn")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const POTION := preload("res://data/items/healing_potion.tres")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func new_run() -> Node2D:
	var run := RUN.instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	root.add_child(run)
	var grid: GridState = run.dungeon.grid
	grid.size = Vector2i(24, 24)
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	run.dungeon.ground_items.clear()
	run.dungeon.has_stairs = false
	grid.place(run.turns.player, Vector2i(2, 2))
	run._refresh()
	return run


func hold(action: StringName) -> void:
	Input.action_press(action)


func release(action: StringName) -> void:
	Input.action_release(action)


func test_repeat_and_release() -> void:
	var run := new_run()
	hold(&"move_e")
	run._on_action("move", Vector2i.RIGHT)
	check(run.rapid_move.armed and run.turns.player.cell == Vector2i(3, 2) and run.turns.turn_count == 1, "Held safe move arms acceleration after one normal turn")
	run.rapid_move._on_timeout()
	check(run.turns.player.cell == Vector2i(4, 2) and run.turns.turn_count == 2, "Accelerated step uses one ordinary turn")
	release(&"move_e")
	run.rapid_move._process(0.0)
	check(not run.rapid_move.armed and run.turns.player.cell == Vector2i(4, 2), "Releasing input stops acceleration")
	run.free()


func test_stop_before_unknown_and_item() -> void:
	var run := new_run()
	var player: Node2D = run.turns.player
	player.vision_range = 0
	run.dungeon.fog.reset()
	run.dungeon.fog.explored[Vector2i(2, 2)] = true
	run.dungeon.fog.explored[Vector2i(3, 2)] = true
	hold(&"move_e")
	run._on_action("move", Vector2i.RIGHT)
	check(run.rapid_move.armed, "Explored first step may arm acceleration")
	run.rapid_move._on_timeout()
	check(not run.rapid_move.armed and player.cell == Vector2i(3, 2) and run.turns.turn_count == 1, "Acceleration stops before unexplored cell without spending a turn")
	release(&"move_e")
	player.vision_range = 8
	run._refresh()
	hold(&"move_e")
	run._on_action("move", Vector2i.RIGHT)
	check(run.rapid_move.armed, "Fresh movement input rearms after a safety stop")
	run.dungeon.ground_items[Vector2i(5, 2)] = InventoryEntry.new(POTION)
	run.rapid_move._on_timeout()
	check(not run.rapid_move.armed and player.cell == Vector2i(4, 2), "Acceleration stops before a known ground item")
	release(&"move_e")
	run.free()


func test_enemy_and_branch_stops() -> void:
	var run := new_run()
	var player: Node2D = run.turns.player
	player.vision_range = 1
	var enemy := ENEMY.instantiate()
	run.dungeon.get_node("Actors").add_child(enemy)
	run.dungeon.grid.place(enemy, Vector2i(4, 2))
	run.turns.enemies.append(enemy)
	run.dungeon.fog.explored[Vector2i(3, 2)] = true
	hold(&"move_e")
	run._on_action("move", Vector2i.RIGHT)
	check(not run.rapid_move.armed and run.turns.turn_count == 1, "Enemy entering vision prevents acceleration while preserving the combat turn")
	release(&"move_e")
	run.free()

	run = new_run()
	var grid: GridState = run.dungeon.grid
	for y in grid.size.y:
		for x in grid.size.x:
			grid.walls[Vector2i(x, y)] = true
	for cell: Vector2i in [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 2), Vector2i(3, 4)]:
		grid.walls.erase(cell)
	check(run._entered_branch(Vector2i(2, 3), Vector2i(3, 3), Vector2i.RIGHT), "T junction is detected as a rapid-move stop")
	grid.walls[Vector2i(3, 2)] = true
	grid.walls[Vector2i(3, 4)] = true
	check(not run._entered_branch(Vector2i(2, 3), Vector2i(3, 3), Vector2i.RIGHT), "Straight corridor remains eligible for acceleration")
	run.free()


func test_stairs_and_ui_stops() -> void:
	var run := new_run()
	var player: Node2D = run.turns.player
	player.vision_range = 1
	run.dungeon.has_stairs = true
	run.dungeon.stairs_cell = Vector2i(4, 2)
	run.dungeon.fog.reset()
	run.dungeon.fog.explored[Vector2i(2, 2)] = true
	run.dungeon.fog.explored[Vector2i(3, 2)] = true
	hold(&"move_e")
	run._on_action("move", Vector2i.RIGHT)
	check(run.stairs_discovered and not run.rapid_move.armed, "Discovering stairs after a move prevents acceleration")
	release(&"move_e")
	run.free()

	run = new_run()
	player = run.turns.player
	run.dungeon.has_stairs = true
	run.dungeon.stairs_cell = Vector2i(4, 2)
	run._refresh()
	hold(&"move_e")
	run._on_action("move", Vector2i.RIGHT)
	check(run.rapid_move.armed, "Fresh input may accelerate toward already discovered stairs")
	run.rapid_move._on_timeout()
	check(not run.rapid_move.armed and player.cell == Vector2i(3, 2), "Acceleration stops before entering stairs")
	release(&"move_e")
	hold(&"move_w")
	run._on_action("move", Vector2i.LEFT)
	check(run.rapid_move.armed, "Safe movement rearms before a UI action")
	var inventory_event := InputEventAction.new()
	inventory_event.action = "inventory"
	inventory_event.pressed = true
	run._input(inventory_event)
	check(run.inventory_panel.visible and not run.rapid_move.armed, "Opening Inventory immediately stops acceleration")
	release(&"move_w")
	run.free()


func run_tests() -> void:
	root.add_child(load("res://game/main.gd").new())
	test_repeat_and_release()
	test_stop_before_unknown_and_item()
	test_enemy_and_branch_stops()
	test_stairs_and_ui_stops()
	print("Rapid move tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
