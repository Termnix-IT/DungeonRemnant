class_name EquipSocket
extends Button

# One round socket on the status page (HubStatus), drawn as the fight's HUD
# draws her actions (ActionSlot) and the upgrade tree its nodes: an emblem in
# a dark disc, and under it, on a small tag, the key that uses it (`key`), so
# what is set here is seen to become that key in the fight. The slots in the
# bar and the tiles on the shelf under them are both sockets, the tiles
# smaller. A thing not held yet shows its emblem's shadow (`unknown`); an
# empty slot, or the tile that clears one, a dashed ring (`empty`, `clears`
# adding a slash); a slot that cannot hold anything yet is dimmed (`sealed`).
# What the chosen slot holds carries a gold diamond over it (`held`). The
# slot whose tiles are on the shelf keeps a quiet gold ring (`lit`); the
# focus rings it in full gold with a glow, and the pointer resting on it
# rings it faintly.
#
# The button's styles are all empty (EquipSocket); it carries no words of its
# own, its name being in its tooltip and in the page's column.

const KEY_HEIGHT := 22.0
const KEY_GAP := 8.0
const KEY_PAD := 16.0
const KEY_MIN := 28.0
const RING_WIDTH := 2.5
const RING_GAP := 5.0
const GLOW_RADII := [16.0, 12.0, 8.0, 4.0]
const HELD_MARK := 6.0
# Room over the disc for the held mark and the focus ring.
const TOP_ROOM := 2.0 * HELD_MARK + RING_GAP + 6.0
const DASHES := 24
const ARC_POINTS := 64

var diameter := 80.0
var emblem: Texture2D
var key := "":
	set(value):
		key = value
		queue_redraw()
var unknown := false
var empty := false
var clears := false
var sealed := false
var held := false
var lit := false:
	set(value):
		lit = value
		queue_redraw()


func _init(extent := 80.0) -> void:
	theme_type_variation = &"EquipSocket"
	diameter = extent
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2(diameter + 2.0 * (RING_GAP + RING_WIDTH), TOP_ROOM + diameter + KEY_GAP + KEY_HEIGHT)


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, TOP_ROOM + diameter * 0.5)


func _draw() -> void:
	var centre := _centre()
	var radius := diameter * 0.5
	var chosen := has_focus()
	var pointed := get_draw_mode() in [DRAW_HOVER, DRAW_HOVER_PRESSED]
	var gold := get_theme_color(&"focus")
	if chosen:
		var glow := get_theme_color(&"glow")
		for extra: float in GLOW_RADII:
			draw_circle(centre, radius + extra, glow)
	draw_circle(centre, radius, get_theme_color(&"disc"))
	if emblem != null:
		var tint := Color.WHITE
		if unknown:
			tint = get_theme_color(&"unknown_tint")
		elif sealed:
			tint = get_theme_color(&"sealed_tint")
		draw_texture_rect(emblem, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * diameter), false, tint)
	if empty or clears:
		var dash := get_theme_color(&"empty_ring")
		var step := TAU / DASHES
		for index in DASHES:
			draw_arc(centre, radius - 3.0, index * step, index * step + step * 0.5, 6, dash, 1.5, true)
		if clears:
			var reach := radius * 0.4
			draw_line(centre + Vector2(-reach, reach), centre + Vector2(reach, -reach), dash, 2.0, true)
	var ring := Color.TRANSPARENT
	if chosen:
		ring = gold
	elif lit:
		ring = get_theme_color(&"lit")
	elif pointed:
		ring = get_theme_color(&"pointed")
	if ring.a > 0.0:
		draw_arc(centre, radius + RING_GAP, 0.0, TAU, ARC_POINTS, ring, RING_WIDTH, true)
	if held:
		var mark := Vector2(centre.x, HELD_MARK + 1.5)
		HubUI.diamond(self, mark, HELD_MARK + 1.5, get_theme_color(&"held_edge"))
		HubUI.diamond(self, mark, HELD_MARK, get_theme_color(&"held"))
	if not key.is_empty():
		_draw_key(chosen or lit)


# The key's tag under the disc, gold-edged while the socket is chosen or lit.
func _draw_key(bright: bool) -> void:
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var width := maxf(KEY_MIN, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + KEY_PAD)
	var tag := Rect2(size.x * 0.5 - width * 0.5, TOP_ROOM + diameter + KEY_GAP, width, KEY_HEIGHT)
	draw_rect(tag, get_theme_color(&"key_ground"))
	draw_rect(tag, get_theme_color(&"focus") if bright else get_theme_color(&"key_edge"), false, 1.0)
	var baseline := tag.position.y + (KEY_HEIGHT + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(tag.position.x, baseline), key, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, get_theme_color(&"key_lit") if bright else get_theme_color(&"key"))
