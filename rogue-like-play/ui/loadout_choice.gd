class_name LoadoutChoice
extends Button

# One thing the chosen slot can hold, a row in the status page's list
# (HubStatus): its emblem small at the left, its name over a short figure
# ("再使用 6秒"), and at the right where it stands now (`state`): what the
# chosen slot holds carries a gold diamond and "装備中"; a skill set in the
# other skill slot, that slot's key on its plate and "装備中"; a thing not
# learned yet is its emblem's shadow named "？？？" and marked "未所持". The
# first row of a slot that can be emptied clears it (`clears`: a dashed ring
# with a slash). A row whose Enter would change nothing is dimmed (`idle`).
#
# The row under the focus is lit as the slots' rows are (`stand`); it draws
# with LoadoutSlot's face, medallion and key plate, and takes its colours
# from the same theme type (LoadoutChoice is a LoadoutSlot).

enum State { FREE, HELD, ELSEWHERE, UNKNOWN }

const DIAMETER := 44.0
const INSET := 14.0
const TEXT_GAP := 16.0
const LINE_GAP := 2.0
const KEY_HEIGHT := 24.0
const MARK := 5.0
const TAG_GAP := 8.0
const IDLE_FADE := 0.45

var emblem: Texture2D
var title := ""
var note := ""
var state := State.FREE
# The words at the right ("装備中", "未所持"), and the other slot's key.
var tag := ""
var key := ""
var clears := false
var idle := false
var stand := 0.0:
	set(value):
		stand = value
		queue_redraw()


func _init() -> void:
	theme_type_variation = &"LoadoutChoice"
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	focus_entered.connect(func(): UIMotion.of(self).stand(true))
	focus_exited.connect(func(): UIMotion.of(self).stand(false))


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var lit := clampf(stand, 0.0, 1.0)
	LoadoutSlot.paint_face(self, rect, lit, lit, true)
	var unknown := state == State.UNKNOWN
	var fade := IDLE_FADE if idle and not unknown else 1.0
	var radius := DIAMETER * 0.5
	var centre := Vector2(INSET + radius, size.y * 0.5)
	var tint := get_theme_color(&"unknown_tint") if unknown else Color(1.0, 1.0, 1.0, fade)
	LoadoutSlot.paint_medallion(self, centre, radius, emblem, tint, clears, clears)
	if lit > 0.0 and not clears:
		var ring := get_theme_color(&"lit_ring")
		draw_arc(centre, radius + 3.0, 0.0, TAU, 48, Color(ring, lit), 1.5, true)
	var font := get_theme_font(&"font")
	var name_font := get_theme_font(&"name_font")
	var small := get_theme_font_size(&"font_size")
	var big := get_theme_font_size(&"name_size")
	# Where it stands now, from the right edge inwards.
	var right := size.x - INSET
	if not tag.is_empty():
		var colour := get_theme_color(&"preview") if state == State.HELD else get_theme_color(&"note")
		var tag_width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		right -= tag_width
		draw_string(font, Vector2(right, (size.y + font.get_ascent(small) - font.get_descent(small)) * 0.5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, small, colour)
		right -= TAG_GAP
	if state == State.HELD:
		var mark := Vector2(right - MARK, size.y * 0.5)
		HubUI.diamond(self, mark, MARK + 1.5, get_theme_color(&"mark_edge"))
		HubUI.diamond(self, mark, MARK, get_theme_color(&"lit_ring"))
		right -= MARK * 2.0 + TAG_GAP
	elif state == State.ELSEWHERE and not key.is_empty():
		var key_font_size := get_theme_font_size(&"key_size")
		var plate := maxf(LoadoutSlot.KEY_MIN, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, key_font_size).x + LoadoutSlot.KEY_PAD)
		LoadoutSlot.paint_key(self, Vector2(right - plate * 0.5, (size.y - KEY_HEIGHT) * 0.5), key, KEY_HEIGHT, false)
		right -= plate + TAG_GAP
	# Its name over its figure.
	var left := centre.x + radius + TEXT_GAP
	var width := maxf(1.0, right - left)
	var lines := name_font.get_height(big) + (font.get_height(small) + LINE_GAP if not note.is_empty() else 0.0)
	var top := (size.y - lines) * 0.5
	var name_colour := get_theme_color(&"name_off") if unknown else get_theme_color(&"name").lerp(get_theme_color(&"name_lit"), lit)
	draw_string(name_font, Vector2(left, top + name_font.get_ascent(big)), title, HORIZONTAL_ALIGNMENT_LEFT, width, big, Color(name_colour, name_colour.a * fade))
	if not note.is_empty():
		top += name_font.get_height(big) + LINE_GAP
		var note_colour := get_theme_color(&"note")
		draw_string(font, Vector2(left, top + font.get_ascent(small)), note, HORIZONTAL_ALIGNMENT_LEFT, width, small, Color(note_colour, note_colour.a * fade))
