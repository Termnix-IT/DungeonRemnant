class_name JustifiedButton
extends Button

# A button whose words are spread to a set width, a gap between each letter
# (均等割り付け), so a column of buttons with words of different lengths
# ("設定", "探索を中断する") reads as one even block, as many games' menus
# lay theirs out. The words are drawn here, letter by letter, in the
# button's own Theme font and state colours; `text` stays empty so the
# button draws no words of its own. A span narrower than the words leaves
# them at their natural spacing, and no gap grows past MAX_GAP_EMS letters,
# so a short word ("設定") stays one word rather than letters apart; it then
# stands centred, narrower than the span. align_spans() gives a set of
# buttons the span of the longest.

# The widest gap between two letters, in letters (the font size).
const MAX_GAP_EMS := 1.0

var caption := "":
	set(value):
		caption = value
		tooltip_text = value
		queue_redraw()
# The width the words are spread to, in pixels.
var span := 0.0:
	set(value):
		span = value
		queue_redraw()


# Every button's span set to the widest one's natural width.
static func align_spans(buttons: Array) -> void:
	var widest := 0.0
	for button: JustifiedButton in buttons:
		widest = maxf(widest, button.natural_width())
	for button: JustifiedButton in buttons:
		button.span = widest


func natural_width() -> float:
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var width := 0.0
	for letter in caption:
		width += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return width


# The gap between letters: what reaches the span, at most MAX_GAP_EMS.
func gap() -> float:
	var natural := natural_width()
	if caption.length() < 2 or span <= natural:
		return 0.0
	return minf((span - natural) / (caption.length() - 1), MAX_GAP_EMS * get_theme_font_size(&"font_size"))


# How wide the words are drawn.
func drawn_width() -> float:
	return natural_width() + gap() * maxi(caption.length() - 1, 0)


func _draw() -> void:
	if caption.is_empty():
		return
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var natural := natural_width()
	var spacing := gap()
	var x := (size.x - (natural + spacing * (caption.length() - 1))) * 0.5
	var baseline := (size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	var colour := _colour()
	var outline := get_theme_constant(&"outline_size")
	var outline_colour := get_theme_color(&"font_outline_color")
	for letter in caption:
		var at := Vector2(x, baseline)
		if outline > 0 and outline_colour.a > 0.0:
			draw_string_outline(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_colour)
		draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing


# The colour Button gives its words in the state it is in.
func _colour() -> Color:
	if disabled:
		return get_theme_color(&"font_disabled_color")
	match get_draw_mode():
		DRAW_PRESSED:
			return get_theme_color(&"font_pressed_color")
		DRAW_HOVER:
			return get_theme_color(&"font_hover_color")
		DRAW_HOVER_PRESSED:
			return get_theme_color(&"font_hover_pressed_color")
	if has_focus():
		return get_theme_color(&"font_focus_color")
	return get_theme_color(&"font_color")
