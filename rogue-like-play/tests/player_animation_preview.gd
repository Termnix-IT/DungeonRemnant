extends Node2D

const TILE_SIZE := 48
const DIRECTIONS: Array[StringName] = MioAnimation.DIRECTIONS
const FACING := MioAnimation.FACINGS
const WEAPONS := [preload("res://data/weapons/sword.tres"), preload("res://data/weapons/spear.tres"), preload("res://data/weapons/hammer.tres")]

var actual_player: Node2D
var inspection_player: Node2D
var weapon_index := 0
var actual_sprite: AnimatedSprite2D
var inspection_sprite: AnimatedSprite2D
var direction: StringName = &"front"
var walking := true
var auto_cycle := true
var cycle_elapsed := 0.0
var state_label: Label


func _ready() -> void:
	queue_redraw()
	actual_player = _create_player(Vector2(280, 366), 1.0)
	inspection_player = _create_player(Vector2(750, 350), 3.75)
	actual_sprite = actual_player.sprite
	inspection_sprite = inspection_player.sprite
	_create_labels()
	_refresh_animation()


func _create_player(position_value: Vector2, scale_value: float) -> Node2D:
	var player := preload("res://actors/player/player.tscn").instantiate()
	player.position = position_value
	player.scale = Vector2.ONE * scale_value
	player.input_enabled = false
	add_child(player)
	return player


func _create_labels() -> void:
	_add_label("白峰 澪　プレイヤーアニメーション確認", Vector2(54, 34), 28, Color("e9edf7"))
	_add_label("48pxタイル上の実寸", Vector2(62, 116), 18, Color("b9c5d8"))
	_add_label("3倍拡大（輪郭・動き確認）", Vector2(573, 116), 18, Color("b9c5d8"))
	state_label = _add_label("", Vector2(54, 610), 18, Color("f0c77b"))
	_add_label("矢印/WASD：向き　Home/PgUp/End/PgDn：斜め　Space：歩行　Tab：自動　Q：武器", Vector2(54, 654), 16, Color("8f9caf"))


func _add_label(text_value: String, position_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1000, 720), Color("080b12"))
	draw_rect(Rect2(42, 94, 476, 500), Color("101722"), true)
	draw_rect(Rect2(548, 94, 410, 500), Color("101722"), true)
	draw_rect(Rect2(42, 94, 476, 500), Color("4f5c6b"), false, 2.0)
	draw_rect(Rect2(548, 94, 410, 500), Color("4f5c6b"), false, 2.0)
	var origin := Vector2(64, 151)
	for y in range(8):
		for x in range(9):
			var tile_rect := Rect2(origin + Vector2(x, y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
			var shade := Color("242936") if (x + y) % 2 == 0 else Color("202531")
			draw_rect(tile_rect, shade, true)
			draw_rect(tile_rect, Color("343b49"), false, 1.0)
			if (x * 3 + y * 5) % 7 == 0:
				draw_line(tile_rect.position + Vector2(10, 17), tile_rect.position + Vector2(23, 21), Color("171b24"), 2.0)
	draw_circle(Vector2(750, 350), 136.0, Color("171d29"))
	draw_circle(Vector2(750, 350), 137.0, Color("3f4959"), false, 2.0)


func _process(delta: float) -> void:
	if walking and actual_player.move_tween == null:
		_refresh_animation()
	# Both scales show the same frame even across a direction change.
	inspection_sprite.set_frame_and_progress(actual_sprite.frame, actual_sprite.frame_progress)
	if not auto_cycle:
		return
	cycle_elapsed += delta
	if cycle_elapsed < 1.6:
		return
	cycle_elapsed = 0.0
	var next_index := (DIRECTIONS.find(direction) + 1) % DIRECTIONS.size()
	direction = DIRECTIONS[next_index]
	_refresh_animation()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_HOME:
			_set_direction(&"back_left")
		KEY_PAGEUP:
			_set_direction(&"back_right")
		KEY_END:
			_set_direction(&"front_left")
		KEY_PAGEDOWN:
			_set_direction(&"front_right")
		KEY_UP, KEY_W:
			_set_direction(&"back")
		KEY_DOWN, KEY_S:
			_set_direction(&"front")
		KEY_LEFT, KEY_A:
			_set_direction(&"left")
		KEY_RIGHT, KEY_D:
			_set_direction(&"right")
		KEY_SPACE:
			walking = not walking
			auto_cycle = false
			_refresh_animation()
		KEY_TAB:
			auto_cycle = not auto_cycle
			cycle_elapsed = 0.0
			_refresh_animation()
		KEY_Q:
			weapon_index = (weapon_index + 1) % WEAPONS.size()
			_refresh_animation()
		_:
			return
	get_viewport().set_input_as_handled()


func _set_direction(value: StringName) -> void:
	direction = value
	auto_cycle = false
	cycle_elapsed = 0.0
	_refresh_animation()


func _refresh_animation() -> void:
	for player in [actual_player, inspection_player]:
		player.facing = FACING[DIRECTIONS.find(direction)]
		player.weapon = WEAPONS[weapon_index]
		player.queue_redraw()
		if walking:
			if player.move_tween == null:
				player.play_step(player.facing, TILE_SIZE)
		else:
			player.reset_step()
	if state_label:
		var motion_text := "歩行" if walking else "待機"
		var mode_text := "自動" if auto_cycle else "手動"
		state_label.text = "状態：%s / %s / %s" % [direction, motion_text, mode_text]
