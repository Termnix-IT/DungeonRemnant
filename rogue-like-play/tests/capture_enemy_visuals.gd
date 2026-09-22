extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1000, 500)
	root.content_scale_size = Vector2i(1000, 500)
	RenderingServer.set_default_clear_color(Color("202a31"))
	var resources := ["basic_enemy", "proximity_enemy", "fast_enemy", "charge_enemy", "summoner_enemy", "turret_enemy", "boss"]
	var row_names := ["Idle", "Attack pose", "Hit pose", "Death pose"]
	for row in 4:
		var row_label := Label.new()
		row_label.text = row_names[row]
		row_label.position = Vector2(10, 60 + row * 110)
		root.add_child(row_label)
		for index in resources.size():
			var enemy := preload("res://actors/enemy/enemy.tscn").instantiate()
			enemy.stats = load("res://data/enemies/%s.tres" % resources[index])
			enemy.position = Vector2(170 + index * 125, 85 + row * 110)
			enemy.scale = Vector2.ONE * 2.0
			root.add_child(enemy)
			enemy.facing = Vector2i.RIGHT
			if row == 1:
				enemy.visual_scale = Vector2(1.15, 0.85)
				enemy.visual_rotation = -0.12
				enemy.shot_direction = Vector2i.RIGHT
			elif row == 2:
				enemy.hp -= 2
				enemy.visual_rotation = 0.2
				enemy.visual_scale = Vector2(0.9, 1.1)
			elif row == 3:
				enemy.hp = 0
				enemy.visual_rotation = 0.4
				enemy.visual_scale = Vector2(1.15, 0.35)
			if row == 0:
				var label := Label.new()
				label.text = resources[index].trim_suffix("_enemy")
				label.position = Vector2(135 + index * 125, 20)
				root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://.godot/enemy_visuals.png")
	quit(0 if result == OK else 1)
