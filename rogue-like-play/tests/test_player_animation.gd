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
	var player = preload("res://actors/player/player.tscn").instantiate()
	root.add_child(player)
	var sprite: AnimatedSprite2D = player.sprite
	var directions := [Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i.UP,
		Vector2i(1, -1), Vector2i(-1, -1), Vector2i.LEFT, Vector2i.RIGHT]
	var names := ["front", "front", "front", "back", "back", "back", "left", "right"]
	for index in directions.size():
		player.facing = directions[index]
		check(sprite.animation == StringName("idle_%s" % names[index]), "Eight-way facing %s" % directions[index])
		check(player.weapon_visual.show_behind_parent == (directions[index].y < 0), "Weapon depth follows facing")
	player.facing = Vector2i.RIGHT
	var seen: Dictionary = {}
	sprite.frame_changed.connect(func():
		if sprite.animation == &"walk_right":
			seen[sprite.frame] = true
	)
	player.play_step(Vector2i.RIGHT, 48)
	seen[sprite.frame] = true
	check(player.position == Vector2.ZERO, "Visual step never moves the logical actor")
	check(player.weapon_visual.global_position.is_equal_approx(Vector2(-8, 0)), "Weapon follows initial visual step")
	check(player.foot_marker.global_position.is_equal_approx(Vector2(-8, 26)), "Foot marker follows initial visual step")
	player.move_tween.pause()
	player.move_tween.custom_step(0.05)
	check(sprite.position.x > -8 and sprite.position.x < 0, "Step interpolates toward destination")
	check(player.foot_marker.global_position.is_equal_approx(sprite.position + Vector2(0, 29)), "Foot marker remains attached during tween")
	check(player.weapon_visual.global_position.is_equal_approx(sprite.position + Vector2(0, 3)), "Weapon remains attached during tween")
	player.move_tween.play()
	await create_timer(0.16).timeout
	check(sprite.position.is_equal_approx(player.BASE_SPRITE_POSITION), "Position settles in 0.12 seconds")
	check(sprite.animation == &"walk_right", "Walk continues after position settles")
	await create_timer(0.30).timeout
	check(seen.size() == 4, "Single step displays all four walk frames")
	check(sprite.animation == &"idle_right", "Single step returns to idle")
	check(player.foot_marker.global_position.is_equal_approx(Vector2(0, 26)), "Foot marker settles under feet")
	var idle_frame := sprite.frame
	await create_timer(0.55).timeout
	check(sprite.frame != idle_frame, "Idle animation advances while stationary")
	player.play_step(Vector2i.RIGHT, 48)
	await create_timer(0.15).timeout
	var walk_frame := sprite.frame
	player.facing = Vector2i.LEFT
	check(sprite.animation == &"walk_left" and sprite.frame == walk_frame, "Direction change preserves walking phase")
	player.play_step(Vector2i.LEFT, 48)
	await create_timer(0.28).timeout
	check(sprite.animation == &"walk_left", "Replaced tween cannot stop a later step")
	player.reset_step()
	check(sprite.animation == &"idle_left" and sprite.position == player.BASE_SPRITE_POSITION, "Reset clears movement immediately")
	player.facing = Vector2i(1, -1)
	player.play_step(player.facing, 48)
	check(is_equal_approx((sprite.position - player.BASE_SPRITE_POSITION).length(), 8.0), "Diagonal step has the same visual distance as cardinal steps")
	player.facing = Vector2i.LEFT
	player.reset_step()
	player.hp = 0
	player.play_step(Vector2i.LEFT, 48)
	check(sprite.animation == &"idle_left", "Dead player cannot start walking")
	player.free()
	var run = preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	root.add_child(run)
	preload("res://tests/run_fixture.gd").arrange(run)
	player = run.turns.player
	sprite = player.sprite
	run._on_action("move", Vector2i.DOWN)
	check(sprite.animation == &"walk_front" and player.cell == Vector2i(3, 4), "Successful game action starts walking")
	if run.presentation.playing:
		await run.presentation.finished
		await process_frame
	player.reset_step()
	run.dungeon.grid.walls[player.cell + Vector2i.LEFT] = true
	var turns_before: int = run.turns.turn_count
	run._on_action("move", Vector2i.LEFT)
	check(sprite.animation == &"idle_left" and run.turns.turn_count == turns_before, "Blocked movement turns without walking or spending a turn")
	player.aiming = true
	var event := InputEventAction.new()
	event.action = "move_n"
	event.pressed = true
	player._unhandled_input(event)
	check(sprite.animation == &"idle_back" and run.turns.turn_count == turns_before, "Aiming changes direction without movement")
	player.aiming = false
	run._on_action("switch", Vector2i.UP)
	check(player.weapon.kind == WeaponData.Kind.SPEAR, "Weapon switch remains available")
	player.play_step(Vector2i.UP, 48)
	run._load_floor()
	check(sprite.animation == &"idle_back" and sprite.position == player.BASE_SPRITE_POSITION, "Floor transition cancels an old step")
	player.play_step(Vector2i.UP, 48)
	run.finish_run(false)
	check(sprite.animation == &"idle_back" and sprite.position == player.BASE_SPRITE_POSITION, "Run completion cancels an old step")
	run.free()
	main.free()
	print("Player animation tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
