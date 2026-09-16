extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func has_binary_alpha(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if not is_equal_approx(alpha, 0.0) and not is_equal_approx(alpha, 1.0):
				return false
	return true


func has_clear_cell_margins(image: Image, margin: int) -> bool:
	for row in 4:
		for column in 6:
			var origin := Vector2i(column * 80, row * 80)
			for offset in 80:
				for inset in margin:
					if image.get_pixelv(origin + Vector2i(offset, inset)).a > 0.0:
						return false
					if image.get_pixelv(origin + Vector2i(offset, 79 - inset)).a > 0.0:
						return false
					if image.get_pixelv(origin + Vector2i(inset, offset)).a > 0.0:
						return false
					if image.get_pixelv(origin + Vector2i(79 - inset, offset)).a > 0.0:
						return false
	return true


func run_tests() -> void:
	var texture := load("res://art/characters/shiramine_mio_animation_final.png") as Texture2D
	check(texture != null and texture.get_size() == Vector2(480, 320), "Animation atlas uses 24 padded 80px frames")
	var image := texture.get_image()
	check(has_binary_alpha(image), "Animation atlas has no semitransparent fringe")
	check(has_clear_cell_margins(image, 2), "Every animation frame has a two-pixel transparent safety margin")
	var diagonal := MioAnimation.DIAGONAL_SHEET.get_image()
	check(diagonal.get_size() == Vector2i(480, 320), "Diagonal atlas has 24 equally sized frames")
	check(has_binary_alpha(diagonal), "Diagonal frames have clean binary transparency")
	check(has_clear_cell_margins(diagonal, 2), "Diagonal frames have safe transparent margins")
	for row in 4:
		var previous := PackedByteArray()
		for column in 6:
			var cell := diagonal.get_region(Rect2i(column * 80, row * 80, 80, 80))
			var bounds := cell.get_used_rect()
			check(bounds.size.y >= 64 and bounds.end.y == 78, "Diagonal character scale and foot baseline stay aligned")
			if column > 2:
				check(cell.get_data() != previous, "Walk frames contain distinct poses")
			previous = cell.get_data()
	var preview := (load("res://tests/player_animation_preview.tscn") as PackedScene).instantiate()
	root.add_child(preview)
	await process_frame
	var frame_set: SpriteFrames = preview.actual_sprite.sprite_frames
	check(frame_set.get_animation_names().size() == 16, "All eight directions have idle and walking animations")
	for direction_name: StringName in preview.DIRECTIONS:
		var idle_name := StringName("idle_%s" % direction_name)
		var walk_name := StringName("walk_%s" % direction_name)
		check(frame_set.has_animation(idle_name), "%s idle animation exists" % direction_name)
		check(frame_set.get_frame_count(idle_name) == 2, "%s idle animation has two frames" % direction_name)
		check(frame_set.has_animation(walk_name), "%s walk animation exists" % direction_name)
		check(frame_set.get_frame_count(walk_name) == 4, "%s walk animation has four frames" % direction_name)
		var first_frame := frame_set.get_frame_texture(idle_name, 0) as AtlasTexture
		check(first_frame.region.size == Vector2(80, 80), "%s animation reads an 80px padded cell" % direction_name)
		var index: int = preview.DIRECTIONS.find(direction_name)
		check(first_frame.atlas == (MioAnimation.SHEET if index < 4 else MioAnimation.DIAGONAL_SHEET), "Direction selects the correct atlas")
		check(first_frame.region.position == Vector2(0, (index % 4) * 80), "Direction selects its own row")
	check(preview.actual_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Native preview uses nearest filtering")
	check(preview.actual_sprite.scale == Vector2(0.8, 0.8), "Runtime preview cancels the camera's 1.25 texture scale")
	check(preview.inspection_sprite.global_scale.is_equal_approx(Vector2(3.0, 3.0)), "Inspection preview exposes pixel detail")
	check(not preview.actual_player.input_enabled, "Preview controls cannot submit gameplay actions")
	preview.auto_cycle = false
	preview.actual_sprite.set_frame_and_progress(2, 0.4)
	preview._set_direction(&"left")
	check(preview.actual_sprite.animation == &"walk_left" and preview.actual_sprite.frame == 2, "Preview turning preserves runtime walk phase")
	var event := InputEventKey.new()
	event.pressed = true
	var diagonal_keys := [KEY_HOME, KEY_PAGEUP, KEY_END, KEY_PAGEDOWN]
	var diagonal_names := [&"back_left", &"back_right", &"front_left", &"front_right"]
	for index in diagonal_keys.size():
		event.keycode = diagonal_keys[index]
		preview._unhandled_key_input(event)
		check(preview.actual_sprite.animation == StringName("walk_%s" % diagonal_names[index]), "Preview can select diagonal directions")
	preview._set_direction(&"left")
	event.keycode = KEY_Q
	preview._unhandled_key_input(event)
	check(preview.actual_player.weapon.kind == WeaponData.Kind.SPEAR and preview.inspection_player.weapon.kind == WeaponData.Kind.SPEAR, "Weapon selection updates both preview scales")
	event.keycode = KEY_SPACE
	preview._unhandled_key_input(event)
	check(preview.actual_player.move_tween == null and preview.actual_sprite.animation == &"idle_left", "Idle control cancels the runtime step")
	check(preview.actual_sprite.position == preview.actual_player.BASE_SPRITE_POSITION, "Idle control restores the resting position")
	event.keycode = KEY_SPACE
	preview._unhandled_key_input(event)
	await create_timer(0.5).timeout
	check(preview.actual_sprite.animation == &"walk_left" and preview.actual_player.move_tween != null, "Walking preview repeats real steps")
	preview._process(0.0)
	check(preview.actual_sprite.animation == preview.inspection_sprite.animation and preview.actual_sprite.frame == preview.inspection_sprite.frame, "Both preview scales retain the same animation and frame after repeating")
	preview.walking = false
	preview._refresh_animation()
	preview.actual_sprite.set_frame_and_progress(1, 0.4)
	preview._set_direction(&"back")
	check(preview.actual_sprite.animation == &"idle_back" and preview.actual_sprite.frame == 1 and is_equal_approx(preview.actual_sprite.frame_progress, 0.4), "Idle direction change preserves animation phase")
	preview.free()
	print("Player animation preview tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
