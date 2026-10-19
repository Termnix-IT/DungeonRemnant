extends SceneTree

# Every enemy drawn as its rig, on the slate floor at the dungeon camera's
# 1.5 zoom: a row each of the idle, the blow of an attack (0.09 s in), a
# flinch and the fall, the bosses at their size. Written to
# .godot/enemy_lineup_regular.png and _bosses.png, and _settled versions
# 0.6 s later (the fall's end).

const ENEMY := preload("res://actors/enemy/enemy.tscn")
const BOSS := preload("res://data/enemies/boss.tres")
const TERRAIN := preload("res://art/tiles/painted/slate_terrain.png")
const REGULAR := ["basic_enemy", "proximity_enemy", "fast_enemy", "charge_enemy", "summoner_enemy", "turret_enemy"]
const ZOOM := 1.5


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	var main := load("res://game/main.gd").new() as Node
	root.add_child(main)
	var world := Node2D.new()
	world.scale = Vector2.ONE * ZOOM
	root.add_child(world)
	var floor_layer := Node2D.new()
	floor_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_layer.draw.connect(func():
		for y in 13:
			for x in 23:
				var index := 21 + (y % 4) * 4 + x % 4
				floor_layer.draw_texture_rect_region(TERRAIN, Rect2(Vector2(x, y) * 48, Vector2.ONE * 48), Rect2((index % 16) * 96, (index / 16) * 96, 96, 96)))
	world.add_child(floor_layer)
	var all: Array[EnemyStats] = []
	for path: String in REGULAR:
		all.append((load("res://data/enemies/%s.tres" % path) as EnemyStats).duplicate())
	for display_name: String in EnemySprites.BOSS_IDS:
		var stats: EnemyStats = BOSS.duplicate()
		stats.display_name = display_name
		all.append(stats)
	# The regular enemies and the bosses are shot apart, each as four rows:
	# the idle, the blow of an attack (0.09 s in), a flinch, the fall.
	var result := OK
	for group in 2:
		var stats_list: Array[EnemyStats] = all.slice(0, REGULAR.size()) if group == 0 else all.slice(REGULAR.size())
		var spacing := Vector2(170, 180) if group == 0 else Vector2(150, 205)
		var rows: Array = [[], [], [], []]
		for row in 4:
			for index in stats_list.size():
				var enemy: Node2D = ENEMY.instantiate()
				enemy.stats = stats_list[index]
				enemy.facing = Vector2i.RIGHT
				world.add_child(enemy)
				enemy.position = (Vector2(110, 150 if group == 0 else 170) + Vector2(index, row) * spacing) / ZOOM
				rows[row].append(enemy)
		await create_timer(1.0).timeout
		for enemy: Node2D in rows[1]:
			enemy.play_attack(null)
		for enemy: Node2D in rows[2]:
			enemy.pose_frame = EnemySprites.FRAME_HURT
		for enemy: Node2D in rows[3]:
			enemy.hp = 0
			enemy.pose_frame = -1
		await create_timer(0.09).timeout
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var name := "regular" if group == 0 else "bosses"
		result |= shot.save_png("res://.godot/enemy_lineup_%s.png" % name)
		result |= root.get_texture().get_image().save_png("res://.godot/enemy_lineup_%s_settled.png" % name)
		for row: Array in rows:
			for enemy: Node2D in row:
				enemy.free()
	print("Captured the enemy lineup.")
	quit(0 if result == OK else 1)
