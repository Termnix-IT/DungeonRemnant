extends Node2D

# Wall torches and the stairs' warm light. Torches hang on wall faces that look
# down onto visible floor; their glow is added on top of the terrain in a child
# layer so the floor brightens instead of being painted over. Each torch is a
# painted sconce (tools/build_painted_objects.py) drawn TORCH_HEIGHT world px
# tall, and its flame flickers by the same waves as the glow and sways.
const TILE_SIZE := 48.0
const MAX_TORCHES := 10
const TORCH_SPACING := 5
const GLOW_RADIUS := 96.0
const STAIRS_RADIUS := 60.0
const STAIRS_CORE_RADIUS := 30.0
# Flame and light colours follow dungeon.gd's terrain theme order.
const THEME_LIGHTS: Array[Color] = [Color(1.0, 0.66, 0.32), Color(0.95, 0.72, 0.38), Color(1.0, 0.45, 0.2), Color(0.72, 0.56, 1.0)]
const SCONCE := preload("res://art/tiles/painted/torch_sconce.png")
const FLAME := preload("res://art/tiles/painted/torch_flame.png")
const TORCH_HEIGHT := 26.0
const FLAME_HEIGHT := 16.0

var torches: Array[Vector2i] = []
var stairs := Vector2i(-1, -1)
var light_color := THEME_LIGHTS[0]
var _phase := 0.0
var _glow: Node2D
var _glow_texture: GradientTexture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_glow_texture = GradientTexture2D.new()
	_glow_texture.fill = GradientTexture2D.FILL_RADIAL
	_glow_texture.fill_from = Vector2(0.5, 0.5)
	_glow_texture.fill_to = Vector2(1.0, 0.5)
	_glow_texture.width = 128
	_glow_texture.height = 128
	var falloff := Gradient.new()
	falloff.set_color(0, Color.WHITE)
	falloff.set_color(1, Color(1, 1, 1, 0))
	falloff.add_point(0.35, Color(1, 1, 1, 0.45))
	_glow_texture.gradient = falloff
	_glow = Node2D.new()
	_glow.name = "Glow"
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.show_behind_parent = true
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	visibility_changed.connect(_update_processing)
	_update_processing()


func refresh(grid: GridState, visible_cells: Dictionary, stairs_cell: Vector2i, has_stairs: bool, forest: bool, theme_index: int) -> void:
	torches.clear()
	stairs = Vector2i(-1, -1)
	light_color = THEME_LIGHTS[clampi(theme_index, 0, THEME_LIGHTS.size() - 1)]
	if grid != null:
		# Trees line the forest; only built halls carry torches.
		if not forest:
			for cell: Vector2i in visible_cells:
				if torches.size() >= MAX_TORCHES:
					break
				var below := cell + Vector2i.DOWN
				if grid.walls.has(cell) and not grid.pillars.has(cell) and grid.is_floor(below) and visible_cells.has(below) and _cell_seed(cell) % TORCH_SPACING == 0:
					torches.append(cell)
		if has_stairs and visible_cells.has(stairs_cell) and grid.is_floor(stairs_cell):
			stairs = stairs_cell
	_update_processing()
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()


func _update_processing() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and (not torches.is_empty() or stairs.x >= 0))


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 20.0)
	queue_redraw()
	_glow.queue_redraw()


func _cell_seed(cell: Vector2i) -> int:
	# Coordinate hashing never consumes the generator's gameplay RNG stream.
	return absi((cell.x * 83492791) ^ (cell.y * 2971215073))


# Two unrelated waves per torch keep neighbours from flickering in step.
func flicker(cell: Vector2i) -> float:
	var offset := float(_cell_seed(cell) % 997)
	return 0.86 + 0.09 * sin(_phase * 9.1 + offset) + 0.05 * sin(_phase * 23.7 + offset * 1.7)


func _flame_point(cell: Vector2i) -> Vector2:
	# The sconce sits low on the wall face, just above the floor it lights.
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE - 14.0)


func _draw() -> void:
	for cell in torches:
		_draw_torch(cell, _flame_point(cell))


# The sconce hangs with its torch's top at the flame point; the flame stands
# on it, stretched by the flicker and leaning with the sway.
func _draw_torch(cell: Vector2i, point: Vector2) -> void:
	var sconce := SCONCE
	var flame := FLAME
	var strength := flicker(cell)
	var sconce_size := Vector2(sconce.get_width() * TORCH_HEIGHT / sconce.get_height(), TORCH_HEIGHT)
	draw_texture_rect(sconce, Rect2(point + Vector2(-sconce_size.x * 0.5, -sconce_size.y * 0.35), sconce_size), false)
	var height := FLAME_HEIGHT * (0.85 + 0.25 * strength)
	var flame_size := Vector2(flame.get_width() * FLAME_HEIGHT / flame.get_height(), height)
	var sway := sin(_phase * 6.0 + float(_cell_seed(cell) % 13)) * 0.06
	draw_set_transform(point + Vector2(0, -sconce_size.y * 0.3), sway, Vector2.ONE)
	draw_texture_rect(flame, Rect2(Vector2(-flame_size.x * 0.5, -flame_size.y), flame_size), false, Color(1, 1, 1, 0.92 + 0.08 * strength))
	draw_set_transform(Vector2.ZERO)


func _draw_glow() -> void:
	for cell in torches:
		var strength := flicker(cell)
		var tint := light_color
		tint.a = 0.28 * strength
		var radius := GLOW_RADIUS * (0.96 + 0.04 * strength)
		# Centred just below the flame, so most light lands on the floor.
		var center := _flame_point(cell) + Vector2(0, 18)
		_glow.draw_texture_rect(_glow_texture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)
		var core := tint
		core.a = 0.35 * strength
		_glow.draw_texture_rect(_glow_texture, Rect2(_flame_point(cell) + Vector2(-16, -22), Vector2.ONE * 32.0), false, core)
	if stairs.x >= 0:
		var pulse := 0.5 + 0.5 * sin(_phase * 1.6)
		var gold := Color(1.0, 0.78, 0.36, 0.22 + 0.1 * pulse)
		var center := (Vector2(stairs) + Vector2.ONE * 0.5) * TILE_SIZE
		_glow.draw_texture_rect(_glow_texture, Rect2(center - Vector2.ONE * STAIRS_RADIUS, Vector2.ONE * STAIRS_RADIUS * 2.0), false, gold)
		# A tight core gilds the painted steps themselves, so the exit reads
		# as the golden stairs the log names even on a dark, textured floor.
		var core := Color(1.0, 0.74, 0.3, 0.38 + 0.14 * pulse)
		_glow.draw_texture_rect(_glow_texture, Rect2(center - Vector2.ONE * STAIRS_CORE_RADIUS, Vector2.ONE * STAIRS_CORE_RADIUS * 2.0), false, core)
