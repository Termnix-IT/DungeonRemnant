extends SceneTree

# The boss hall drawn for real at 1600x900: the ruin king come in with its
# gauge, winding up its quake and its charge, and its second phase with its
# summons arriving. Images go to .godot/boss_*.png. Needs a rendering
# display driver:
#   godot --path . --log-file .godot/boss-capture.log --script res://tests/capture_boss.gd

var shots := {}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	var area := BattleArea.new()
	area.setup(load("res://data/areas/guardian_hall.tres"), RunState.new(9), 9)
	root.add_child(area)
	await process_frame
	area.hero.controlled = false
	area.hero.health.max_hp = 100000
	area.hero.health.hp = 100000
	await create_timer(BattleArea.BOSS_DELAY + BattleArea.BOSS_MARK_TIME + 0.4).timeout
	var boss := area.boss_foe
	boss.set_physics_process(false)
	boss.global_position = area.hero.global_position + Vector2(0, -150)
	boss.begin_attack(boss.data.attacks[2], area.hero.global_position - boss.global_position)
	for frame in 30:
		await physics_frame
		boss.step(1.0 / 60.0)
	await _grab("boss_quake")
	boss._cancel_attack()
	boss.global_position = area.hero.global_position + Vector2(-380, -120)
	boss.begin_attack(boss.data.attacks[1], area.hero.global_position - boss.global_position)
	for frame in 30:
		await physics_frame
		boss.step(1.0 / 60.0)
	await _grab("boss_charge")
	boss._cancel_attack()
	boss.set_physics_process(true)
	boss.receive(DamageInfo.make(boss.data.max_hp * 0.55, Vector2.UP))
	await create_timer(0.4).timeout
	await _grab("boss_phase_two")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the boss: ", ", ".join(shots.keys()))
	area.hit_stop.release()
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
