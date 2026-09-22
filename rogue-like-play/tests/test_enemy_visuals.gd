extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run_tests() -> void:
	var enemy := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(enemy)
	enemy.cell = Vector2i(3, 4)
	enemy.position = Vector2(100, 120)
	var initial_hp: int = enemy.hp
	var initial_scale: Vector2 = enemy.scale
	enemy.visual_scale = Vector2(1.15, 0.8)
	enemy.visual_rotation = 0.15
	enemy.visual_offset = Vector2(2, -3)
	check(enemy.cell == Vector2i(3, 4) and enemy.position == Vector2(100, 120), "Presentation poses preserve logical location")
	check(enemy.hp == initial_hp and enemy.scale == initial_scale, "Presentation poses preserve health and actor transform")
	await create_timer(0.04).timeout
	check(enemy._idle_time > 0.0 and enemy.is_processing(), "Living visible enemy animates idle")
	enemy.hide()
	var hidden_time: float = enemy._idle_time
	await create_timer(0.04).timeout
	check(not enemy.is_processing() and enemy._idle_time == hidden_time, "Hidden enemy suspends idle")
	enemy.show()
	check(enemy.is_processing(), "Showing living enemy resumes idle")
	enemy.hp = 0
	var dead_time: float = enemy._idle_time
	await create_timer(0.04).timeout
	check(not enemy.is_processing() and enemy._idle_time == dead_time, "Dead ghost remains idle-free")
	enemy.visual_scale = Vector2(0.8, 0.2)
	check(enemy.visible and enemy.visual_scale == Vector2(0.8, 0.2), "Dead ghost remains drawable with death pose")
	enemy.queue_free()
	await process_frame
	print("Enemy visuals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
