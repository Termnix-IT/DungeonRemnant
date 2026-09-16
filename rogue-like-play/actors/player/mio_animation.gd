class_name MioAnimation
extends RefCounted

const SHEET := preload("res://art/characters/shiramine_mio_animation_final.png")
const DIAGONAL_SHEET := preload("res://art/characters/shiramine_mio_diagonal.png")
const FRAME_SIZE := Vector2i(80, 80)
const DIRECTIONS: Array[StringName] = [&"front", &"back", &"left", &"right",
	&"front_left", &"front_right", &"back_left", &"back_right"]
const FACINGS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]


static func build_frame_set() -> SpriteFrames:
	var frame_set := SpriteFrames.new()
	frame_set.remove_animation(&"default")
	for row in DIRECTIONS.size():
		var direction_name := DIRECTIONS[row]
		var sheet: Texture2D = SHEET if row < 4 else DIAGONAL_SHEET
		_add_animation(frame_set, StringName("idle_%s" % direction_name), sheet, row % 4, 0, 2, 2.0)
		_add_animation(frame_set, StringName("walk_%s" % direction_name), sheet, row % 4, 2, 4, 10.0)
	return frame_set


static func direction_name(facing: Vector2i) -> StringName:
	if facing.x != 0 and facing.y != 0:
		if facing.y > 0:
			return &"front_left" if facing.x < 0 else &"front_right"
		return &"back_left" if facing.x < 0 else &"back_right"
	if facing.y > 0 and absi(facing.y) >= absi(facing.x):
		return &"front"
	if facing.y < 0 and absi(facing.y) >= absi(facing.x):
		return &"back"
	if facing.x < 0:
		return &"left"
	return &"right"


static func _add_animation(
	frame_set: SpriteFrames,
	animation_name: StringName,
	sheet: Texture2D,
	row: int,
	first_column: int,
	frame_count: int,
	speed: float
) -> void:
	frame_set.add_animation(animation_name)
	frame_set.set_animation_speed(animation_name, speed)
	frame_set.set_animation_loop(animation_name, true)
	for column in range(first_column, first_column + frame_count):
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2i(column * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frame_set.add_frame(animation_name, frame)
