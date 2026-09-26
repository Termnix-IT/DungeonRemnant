class_name HudEffects
extends Panel

# Active talismans and scrolls as a small HUD panel under the floor/Gold panel:
# glyph, name and remaining turns per row. Metrics come from the HudEquipment
# Theme type so both HUD lists share one row rhythm.
const PADDING := Vector2(14, 10)
const CAPTION := "効果中"
const FLOOR_ONLY := "この階"

var entries: Array[Dictionary] = []


func _init() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_entries(active: Array[Dictionary]) -> void:
	entries = active
	visible = not entries.is_empty()
	var row_height := get_theme_constant(&"row_height", &"HudEquipment")
	custom_minimum_size.y = PADDING.y * 2 + row_height * (entries.size() + 1)
	size.y = custom_minimum_size.y
	var lines: Array[String] = []
	for entry: Dictionary in entries:
		lines.append("%s：%s" % [entry.item.display_name, _remaining(entry)])
	tooltip_text = "\n".join(lines)
	queue_redraw()


func _remaining(entry: Dictionary) -> String:
	return "残り%d" % entry.remaining if entry.remaining > 0 else FLOOR_ONLY


func _draw() -> void:
	var row_height := get_theme_constant(&"row_height", &"HudEquipment")
	var glyph_size := get_theme_constant(&"glyph_size", &"HudEquipment")
	var font := get_theme_font(&"font", &"HudEquipment")
	var font_size := get_theme_font_size(&"font_size", &"HudEquipment")
	var gold := get_theme_color(&"font_color", &"GoldLabel")
	var muted := get_theme_color(&"font_color", &"HudCaption")
	var body := get_theme_color(&"font_color", &"Label")
	var width := size.x - PADDING.x * 2
	var baseline_offset := (row_height - font.get_height(font_size)) / 2.0 + font.get_ascent(font_size)
	draw_string(font, PADDING + Vector2(0, baseline_offset), CAPTION, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, muted)
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var top := PADDING.y + row_height * (index + 1)
		var glyph := Rect2(PADDING.x, top + (row_height - glyph_size) / 2.0, glyph_size, glyph_size)
		ItemGlyph.paint(self, glyph, entry.item, gold)
		var remaining := _remaining(entry)
		# Turns left warm toward red in the last few turns.
		var urgent: bool = entry.remaining > 0 and entry.remaining <= 5
		var remaining_color := get_theme_color(&"font_color", &"HpCaption") if urgent else muted
		draw_string(font, Vector2(PADDING.x, top + baseline_offset), remaining, HORIZONTAL_ALIGNMENT_RIGHT, width, font_size, remaining_color)
		var name_x := PADDING.x + glyph_size + 10
		var name_width := width - glyph_size - 10 - font.get_string_size(remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - 8
		var line := TextLine.new()
		line.add_string(entry.item.display_name, font, font_size)
		line.width = name_width
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.draw(get_canvas_item(), Vector2(name_x, top + (row_height - line.get_size().y) / 2.0), body)
