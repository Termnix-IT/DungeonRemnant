extends SceneTree

const PLAYER := preload("res://actors/player/player.tscn")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const TURNS := preload("res://game/run/turn_manager.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func run_tests() -> void:
	var grid := GridState.new()
	grid.size = Vector2i(8, 8)
	check(not grid.is_floor(Vector2i(-1, 0)), "Out of bounds")
	check(not grid.is_floor(Vector2i(8, 0)), "Right boundary")
	for direction: Vector2i in [Vector2i.UP, Vector2i(1, -1), Vector2i.RIGHT, Vector2i(1, 1), Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1)]:
		check(grid.can_step(Vector2i(3, 3), Vector2i(3, 3) + direction), "Eight-direction movement")
	grid.walls[Vector2i(2, 1)] = true
	check(not grid.can_step(Vector2i(1, 1), Vector2i(2, 2)), "Single wall blocks diagonal")
	check(not grid.can_step(Vector2i(1, 1), Vector2i(2, 1)), "Wall blocks movement")
	check(not grid.can_step(Vector2i(1, 1), Vector2i(3, 1)), "Cannot skip cells")
	grid.walls.clear()
	var player := PLAYER.instantiate()
	var enemy := ENEMY.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	check(grid.place(player, Vector2i(1, 1)), "Place player")
	check(grid.place(enemy, Vector2i(2, 1)), "Place enemy")
	check(not grid.move_actor(player, enemy.cell), "Occupied destination rejected")
	grid.walls[Vector2i(2, 0)] = true
	check(CombatRules.attack(grid, player, Vector2i(1, -1)) == 0, "Attack cannot hit wall")
	grid.walls.clear()
	var turns := TURNS.new()
	root.add_child(turns)
	turns.grid = grid
	turns.player = player
	turns.enemies.append(enemy)
	turns.busy = true
	check(not turns.submit("attack", Vector2i.RIGHT), "Busy state rejects input")
	turns.busy = false
	check(not turns.submit("move", Vector2i.RIGHT), "Blocked action rejected")
	check(turns.turn_count == 0 and player.hp == 24, "Blocked move costs no turn")
	check(turns.submit("attack", Vector2i.LEFT), "Miss accepted")
	check(turns.turn_count == 1 and player.hp == 21, "Miss consumes turn and enemy attacks once")
	enemy.hp = 4
	check(turns.submit("attack", Vector2i.RIGHT), "Killing attack accepted")
	check(enemy.hp == 0 and player.hp == 21, "Killed enemy does not act")
	check(not grid.occupants.has(Vector2i(2, 1)), "Death frees cell")
	check(turns.submit("move", Vector2i.RIGHT), "Can enter defeated enemy cell")
	check(player.cell == Vector2i(2, 1), "Logical position updated")
	check(not grid.occupants.has(Vector2i(1, 1)), "Old position released")
	# Restore the enemy to verify player death and state guards.
	enemy.hp = 8
	grid.place(enemy, Vector2i(3, 1))
	player.hp = 3
	turns.submit("attack", Vector2i.LEFT)
	check(turns.ended and player.hp == 0 and not player.input_enabled, "Player death ends run")
	var count: int = turns.turn_count
	check(not turns.submit("attack", Vector2i.RIGHT) and turns.turn_count == count, "No actions after death")
	check(player.stats.max_hp == 24 and enemy.stats.max_hp == 8, "Definition resources stay unchanged")
	player.free()
	enemy.free()
	turns.free()
	# Scene integration: enemy turns, fresh start, and clean occupancy.
	var run_scene := load("res://game/run/run.tscn") as PackedScene
	var run_instance := run_scene.instantiate()
	root.add_child(run_instance)
	preload("res://tests/run_fixture.gd").arrange(run_instance)
	check(run_instance.turns.enemies.size() == 3, "Run spawns three enemies")
	var before: Vector2i = run_instance.turns.enemies[0].cell
	run_instance.turns.submit("move", Vector2i.DOWN)
	check(run_instance.turns.enemies[0].cell != before, "Enemy approaches on a player move")
	check(run_instance.dungeon.grid.occupants.size() == 4, "Actors remain distinct")
	run_instance.free()
	run_instance = run_scene.instantiate()
	root.add_child(run_instance)
	preload("res://tests/run_fixture.gd").arrange(run_instance)
	check(run_instance.turns.turn_count == 0 and run_instance.turns.player.hp == 24, "Restart resets run")
	# A lethal move must leave the displayed player at the new logical cell.
	run_instance.turns.player.hp = 1
	var lethal_enemy: Node2D = run_instance.turns.enemies[0]
	run_instance.dungeon.grid.remove_actor(lethal_enemy)
	run_instance.dungeon.grid.place(lethal_enemy, Vector2i(4, 4))
	run_instance.turns.submit("move", Vector2i.DOWN)
	check(run_instance.turns.player.hp == 0, "Lethal enemy attack after movement")
	check(run_instance.turns.player.position == Vector2(112, 144), "Death display matches final cell")
	run_instance.free()
	print("Core tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
