extends Node2D

# Attack range while aiming: each cell in reach carries a golden rune mark,
# and a cell holding a target a red-orange reticle mark. The marks are light
# (painted on black, art/ui/hud/aim_*.png) added onto the floor, so the tile
# and whoever stands on it show through; they breathe slowly while the
# direction is chosen.
const RANGE_MARK := preload("res://art/ui/hud/aim_range.png")
const TARGET_MARK := preload("res://art/ui/hud/aim_target.png")
const PULSE_SPEED := 4.0
# How bright the marks are at the low and high of their breath.
const RANGE_LIGHT := Vector2(0.75, 1.0)
const TARGET_LIGHT := Vector2(0.8, 1.0)

var cells: Array[Vector2i] = []
var target_cells: Array[Vector2i] = []
var tile_size := 48
var _phase := 0.0


func _init() -> void:
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light


func _process(delta: float) -> void:
	if not visible:
		return
	_phase = fmod(_phase + delta * PULSE_SPEED, TAU)
	queue_redraw()


func _draw() -> void:
	var breath := 0.5 + 0.5 * sin(_phase)
	for cell in cells:
		var area := Rect2(Vector2(cell * tile_size), Vector2.ONE * tile_size)
		var target := cell in target_cells
		var light := TARGET_LIGHT if target else RANGE_LIGHT
		# Added light: dimming the colour dims the mark; alpha stays whole.
		var strength := lerpf(light.x, light.y, breath)
		draw_texture_rect(TARGET_MARK if target else RANGE_MARK, area, false, Color(strength, strength, strength, 1.0))
