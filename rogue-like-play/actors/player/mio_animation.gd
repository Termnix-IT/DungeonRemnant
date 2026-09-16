class_name MioAnimation
extends RefCounted

const SHEET := preload("res://art/characters/shiramine_mio_animation_final.png")
const FRAME_SIZE := Vector2i(80, 80)
const DIRECTIONS: Array[StringName] = [&"front", &"back", &"left", &"right"]


static func build_frame_set() -> SpriteFrames:
	var frame_set := SpriteFrames.new()
	frame_set.remove_animation(&"default")
	for row in DIRECTIONS.size():
		var direction_name := DIRECTIONS[row]
		_add_animation(frame_set, StringName("idle_%s" % direction_name), row, 0, 2, 2.0)
		_add_animation(frame_set, StringName("walk_%s" % direction_name), row, 2, 4, 10.0)
	return frame_set


static func direction_name(facing: Vector2i) -> StringName:
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
		frame.atlas = SHEET
		frame.region = Rect2i(column * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frame_set.add_frame(animation_name, frame)
