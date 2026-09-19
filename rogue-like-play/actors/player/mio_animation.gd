class_name MioAnimation
extends RefCounted

const SHEET := preload("res://art/characters/mio_dungeon_chibi_64/cardinal.png")
const DIAGONAL_SHEET := preload("res://art/characters/mio_dungeon_chibi_64/diagonal.png")
const FRAME_SIZE := Vector2i(64, 64)
const DIRECTIONS: Array[StringName] = [&"front", &"back", &"left", &"right",
	&"front_left", &"front_right", &"back_left", &"back_right"]
const FACINGS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]


static func build_frame_set() -> SpriteFrames:
	var frame_set := SpriteFrames.new()
	frame_set.remove_animation(&"default")
	for row in range(1, DIRECTIONS.size()):
		var direction_name := DIRECTIONS[row]
		var sheet: Texture2D = SHEET if row < 4 else DIAGONAL_SHEET
		var source_row := row - 1 if row < 4 else row - 4
		_add_animation(frame_set, StringName("idle_%s" % direction_name), sheet, source_row, 0, 2, 2.0)
		_add_animation(frame_set, StringName("walk_%s" % direction_name), sheet, source_row, 2, 4, 10.0)
	var front_idle := build_front_idle_frames(false, true)
	frame_set.add_animation(&"idle_front")
	frame_set.set_animation_speed(&"idle_front", 1.0)
	for index in 8:
		frame_set.add_frame(&"idle_front", front_idle.get_frame_texture(&"idle_front", index), front_idle.get_frame_duration(&"idle_front", index))
	frame_set.add_animation(&"walk_front")
	# Eight frames retain the existing 0.4-second step cycle.
	frame_set.set_animation_speed(&"walk_front", 20.0)
	for index in 8:
		var frame := AtlasTexture.new()
		frame.atlas = preload("res://art/characters/mio_dungeon_chibi_64/walk_front.png")
		frame.region = Rect2i((index % 4) * 64, (index / 4) * 64, 64, 64)
		frame_set.add_frame(&"walk_front", frame)
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
		# Keep the resting silhouette fixed, avoiding generated hair/body drift.
		var source_column := first_column if String(animation_name).begins_with("idle_") else column
		frame.region = Rect2i(source_column * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frame_set.add_frame(animation_name, frame)


static func build_front_idle_frames(eyes_only := false, dungeon := false) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle_front")
	frames.set_animation_loop(&"idle_front", true)
	frames.set_animation_speed(&"idle_front", 1.0)
	# Hold the open-eyed poses; the blink should be brief rather than rhythmic.
	var durations := [1.1, 0.24, 0.24, 0.18, 0.07, 0.10, 0.07, 0.40]
	for index in 8:
		var frame := AtlasTexture.new()
		frame.atlas = preload("res://art/characters/mio_dungeon_chibi_64/idle_front.png") if dungeon else preload("res://art/characters/mio_animation_v2/idle_front.png")
		# Reuse one silhouette; only the approved blink changes between frames.
		var size := 64 if dungeon else 128
		frame.region = Rect2i(0, 0, size, size)
		if eyes_only:
			var source_index: int = index if index == 4 or index == 5 else 0
			var eye_rect := Rect2i(24, 25, 20, 8) if dungeon else Rect2i(55, 31, 19, 8)
			frame.region = Rect2i(Vector2i((source_index % 4) * size, (source_index / 4) * size) + eye_rect.position, eye_rect.size)
		frames.add_frame(&"idle_front", frame, durations[index])
	return frames
