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
	await test_sprite_strips()
	test_standout()
	print("Enemy visuals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_sprite_strips() -> void:
	var basic := preload("res://data/enemies/basic_enemy.tres")
	check(EnemySprites.visual_id(basic) == "basic", "Plain vision enemy maps to the basic strip")
	check(EnemySprites.visual_id(preload("res://data/enemies/turret_enemy.tres")) == "turret", "Turret maps to its strip")
	check(EnemySprites.visual_id(preload("res://data/enemies/summoner_enemy.tres")) == "summoner", "Nest maps to its strip")
	var named_boss := EnemyStats.new()
	named_boss.is_boss = true
	named_boss.display_name = "遺跡王"
	check(EnemySprites.visual_id(named_boss) == ("boss_ruin_king" if ResourceLoader.exists("res://art/enemies/boss_ruin_king.png") else "boss"), "A named boss uses its own strip when it exists")
	named_boss.display_name = "名もなき試験の主"
	check(EnemySprites.visual_id(named_boss) == "boss", "A boss without its own strip falls back to the shared boss strip")
	var fallback := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(fallback)
	check(not fallback.has_sprite() or ResourceLoader.exists("res://art/enemies/basic.png"), "Enemies without generated art keep the drawn body")
	fallback.queue_free()

	var image := Image.create(64 * 8, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	EnemySprites.set_override("basic", ImageTexture.create_from_image(image))
	var enemy := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(enemy)
	check(enemy.has_sprite(), "An injected strip replaces the drawn body")
	check(enemy.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Sprite pixels stay crisp")
	check(enemy.sprite_frame() >= 0 and enemy.sprite_frame() < EnemySprites.IDLE_FRAMES, "Living enemy cycles idle frames")
	var seen: Dictionary = {}
	for step in 12:
		seen[enemy.sprite_frame()] = true
		await create_timer(0.05).timeout
	check(seen.size() > 1, "Idle frames advance over time")
	enemy.pose_frame = EnemySprites.FRAME_STRIKE
	check(enemy.sprite_frame() == EnemySprites.FRAME_STRIKE, "Presentation holds the strike frame")
	enemy.pose_frame = -1
	enemy.shot_direction = Vector2i.RIGHT
	check(enemy.sprite_frame() == EnemySprites.FRAME_WIND_UP, "A warned shot or charge holds the wind-up frame")
	enemy.shot_direction = Vector2i.ZERO
	check(enemy.sprite_frame() < EnemySprites.IDLE_FRAMES, "Clearing the warning returns to idle")
	enemy.hp = 0
	check(enemy.sprite_frame() == EnemySprites.FRAME_DOWN, "Defeated enemy rests on its down frame")
	enemy.pose_frame = EnemySprites.FRAME_HURT
	check(enemy.sprite_frame() == EnemySprites.FRAME_HURT, "The flinch plays before the down frame")
	enemy.queue_free()

	EnemySprites.set_override("summoner", ImageTexture.create_from_image(image))
	var nest := preload("res://actors/enemy/enemy.tscn").instantiate()
	nest.stats = preload("res://data/enemies/summoner_enemy.tres")
	root.add_child(nest)
	var grid := GridState.new()
	grid.size = Vector2i(8, 8)
	# A living target; the nest only counts turns and never reaches it.
	var target := preload("res://actors/enemy/enemy.tscn").instantiate()
	target.hp = 5
	var nest_frames: Array[int] = []
	var hatched_on: Array[int] = []
	for turn in nest.stats.summon_interval + 1:
		nest.take_turn(grid, target)
		nest_frames.append(nest.sprite_frame())
		if nest.summon_due:
			hatched_on.append(turn)
	check(hatched_on.size() == 1, "The nest hatches once per interval")
	var hatch: int = hatched_on[0] if not hatched_on.is_empty() else -1
	check(hatch > 0 and nest_frames[hatch - 1] == EnemySprites.FRAME_WIND_UP, "The turn before hatching shows the swollen wind-up")
	check(hatch >= 0 and nest_frames[hatch] == EnemySprites.FRAME_STRIKE, "The hatching turn shows the burst egg")
	check(nest_frames[0] < EnemySprites.IDLE_FRAMES, "Between hatchings the nest idles")
	EnemySprites.set_override("summoner", null)
	target.free()
	nest.queue_free()

	var short_image := Image.create(64 * 4, 64, false, Image.FORMAT_RGBA8)
	EnemySprites.set_override("basic", ImageTexture.create_from_image(short_image))
	var idle_only := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(idle_only)
	idle_only.pose_frame = EnemySprites.FRAME_STRIKE
	check(idle_only.sprite_frame() == 0, "Idle-only strips fall back to the first frame for missing poses")
	idle_only.queue_free()

	var presentation := preload("res://combat/battle_presentation.gd").new()
	root.add_child(presentation)
	var hit := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(hit)
	EnemySprites.set_override("basic", ImageTexture.create_from_image(image))
	hit.hp = 0
	presentation._pose(hit, Vector2(1.14, 0.85), 0.12, 0.05, true)
	await create_timer(0.12).timeout
	check(hit.visual_scale == Vector2.ONE, "Sprite deaths use the down frame instead of flattening the body")
	hit.queue_free()

	var fallen := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(fallen)
	fallen.hp = 0
	var hero := Node2D.new()
	root.add_child(hero)
	presentation._hit({"actor": fallen, "damage": 5, "dead": true, "origin": Vector2i(2, 2), "direction": Vector2i.RIGHT}, hero, 48)
	check(fallen.sprite_frame() == EnemySprites.FRAME_HURT, "A killing blow first shows the flinch")
	await create_timer(0.2).timeout
	check(fallen.sprite_frame() == EnemySprites.FRAME_DOWN and fallen.modulate.a > 0.9, "The down frame is shown fully opaque before the fade")
	await create_timer(0.6).timeout
	check(not is_instance_valid(fallen), "The fallen enemy fades out and is freed")
	EnemySprites.set_override("basic", null)
	hero.queue_free()
	presentation.queue_free()
	await process_frame


func test_standout() -> void:
	var king := EnemyStats.new()
	king.is_boss = true
	king.display_name = "古樹の王"
	var stone := EnemyStats.new()
	stone.is_boss = true
	stone.display_name = "石門の守護者"
	check(EnemySprites.stands_out(king) == (EnemySprites.sheet("boss_ancient_tree_king") != null), "The Ancient Tree King stands out from the moss floor")
	check(not EnemySprites.stands_out(stone), "Other bosses keep the plain shadow")
	var sheet := EnemySprites.sheet("boss_ancient_tree_king")
	if sheet != null:
		check(EnemySprites.foot_width(sheet) > 40, "The standout shadow follows the boss's footprint")
