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
	check(enemy.is_processing(), "Living visible enemy follows its rig")
	enemy.hide()
	check(not enemy.is_processing(), "Hidden enemy stops following its rig")
	enemy.show()
	check(enemy.is_processing(), "Showing living enemy resumes")
	enemy.hp = 0
	check(not enemy.is_processing(), "Dead ghost stops following its rig")
	enemy.visual_scale = Vector2(0.8, 0.2)
	check(enemy.visible and enemy.visual_scale == Vector2(0.8, 0.2), "Dead ghost remains drawable with death pose")
	enemy.queue_free()
	await process_frame
	test_visual_ids()
	await test_falls()
	print("Enemy visuals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_visual_ids() -> void:
	var basic := preload("res://data/enemies/basic_enemy.tres")
	check(EnemySprites.visual_id(basic) == "basic", "Plain vision enemy maps to the basic rig")
	check(EnemySprites.visual_id(preload("res://data/enemies/turret_enemy.tres")) == "turret", "Turret maps to its rig")
	check(EnemySprites.visual_id(preload("res://data/enemies/summoner_enemy.tres")) == "summoner", "Nest maps to its rig")
	var named_boss := EnemyStats.new()
	named_boss.is_boss = true
	named_boss.display_name = "遺跡王"
	check(EnemySprites.visual_id(named_boss) == "boss_ruin_king", "A named boss uses its own rig")
	named_boss.display_name = "名もなき試験の主"
	check(EnemySprites.visual_id(named_boss) == "boss", "A boss without its own rig falls back to the shared boss rig")
	for display_name: String in EnemySprites.BOSS_IDS:
		check(ResourceLoader.exists(EnemySprites.rig_path(EnemySprites.BOSS_IDS[display_name])), "%s has a rig" % display_name)


# A killing blow flinches the rig, then it falls and fades without being
# flattened.
func test_falls() -> void:
	var presentation := preload("res://combat/battle_presentation.gd").new()
	root.add_child(presentation)
	var hit := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(hit)
	check(hit.has_sprite(), "The enemy is drawn as its rig")
	hit.hp = 0
	presentation._pose(hit, Vector2(1.14, 0.85), 0.12, 0.05, true)
	await create_timer(0.12).timeout
	check(hit.visual_scale == Vector2.ONE, "Rig deaths fall instead of flattening the body")
	hit.queue_free()

	var fallen := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(fallen)
	fallen.hp = 0
	var hero := Node2D.new()
	root.add_child(hero)
	presentation._hit({"actor": fallen, "damage": 5, "dead": true, "origin": Vector2i(2, 2), "direction": Vector2i.RIGHT}, hero, 48)
	check(fallen.rig.animation_player.current_animation == CharacterRig.HURT, "A killing blow first shows the flinch")
	await create_timer(0.2).timeout
	check(fallen.rig.animation_player.current_animation == CharacterRig.DOWN and fallen.modulate.a > 0.9, "The fall is shown fully opaque before the fade")
	await create_timer(0.6).timeout
	check(not is_instance_valid(fallen), "The fallen enemy fades out and is freed")
	hero.queue_free()
	presentation.queue_free()
	await process_frame
