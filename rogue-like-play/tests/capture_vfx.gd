extends SceneTree

# The fight's effects (combat/vfx) laid out over a real floor, each at six
# moments of its life from left to right, so the movement inside an effect
# can be read from one still: a light cut, a heavy cut, a whole turn, a
# thrust, a hit, a heavy blow landing, a spell landing, a shock over the
# floor, lightning, fire, and a foe's blow in its red. Images go to
# .godot/vfx_sheet.png. Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/vfx-capture.log --script res://tests/capture_vfx.gd

const AGES: Array[float] = [0.06, 0.2, 0.36, 0.52, 0.7, 0.88]
const CELL := Vector2(260.0, 150.0)
const ZOOM := 1.0
const WARM := Color(1.0, 0.92, 0.72)
const HEAVY := Color(1.0, 0.74, 0.42)
const ARCANE := Color(0.62, 0.72, 1.0)
const STORM := Color(0.7, 0.88, 1.0)
const HOSTILE := Color(1.0, 0.4, 0.3)


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	var hall := AreaData.new()
	hall.size = Vector2i(60, 36)
	var ground := AreaGround.new()
	root.add_child(ground)
	ground.build(hall.size, hall.walls(), 0)
	var middle := ground.bounds().get_center()
	ground.follow(middle, middle)
	ground.lift = 1.5
	var camera := Camera2D.new()
	camera.position = middle
	camera.zoom = Vector2.ONE * ZOOM
	root.add_child(camera)
	var holder := Node2D.new()
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(holder)
	var makers: Array[Callable] = [
		func(at: Vector2) -> Vfx: return Vfx.slash(holder, at, Vector2.RIGHT, 62.0, 120.0, WARM, 1.0, 0.0),
		func(at: Vector2) -> Vfx: return Vfx.slash(holder, at, Vector2.RIGHT, 68.0, 150.0, HEAVY, -1.0, 1.0),
		func(at: Vector2) -> Vfx: return Vfx.slash(holder, at, Vector2.RIGHT, 62.0, 360.0, WARM, 1.0, 0.5),
		func(at: Vector2) -> Vfx: return Vfx.lance(holder, at - Vector2(70.0, 0.0), Vector2.RIGHT, 130.0, 56.0, WARM),
		func(at: Vector2) -> Vfx: return Vfx.burst(holder, at, 84.0, Color(1.0, 0.86, 0.6), &"hit", Vector2.RIGHT, 0.0),
		func(at: Vector2) -> Vfx: return Vfx.burst(holder, at, 130.0, HEAVY, &"heavy", Vector2.RIGHT, 1.0),
		func(at: Vector2) -> Vfx: return Vfx.burst(holder, at, 120.0, ARCANE, &"magic", Vector2.ZERO, 0.5),
		func(at: Vector2) -> Vfx: return Vfx.ring(holder, at, 64.0, HEAVY),
		func(at: Vector2) -> Vfx: return Vfx.bolt(holder, at - Vector2(150.0, 20.0), at + Vector2(150.0, 20.0), STORM),
		func(at: Vector2) -> Vfx: return Vfx.flame(holder, at, 64.0),
		func(at: Vector2) -> Vfx: return Vfx.slash(holder, at, Vector2.LEFT, 62.0, 120.0, Color(HOSTILE, 0.9), 1.0, 0.0),
	]
	# Two screens' worth: the first six kinds, then the rest.
	var shots: Array[Image] = []
	for half in 2:
		for child in holder.get_children():
			child.free()
		var rows := makers.slice(half * 6, half * 6 + 6)
		var top := middle - Vector2(CELL.x * AGES.size(), CELL.y * 6.0) * 0.5 + CELL * 0.5
		for row in rows.size():
			for column in AGES.size():
				var effect: Vfx = rows[row].call(top + Vector2(column * CELL.x, row * CELL.y))
				effect.look.set_shader_parameter(&"age", AGES[column])
				effect.look.set_shader_parameter(&"seed", 0.37)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		shots.append(root.get_texture().get_image())
	var sheet := Image.create(1600, 1800, false, shots[0].get_format())
	sheet.blit_rect(shots[0], Rect2i(0, 0, 1600, 900), Vector2i.ZERO)
	sheet.blit_rect(shots[1], Rect2i(0, 0, 1600, 900), Vector2i(0, 900))
	var result := sheet.save_png("res://.godot/vfx_sheet.png")
	print("Captured the effects: vfx_sheet")
	quit(0 if result == OK else 1)
