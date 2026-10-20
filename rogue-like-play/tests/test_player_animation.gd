extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func run_tests() -> void:
	var main := preload("res://game/main.gd").new()
	root.add_child(main)
	# The hero's own drawing (rig, step, swing) is test_player_rig.gd's; this
	# checks her motion in the real run.
	var player: Node2D
	var run = preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	# The fixed fixture has three enemy positions; random houses add more.
	run.dungeon_settings = run.dungeon_settings.duplicate()
	run.dungeon_settings.monster_house_chance = 0.0
	run.dungeon_settings.enemy_count = 3
	root.add_child(run)
	preload("res://tests/run_fixture.gd").arrange(run)
	# The game's own hero is the illustration rig.
	player = run.turns.player
	run._on_action("move", Vector2i.DOWN)
	# Read after the move: a turn shows another facing's rig.
	var motion: AnimationPlayer = player.rig.rig.animation_player
	check(motion.current_animation == CharacterRig.WALK and player.rig.facing_name == &"front" and player.cell == Vector2i(3, 4), "Successful game action starts walking")
	if run.presentation.playing:
		await run.presentation.finished
		await process_frame
	player.reset_step()
	run.dungeon.grid.walls[player.cell + Vector2i.LEFT] = true
	var turns_before: int = run.turns.turn_count
	run._on_action("move", Vector2i.LEFT)
	motion = player.rig.rig.animation_player
	check(player.rig.facing_name == &"left" and motion.current_animation != CharacterRig.WALK and run.turns.turn_count == turns_before, "Blocked movement turns without walking or spending a turn")
	player.aiming = true
	var event := InputEventAction.new()
	event.action = "move_n"
	event.pressed = true
	player._unhandled_input(event)
	check(player.rig.facing_name == &"back" and run.turns.turn_count == turns_before, "Aiming changes direction without movement")
	player.aiming = false
	run._on_action("switch", Vector2i.UP)
	check(player.weapon.kind == WeaponData.Kind.SPEAR, "Weapon switch remains available")
	player.play_step(Vector2i.UP, 48)
	run._load_floor()
	check(player.rig.rig.animation_player.current_animation == CharacterRig.IDLE and player.body.position == Vector2.ZERO, "Floor transition cancels an old step")
	player.play_step(Vector2i.UP, 48)
	run.finish_run(false)
	check(player.rig.rig.animation_player.current_animation == CharacterRig.IDLE and player.body.position == Vector2.ZERO, "Run completion cancels an old step")
	run.free()
	main.free()
	print("Player animation tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
