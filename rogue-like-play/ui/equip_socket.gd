class_name EquipSocket
extends Button

# One round socket on the status page (HubStatus), drawn as the fight's HUD
# draws her actions (ActionSlot) and the upgrade tree its nodes: an emblem in
# a dark disc. A slot in the bar carries, under it on the key plate the HUD
# and the key guide use, the key that uses it (`key`), so what is set here is
# seen to become that key in the fight. A tile on the shelf carries its name
# and a short figure under it instead (`caption`, `note`: "叩きつけ", "6秒";
# "？？？", "未所持"), and the key plate of the other skill slot it is set in
# at its disc's upper right. A thing not held yet shows its emblem's shadow
# (`unknown`); an empty slot, or the tile that clears one, a dashed ring
# (`empty`, `clears` adding a slash); a slot that cannot hold anything yet is
# dimmed (`sealed`). What the chosen slot holds carries a gold diamond over
# it (`held`). The slot whose tiles are on the shelf keeps a quiet gold ring
# (`lit`); the focus rings it in full gold with a glow, and the pointer
# resting on it rings it faintly. A bare socket (the encyclopedia's tiles)
# carries nothing under or over its disc, and may draw its picture inset in
# the disc (`inset`), a standing figure kept inside the round.
#
# The button's styles are all empty (EquipSocket); it carries no words of its
# own, its name being in its tooltip, its caption and the page's column.

const KEY_HEIGHT := 24.0
const KEY_GAP := 8.0
const KEY_PAD := 16.0
const KEY_MIN := 30.0
const CAPTION_GAP := 6.0
const CAPTION_LINE := 19.0
const RING_WIDTH := 2.5
const RING_GAP := 5.0
const GLOW_RADII := [16.0, 12.0, 8.0, 4.0]
const HELD_MARK := 6.0
# Room over the disc for the held mark and the focus ring.
const TOP_ROOM := 2.0 * HELD_MARK + RING_GAP + 6.0
const DASHES := 24
const ARC_POINTS := 64

var diameter := 80.0
var captioned := false
var bare := false
# The picture's side against the disc's (1: the disc's full square).
var inset := 1.0
var emblem: Texture2D
var key := "":
	set(value):
		key = value
		queue_redraw()
var caption := ""
var note := ""
var unknown := false
var empty := false
var clears := false
var sealed := false
var held := false
var lit := false:
	set(value):
		lit = value
		queue_redraw()


# A slot (its key under it), with `with_caption` a tile (its name and figure
# under it), or with `without_marks` a bare socket.
func _init(extent := 80.0, with_caption := false, without_marks := false) -> void:
	theme_type_variation = &"EquipSocket"
	diameter = extent
	captioned = with_caption
	bare = without_marks
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var under := CAPTION_GAP + 2.0 * CAPTION_LINE if captioned else KEY_GAP + KEY_HEIGHT
	if bare:
		under = _top()
	custom_minimum_size = Vector2(diameter + 2.0 * (RING_GAP + RING_WIDTH), _top() + diameter + under)


# Room over the disc: for its ring alone on a bare socket.
func _top() -> float:
	return RING_GAP + RING_WIDTH + 2.0 if bare else TOP_ROOM


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, _top() + diameter * 0.5)


func _draw() -> void:
	var centre := _centre()
	var radius := diameter * 0.5
	var chosen := has_focus()
	var pointed := get_draw_mode() in [DRAW_HOVER, DRAW_HOVER_PRESSED]
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
		var side := diameter * inset
		draw_texture_rect(emblem, Rect2(centre - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, tint)
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
		ring = get_theme_color(&"focus")
	elif lit:
		ring = get_theme_color(&"lit")
	elif pointed:
		ring = get_theme_color(&"pointed")
	elif bare:
		# A bare socket keeps a faint rim, its disc being all it has to show.
		ring = get_theme_color(&"rim")
	if ring.a > 0.0:
		draw_arc(centre, radius + RING_GAP, 0.0, TAU, ARC_POINTS, ring, RING_WIDTH, true)
	if held:
		var mark := Vector2(centre.x, HELD_MARK + 1.5)
		HubUI.diamond(self, mark, HELD_MARK + 1.5, get_theme_color(&"held_edge"))
		HubUI.diamond(self, mark, HELD_MARK, get_theme_color(&"held"))
	if captioned:
		_draw_caption(chosen)
		if not key.is_empty():
			# The other slot's key, pinned to the disc's upper right.
			_draw_key(Vector2(centre.x + radius * 0.75, TOP_ROOM - 2.0), false)
	elif not key.is_empty():
		_draw_key(Vector2(size.x * 0.5, TOP_ROOM + diameter + KEY_GAP), chosen or lit)


# The key on its plate, its top edge centred on `top`; gold while the socket
# is chosen or lit.
func _draw_key(top: Vector2, bright: bool) -> void:
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var width := maxf(KEY_MIN, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + KEY_PAD)
	var plate := Rect2(top.x - width * 0.5, top.y, width, KEY_HEIGHT)
	draw_style_box(get_theme_stylebox(&"key_plate_lit" if bright else &"key_plate"), plate)
	var baseline := plate.position.y + (KEY_HEIGHT + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(plate.position.x, baseline), key, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, get_theme_color(&"key_lit") if bright else get_theme_color(&"key"))


# The tile's name and its short figure, under the disc.
func _draw_caption(chosen: bool) -> void:
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"caption_size")
	var top := TOP_ROOM + diameter + CAPTION_GAP
	var width := size.x + 24.0
	var left := -12.0
	if not caption.is_empty():
		var colour := get_theme_color(&"caption_lit") if chosen else (get_theme_color(&"caption_off") if unknown else get_theme_color(&"caption"))
		draw_string(font, Vector2(left, top + font.get_ascent(font_size)), caption, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, colour)
	if not note.is_empty():
		draw_string(font, Vector2(left, top + CAPTION_LINE + font.get_ascent(font_size)), note, HORIZONTAL_ALIGNMENT_CENTER, width, font_size - 1, get_theme_color(&"note"))
