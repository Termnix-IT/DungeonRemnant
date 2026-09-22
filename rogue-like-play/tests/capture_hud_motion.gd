extends "res://tests/capture_preparation.gd"


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 60
	var hud = preload("res://ui/hud.tscn").instantiate()
	root.add_child(hud)
	for resolution in [Vector2i(1440, 900), Vector2i(1152, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		hud.reset_log()
		hud.refresh(24, 24, 0, 0, "", 1, "Room")
		hud.show_mana(20, 20)
		await settle()
		hud.refresh(9, 24, 1, 1, "敵の攻撃で15ダメージ。", 1, "Room")
		hud.show_mana(8, 20)
		await create_timer(0.07).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.godot/hud_damage_%d.png" % resolution.y) == OK, "Damage capture")
		await create_timer(0.45).timeout
		await shot("hud_settled_%d" % resolution.y)
		hud.refresh(21, 24, 2, 0, "HPが12回復しました。", 1, "Room")
		hud.show_mana(18, 20)
		await create_timer(0.07).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.godot/hud_recovery_%d.png" % resolution.y) == OK, "Recovery capture")
	hud.free()
	quit(0 if failures == 0 else 1)
