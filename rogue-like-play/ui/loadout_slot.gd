class_name LoadoutSlot
extends Button

# One of her four slots on the status page (HubStatus), a row of her build:
# at the left the slot as the fight's HUD shows it (the emblem of what it
# holds, the key that uses it on its plate under the emblem), and beside it
# the slot's name, what it holds, and a short figure ("再使用 6秒"). An empty
# slot is a dashed ring named "空き"; one that cannot hold anything yet shows
# its seal dimmed.
#
# The row under the focus is lit (`stand`, tweened by UIMotion.stand()): a
# warm face fading to the right, a thin gold edge, a gold ring round the
# emblem. The slot whose choices are listed beside the rows (`chosen`) keeps
# a gold bar at its left and a fainter face while the focus is in the list.
# While a choice there is under the focus, the row tells what it would hold
# afterwards (`preview`: "→ 雷閃") in place of its figure. When what it holds
# has just changed, a gold ring runs round the emblem once and the emblem
# swells (`glow`, UIMotion.glow_in()).
#
# The button's styles are all empty (LoadoutSlot); it draws itself.

const DIAMETER := 80.0
const INSET := 20.0
const KEY_HEIGHT := 28.0
const KEY_OVERLAP := 5.0
const KEY_PAD := 18.0
const KEY_MIN := 34.0
const TEXT_GAP := 24.0
const LINE_GAP := 4.0
const BAR_WIDTH := 3.0
const RING_GAP := 5.0
const RING_WIDTH := 2.0
const DASHES := 28
const ARC_POINTS := 64
# The face a chosen row keeps while the focus is elsewhere, against the lit one.
const CHOSEN_FACE := 0.4
# The moment: the ring runs round over this share of it, then fades; the
# emblem swells by SEAT_RISE over its first half.
const SWEEP_SHARE := 0.55
const SEAT_RISE := 0.08

var emblem: Texture2D:
	set(value):
		emblem = value
		queue_redraw()
var key := "":
	set(value):
		key = value
		queue_redraw()
# The slot's name, what it holds and its short figure.
var title := ""
var content := ""
var note := ""
var preview := "":
	set(value):
		preview = value
		queue_redraw()
var empty := false
var sealed := false
# No hairline under the last row.
var last := false
var chosen := false:
	set(value):
		chosen = value
		queue_redraw()
# 0 rests, 1 lit under the focus.
var stand := 0.0:
	set(value):
		stand = value
		queue_redraw()
# 0 and 1 rest; between, the moment after an equip.
var glow := 0.0:
	set(value):
		glow = value
		queue_redraw()


func _init() -> void:
	theme_type_variation = &"LoadoutSlot"
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	focus_entered.connect(func(): UIMotion.of(self).stand(true))
	focus_exited.connect(func(): UIMotion.of(self).stand(false))


# The moment after what the slot holds has changed.
func celebrate() -> void:
	UIMotion.of(self).glow_in(UIMotion.MOMENT_TIME + UIMotion.GOLD_TIME)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var lit := clampf(stand, 0.0, 1.0)
	LoadoutSlot.paint_face(self, rect, maxf(lit, CHOSEN_FACE if chosen else 0.0), lit, not last)
	if chosen:
		draw_rect(Rect2(0.0, 0.0, BAR_WIDTH, size.y), get_theme_color(&"lit_ring"))
	# The slot as the HUD shows it: the emblem, its key under it.
	var radius := DIAMETER * 0.5
	var unit := DIAMETER + KEY_HEIGHT - KEY_OVERLAP
	var centre := Vector2(INSET + RING_GAP + radius, (size.y - unit) * 0.5 + radius)
	var moment := glow > 0.0 and glow < 1.0
	var swell := 1.0 + (SEAT_RISE * sin(PI * clampf(glow / 0.5, 0.0, 1.0)) if moment else 0.0)
	var tint := get_theme_color(&"sealed_tint") if sealed else Color.WHITE
	LoadoutSlot.paint_medallion(self, centre, radius * swell, emblem, tint, empty, false)
	var ring := get_theme_color(&"lit_ring")
	if lit > 0.0 or chosen:
		draw_arc(centre, radius + RING_GAP, 0.0, TAU, ARC_POINTS, Color(ring, maxf(lit, 0.45)), RING_WIDTH, true)
	if moment:
		var sweep := clampf(glow / SWEEP_SHARE, 0.0, 1.0)
		var fade := 1.0 - clampf((glow - SWEEP_SHARE) / (1.0 - SWEEP_SHARE), 0.0, 1.0)
		var flare := get_theme_color(&"sweep")
		draw_arc(centre, radius + RING_GAP, -PI * 0.5, -PI * 0.5 + TAU * sweep, ARC_POINTS, Color(flare, fade), RING_WIDTH + 2.0, true)
		draw_circle(centre, radius + RING_GAP + 8.0, Color(flare, 0.08 * fade))
	if not key.is_empty():
		LoadoutSlot.paint_key(self, Vector2(centre.x, centre.y + radius - KEY_OVERLAP), key, KEY_HEIGHT, lit > 0.5 or chosen)
	# Its name, what it holds, and its figure (or what it would hold).
	var font := get_theme_font(&"font")
	var name_font := get_theme_font(&"name_font")
	var small := get_theme_font_size(&"font_size")
	var big := get_theme_font_size(&"name_size")
	var left := centre.x + radius + RING_GAP + TEXT_GAP
	var width := maxf(1.0, size.x - left - 16.0)
	var small_height := font.get_height(small)
	var big_height := name_font.get_height(big)
	var top := (size.y - (small_height * 2.0 + big_height + LINE_GAP * 2.0)) * 0.5
	draw_string(font, Vector2(left, top + font.get_ascent(small)), title, HORIZONTAL_ALIGNMENT_LEFT, width, small, get_theme_color(&"title"))
	top += small_height + LINE_GAP
	var name_colour := get_theme_color(&"name_off") if empty or sealed else get_theme_color(&"name").lerp(get_theme_color(&"name_lit"), lit)
	draw_string(name_font, Vector2(left, top + name_font.get_ascent(big)), content, HORIZONTAL_ALIGNMENT_LEFT, width, big, name_colour)
	top += big_height + LINE_GAP
	if not preview.is_empty():
		draw_string(font, Vector2(left, top + font.get_ascent(small)), "→ " + preview, HORIZONTAL_ALIGNMENT_LEFT, width, small, get_theme_color(&"preview"))
	elif not note.is_empty():
		draw_string(font, Vector2(left, top + font.get_ascent(small)), note, HORIZONTAL_ALIGNMENT_LEFT, width, small, get_theme_color(&"note"))


# --- What the status page's rows share (LoadoutChoice draws with these) ---

# A row's face: warm at the left and fading to the right by `weight`, a thin
# gold edge by `edge`, a little warmth under the pointer, and a hairline
# under it.
static func paint_face(row: Button, rect: Rect2, weight: float, edge: float, underlined: bool) -> void:
	var face := row.get_theme_color(&"lit_face")
	var left := Color(face, face.a * weight)
	if row.get_draw_mode() in [DRAW_HOVER, DRAW_HOVER_PRESSED] and weight < 1.0:
		var hover := row.get_theme_color(&"hover_face")
		left = left.blend(Color(hover, hover.a * (1.0 - weight)))
	if left.a > 0.0:
		var right := Color(left, left.a * 0.2)
		row.draw_polygon(
			PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
			PackedColorArray([left, right, right, left]))
	if underlined:
		row.draw_line(Vector2(rect.position.x + 14.0, rect.end.y - 0.5), Vector2(rect.end.x - 14.0, rect.end.y - 0.5), row.get_theme_color(&"separator"), -1.0)
	if edge > 0.0:
		var gold := row.get_theme_color(&"lit_edge")
		row.draw_rect(rect.grow(-0.5), Color(gold, gold.a * edge), false, -1.0)


# An emblem in the round: the painted medallion itself, or, with none, a dark
# disc in a dashed ring (`slashed`: the choice that clears a slot).
static func paint_medallion(row: Button, centre: Vector2, radius: float, picture: Texture2D, tint: Color, dashed: bool, slashed: bool) -> void:
	if picture != null:
		row.draw_texture_rect(picture, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)
		return
	row.draw_circle(centre, radius, row.get_theme_color(&"disc"))
	if dashed or slashed:
		var dash := row.get_theme_color(&"empty_ring")
		var step := TAU / DASHES
		for index in DASHES:
			row.draw_arc(centre, radius - 2.0, index * step, index * step + step * 0.5, 6, dash, 1.5, true)
		if slashed:
			var reach := radius * 0.4
			row.draw_line(centre + Vector2(-reach, reach), centre + Vector2(reach, -reach), dash, 2.0, true)


# A key on the plate the HUD and the key guide use, its top edge centred on
# `top`; returns the plate's width.
static func paint_key(row: Button, top: Vector2, text: String, height: float, bright: bool) -> float:
	var font := row.get_theme_font(&"font")
	var font_size := row.get_theme_font_size(&"key_size")
	var width := maxf(KEY_MIN, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + KEY_PAD)
	var plate := Rect2(top.x - width * 0.5, top.y, width, height)
	row.draw_style_box(row.get_theme_stylebox(&"key_plate_lit" if bright else &"key_plate"), plate)
	var baseline := plate.position.y + (height + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	row.draw_string(font, Vector2(plate.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, row.get_theme_color(&"key_lit") if bright else row.get_theme_color(&"key"))
	return width
