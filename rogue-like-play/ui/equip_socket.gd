class_name EquipSocket
extends Button

# One round socket holding an emblem: a boon held in the run, in the fight's
# menu (DungeonMenu) and on the run's result (RunEndView), drawn as the
# fight's HUD draws her actions (ActionSlot) and the upgrade tree its nodes,
# an emblem in a dark disc with a faint rim. The one the page tells of keeps
# a quiet gold ring (`lit`); the focus rings it in full gold with a glow, and
# the pointer resting on it rings it faintly.
#
# The button's styles are all empty (EquipSocket); it carries no words of its
# own, its name being in its tooltip and the page's account of it.

const RING_WIDTH := 2.5
const RING_GAP := 5.0
const GLOW_RADII := [16.0, 12.0, 8.0, 4.0]
const ARC_POINTS := 64

var diameter := 80.0
var emblem: Texture2D
var lit := false:
	set(value):
		lit = value
		queue_redraw()


func _init(extent := 80.0) -> void:
	theme_type_variation = &"EquipSocket"
	diameter = extent
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2.ONE * (diameter + 2.0 * (RING_GAP + RING_WIDTH)) + Vector2(0.0, 4.0)


func _draw() -> void:
	var centre := Vector2(size.x * 0.5, RING_GAP + RING_WIDTH + 2.0 + diameter * 0.5)
	var radius := diameter * 0.5
	var chosen := has_focus()
	if chosen:
		var glow := get_theme_color(&"glow")
		for extra: float in GLOW_RADII:
			draw_circle(centre, radius + extra, glow)
	draw_circle(centre, radius, get_theme_color(&"disc"))
	if emblem != null:
		draw_texture_rect(emblem, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * diameter), false)
	var ring := get_theme_color(&"rim")
	if chosen:
		ring = get_theme_color(&"focus")
	elif lit:
		ring = get_theme_color(&"lit")
	elif get_draw_mode() in [DRAW_HOVER, DRAW_HOVER_PRESSED]:
		ring = get_theme_color(&"pointed")
	draw_arc(centre, radius + RING_GAP, 0.0, TAU, ARC_POINTS, ring, RING_WIDTH, true)
