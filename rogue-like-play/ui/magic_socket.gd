class_name MagicSocket
extends Button

# The round socket on a staff's slot: the spell the staff holds, drawn small
# in a bronze ring, or, while it is empty, a "+" in a ring that breathes so an
# empty staff asks to be filled. Pressing it opens the MagicPicker. It never
# takes the focus (the slot keeps it; a key opens the picker instead).

const SIZE := 34.0
const BREATH_TIME := 1.1
const RING := Color(0.86, 0.68, 0.36)
const EMPTY_RING := Color(0.55, 0.85, 1.0)

var scroll: ItemData:
	set(value):
		scroll = value
		tooltip_text = "魔法：%s（消費MP %d）" % [value.weapon.display_name, value.weapon.mana_cost] if value != null else "魔法を込める"
		_breathe()
		queue_redraw()
# 0..1, how strongly the empty ring glows at this point of its breath.
var glow := 0.0:
	set(value):
		glow = value
		queue_redraw()
var _breath: Tween


func _init() -> void:
	custom_minimum_size = Vector2.ONE * SIZE
	size = custom_minimum_size
	focus_mode = Control.FOCUS_NONE
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "魔法を込める"
	visibility_changed.connect(_breathe)


# The empty ring breathes only while it is shown, so a hidden socket costs
# nothing per frame.
func _breathe() -> void:
	if _breath != null:
		_breath.kill()
		_breath = null
	glow = 0.0
	if scroll != null or not is_visible_in_tree():
		return
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_breath.tween_property(self, "glow", 1.0, BREATH_TIME)
	_breath.tween_property(self, "glow", 0.0, BREATH_TIME)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	var lit := is_hovered()
	draw_circle(center, radius + 2.0, Color(0, 0, 0, 0.75))
	draw_circle(center, radius, Color(0.05, 0.045, 0.05, 0.95))
	if scroll != null:
		var extent := radius * 1.5
		ItemGlyph.paint(self, Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), scroll, Color.WHITE)
		draw_arc(center, radius, 0.0, TAU, 32, RING.lightened(0.25) if lit else RING, 2.0, true)
		return
	var ring := Color(EMPTY_RING, 0.45 + 0.5 * maxf(glow, 1.0 if lit else 0.0))
	draw_arc(center, radius, 0.0, TAU, 32, ring, 2.0, true)
	var arm := radius * 0.45
	draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), ring, 2.0)
	draw_line(center - Vector2(0, arm), center + Vector2(0, arm), ring, 2.0)
