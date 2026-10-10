class_name HudEffects
extends Panel

# Active talismans and scrolls in the HUD's top-left corner, as small tokens
# three to a row: each the item's glyph and its turns left ("この階" for one
# that lasts the floor). The names are the panel's tooltip. They were once a
# row each with the full name, a tall list that covered a quarter of the
# floor on the left; the glyph already tells the talismans apart.

const PADDING := Vector2(14, 10)
const CAPTION := "効果中"
const FLOOR_ONLY := "この階"
const COLUMNS := 3
const TOKEN_HEIGHT := 36.0
const CAPTION_HEIGHT := 22.0

var entries: Array[Dictionary] = []


func _init() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_entries(active: Array[Dictionary]) -> void:
	entries = active
	visible = not entries.is_empty()
	var rows := ceili(entries.size() / float(COLUMNS))
	custom_minimum_size.y = PADDING.y * 2 + CAPTION_HEIGHT + TOKEN_HEIGHT * rows
	size.y = custom_minimum_size.y
	var lines: Array[String] = []
	for entry: Dictionary in entries:
		lines.append("%s：%s" % [entry.item.display_name, _remaining(entry)])
	tooltip_text = "\n".join(lines)
	queue_redraw()


func _remaining(entry: Dictionary) -> String:
	return "%d" % entry.remaining if entry.remaining > 0 else FLOOR_ONLY


func _draw() -> void:
	var glyph_size := get_theme_constant(&"glyph_size", &"HudEquipment")
	var font := get_theme_font(&"font", &"HudEquipment")
	var font_size := get_theme_font_size(&"font_size", &"HudEquipment")
	var gold := get_theme_color(&"font_color", &"GoldLabel")
	var muted := get_theme_color(&"font_color", &"HudCaption")
	var width := size.x - PADDING.x * 2
	var token_width := width / COLUMNS
	draw_string(font, PADDING + Vector2(0, font.get_ascent(font_size)), CAPTION, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, muted)
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var origin := PADDING + Vector2(token_width * (index % COLUMNS), CAPTION_HEIGHT + TOKEN_HEIGHT * floori(index / float(COLUMNS)))
		var glyph := Rect2(origin + Vector2(0, (TOKEN_HEIGHT - glyph_size) / 2.0), Vector2.ONE * glyph_size)
		ItemGlyph.paint(self, glyph, entry.item, gold)
		# Turns left warm toward red in the last few turns.
		var urgent: bool = entry.remaining > 0 and entry.remaining <= 5
		var remaining_color := get_theme_color(&"font_color", &"HpCaption") if urgent else muted
		var baseline := origin.y + (TOKEN_HEIGHT - font.get_height(font_size)) / 2.0 + font.get_ascent(font_size)
		draw_string(font, Vector2(glyph.end.x + 6, baseline), _remaining(entry), HORIZONTAL_ALIGNMENT_LEFT, token_width - glyph_size - 8, font_size, remaining_color)
