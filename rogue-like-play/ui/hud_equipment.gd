class_name HudEquipment
extends Control

# Five equipped slots drawn as a slot box holding the item's icon, the slot
# caption and the item name. The main weapon's box is gold, and an empty box
# shows the faint symbol of what it accepts. Metrics and text size live in
# the Theme type HudEquipment.
const CAPTIONS := Equipment.SLOT_NAMES
const EMPTY := "—"

var items: Array[ItemData] = []


func _init() -> void:
	theme_type_variation = &"HudEquipment"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Icons are 2x pixel art drawn at a third of their size, so sample whole pixels.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# The rows' height follows the Theme metrics, so a Container never lays the
# next line over the last slot when those metrics change.
func _get_minimum_size() -> Vector2:
	return Vector2(0, get_theme_constant(&"row_height") * CAPTIONS.size())


func show_equipment(equipment: Equipment) -> void:
	show_slots(equipment.slots)


func show_slots(slots: Array) -> void:
	items.assign(slots)
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
	var muted := get_theme_color(&"font_color", &"HudCaption")
	var body := get_theme_color(&"font_color", &"Label")
	for index in CAPTIONS.size():
		var top := index * row_height
		var item: ItemData = items[index] if index < items.size() else null
		var box := _slot(index, Rect2(2, top + (row_height - glyph_size) / 2.0, glyph_size, glyph_size))
		var baseline := top + (row_height - font.get_height(font_size)) / 2.0
		var caption_x := box.end.x + 10
		_text(CAPTIONS[index], Vector2(caption_x, baseline), caption_width, muted)
		var name_x := caption_x + caption_width
		_text(_name(index), Vector2(name_x, baseline), size.x - name_x, body if item != null else muted)


# One slot box: the item's icon, or the faint symbol of what the slot takes.
# Returns the box so rows can place their text after it.
func _slot(index: int, glyph: Rect2) -> Rect2:
	var item: ItemData = items[index] if index < items.size() else null
	var muted := get_theme_color(&"font_color", &"HudCaption")
	var box := glyph.grow(2)
	draw_rect(box, Color(0, 0, 0, 0.35))
	draw_rect(box, get_theme_color(&"font_color", &"GoldLabel") if index == 0 and item != null else Color(muted, 0.35), false, 1.0)
	if item == null:
		ItemGlyph.paint(self, glyph.grow(-7), ItemGlyph.slot_symbol(index), Color(muted, 0.45))
	else:
		ItemGlyph.paint(self, glyph, item, get_theme_color(&"font_color", &"Label"))
	return box


func _text(value: String, at: Vector2, width: float, color: Color) -> void:
	if width <= 0:
		return
	var line := TextLine.new()
	line.add_string(value, get_theme_font(&"font"), get_theme_font_size(&"font_size"))
	line.width = width
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.draw(get_canvas_item(), at, color)
