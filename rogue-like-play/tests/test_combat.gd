extends SceneTree

const PLAYER := preload("res://actors/player/player.tscn")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const SWORD := preload("res://data/weapons/sword.tres")
const SPEAR := preload("res://data/weapons/spear.tres")
const HAMMER := preload("res://data/weapons/hammer.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func press(player: Node2D, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	player._unhandled_input(event)


func run_tests() -> void:
	var grid := GridState.new()
	grid.size = Vector2i(8, 8)
	var player := PLAYER.instantiate()
	var enemy := ENEMY.instantiate()
	var second := ENEMY.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	root.add_child(second)
	grid.place(player, Vector2i(2, 2))
	for direction: Vector2i in player.DIRECTIONS.values():
		grid.occupants.clear()
		grid.place(player, Vector2i(2, 2))
		grid.place(enemy, player.cell + direction * 2)
		enemy.hp = 8
		var cells := CombatRules.attack_cells(grid, player.cell, direction, SPEAR)
		check(cells.size() == 2 and cells.back() == enemy.cell, "Spear preview in eight directions")
		check(CombatRules.attack(grid, player, direction, SPEAR) == 4 and enemy.hp == 4, "Spear preview matches hit")
	grid.occupants.clear()
	grid.place(player, Vector2i(2, 2))
	grid.place(enemy, Vector2i(3, 2))
	grid.place(second, Vector2i(4, 2))
	enemy.hp = 8
	second.hp = 8
	check(CombatRules.attack_cells(grid, player.cell, Vector2i.RIGHT, SPEAR).size() == 1, "Spear stops at first enemy")
	CombatRules.attack(grid, player, Vector2i.RIGHT, SPEAR)
	check(second.hp == 8, "Spear does not pierce")
	grid.remove_actor(enemy)
	check(CombatRules.attack(grid, player, Vector2i.RIGHT, player.weapon) == 0, "Sword cannot reach two cells")
	grid.walls[Vector2i(3, 2)] = true
	check(CombatRules.attack_cells(grid, player.cell, Vector2i.RIGHT, SPEAR).is_empty(), "Wall blocks spear preview")
	check(CombatRules.attack(grid, player, Vector2i.RIGHT, SPEAR) == 0, "Wall blocks spear hit")
	grid.walls.clear()
	grid.walls[Vector2i(4, 3)] = true
	check(CombatRules.attack_cells(grid, player.cell, Vector2i(1, 1), SPEAR).size() == 1, "Second diagonal corner blocks spear")
	grid.walls.clear()
	grid.remove_actor(second)
	grid.remove_actor(enemy)
	grid.place(enemy, Vector2i(3, 2))
	grid.place(second, Vector2i(3, 1))
	enemy.hp = 8
	second.hp = 8
	check(CombatRules.attack_cells(grid, player.cell, Vector2i.RIGHT, SWORD) == [Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 3)], "Sword preview sweeps the three forward directions")
	check(CombatRules.attack(grid, player, Vector2i.RIGHT, SWORD) == 8 and enemy.hp == 4 and second.hp == 4, "Sword sweep damages multiple adjacent enemies once")
	grid.remove_actor(second)
	grid.remove_actor(enemy)
	grid.place(enemy, Vector2i(3, 2))
	enemy.hp = 8
	CombatRules.attack(grid, player, Vector2i.RIGHT, HAMMER)
	check(enemy.cell == Vector2i(5, 2) and enemy.hp == 4, "Hammer pushes a surviving enemy two cells")
	check(not grid.occupants.has(Vector2i(3, 2)), "Knockback releases old cell")
	grid.remove_actor(enemy)
	grid.place(enemy, Vector2i(3, 2))
	grid.place(second, Vector2i(4, 2))
	enemy.hp = 8
	second.hp = 8
	CombatRules.attack(grid, player, Vector2i.RIGHT, HAMMER)
	check(enemy.cell == Vector2i(3, 2) and enemy.hp == 4 and second.hp == 8, "Occupied push has no bonus damage")
	grid.remove_actor(second)
	grid.walls[Vector2i(5, 2)] = true
	enemy.hp = 8
	CombatRules.attack(grid, player, Vector2i.RIGHT, HAMMER)
	check(enemy.cell == Vector2i(4, 2) and enemy.hp == 4, "Hammer uses the available part of its knockback distance")
	grid.walls.clear()
	grid.remove_actor(enemy)
	grid.place(enemy, Vector2i(3, 2))
	grid.size = Vector2i(4, 4)
	enemy.hp = 8
	CombatRules.attack(grid, player, Vector2i.RIGHT, HAMMER)
	check(enemy.cell == Vector2i(3, 2), "Boundary blocks knockback")
	grid.size = Vector2i(8, 8)
	enemy.hp = 4
	CombatRules.attack(grid, player, Vector2i.RIGHT, HAMMER)
	check(enemy.hp == 0 and enemy.cell == Vector2i(3, 2) and not grid.occupants.has(enemy.cell), "Dead enemy is not pushed")
	grid.place(enemy, Vector2i(3, 3))
	enemy.hp = 8
	grid.walls[Vector2i(4, 3)] = true
	CombatRules.attack(grid, player, Vector2i(1, 1), HAMMER)
	check(enemy.hp == 4 and enemy.cell == Vector2i(3, 3), "Corner blocks diagonal knockback")
	player.free()
	enemy.free()
	second.free()
	var main := (load("res://game/main.tscn") as PackedScene).instantiate()
	main.saving_enabled = false
	root.add_child(main)
	main.start_run()
	var run = main.get_node("Run")
	preload("res://tests/run_fixture.gd").arrange(run)
	var hero: Node2D = run.turns.player
	var original: Vector2i = hero.cell
	var enemy_original: Vector2i = run.turns.enemies[0].cell
	press(hero, "attack")
	check(hero.aiming and run.preview.visible and run.turns.turn_count == 0, "Attack mode costs no turn")
	press(hero, "move_s")
	check(hero.cell == original and hero.facing == Vector2i.DOWN, "Direction selection does not move")
	check(run.turns.enemies[0].cell == enemy_original and run.turns.turn_count == 0, "Enemies wait while aiming")
	check(run.preview.cells == CombatRules.attack_cells(run.dungeon.grid, hero.cell, hero.facing, hero.weapon), "Displayed cells use combat result")
	press(hero, "cancel_attack")
	check(not hero.aiming and not run.preview.visible and run.turns.turn_count == 0, "Cancel costs no turn and clears preview")
	press(hero, "attack")
	press(hero, "attack")
	check(not hero.aiming and not run.preview.visible and run.turns.turn_count == 1, "Confirm consumes exactly one turn")
	check(run.turns.enemies[0].cell != enemy_original, "Enemy acts after confirm")
	main.free()
	print("Combat tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
