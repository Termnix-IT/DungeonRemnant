class_name HudEquipment
extends Control

# Five equipped slots drawn as glyph, slot caption and item name. Row metrics
# and text size live in the Theme type HudEquipment.
const CAPTIONS := ["Main", "Sub", "防具", "装飾 1", "装飾 2"]
const EMPTY := "—"

var items: Array[ItemData] = []


func _init() -> void:
	theme_type_variation = &"HudEquipment"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_equipment(equipment: Equipment) -> void:
	items.assign(equipment.slots)
	var lines: Array[String] = []
	for index in CAPTIONS.size():
		lines.append("%s: %s" % [CAPTIONS[index], _name(index)])
	tooltip_text = "\n".join(lines)
	queue_redraw()


func row_text(index: int) -> String:
	return _name(index)


func _name(index: int) -> String:
	var item: ItemData = items[index] if index < items.size() else null
	return item.label() if item != null else EMPTY


func _draw() -> void:
	var row_height := get_theme_constant(&"row_height")
	var glyph_size := get_theme_constant(&"glyph_size")
	var caption_width := get_theme_constant(&"caption_width")
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var gold := get_theme_color(&"font_color", &"GoldLabel")
	var muted := get_theme_color(&"font_color", &"HudCaption")
	var body := get_theme_color(&"font_color", &"Label")
	for index in CAPTIONS.size():
		var top := index * row_height
		var item: ItemData = items[index] if index < items.size() else null
		var glyph := Rect2(0, top + (row_height - glyph_size) / 2.0, glyph_size, glyph_size)
		if item != null:
			ItemGlyph.paint(self, glyph, item, gold if index == 0 else muted)
		var baseline := top + (row_height - font.get_height(font_size)) / 2.0
		_text(CAPTIONS[index], Vector2(glyph_size + 10, baseline), caption_width, muted)
		var name_x := glyph_size + 10 + caption_width
		_text(_name(index), Vector2(name_x, baseline), size.x - name_x, body if item != null else muted)


func _text(value: String, at: Vector2, width: float, color: Color) -> void:
	if width <= 0:
		return
	var line := TextLine.new()
	line.add_string(value, get_theme_font(&"font"), get_theme_font_size(&"font_size"))
	line.width = width
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.draw(get_canvas_item(), at, color)
