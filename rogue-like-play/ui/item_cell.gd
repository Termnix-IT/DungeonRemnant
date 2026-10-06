class_name ItemCell
extends Button

# One square of an inventory: an item's icon alone, a count in its corner. An
# empty equipment slot is the same square with the faint symbol of what it
# accepts. The square is also the hold for drag and drop: a cell with an item
# can be picked up, and a cell whose can_accept says yes takes what is dropped.
# Appearance (the surface, the gold of the chosen one) belongs to the Theme.

signal dropped(source: ItemCell)

const SIZE := 72.0
# The icons are 48px art: drawn at that size they stay crisp.
const ICON := 48.0

var item: ItemData
# An empty slot's stand-in (ItemGlyph.slot_symbol) drawn faintly.
var symbol: ItemData
var count := 1
var draggable := true
# Called with the source cell; says whether a drop here would be taken.
var can_accept := Callable()
# True when the item held for equipping does not fit this cell.
var dimmed := false:
	set(value):
		dimmed = value
		queue_redraw()


func _init() -> void:
	theme_type_variation = &"ItemCell"
	custom_minimum_size = Vector2.ONE * SIZE
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL


func show_item(value: ItemData, amount: int = 1) -> void:
	item = value
	count = amount
	queue_redraw()


func _draw() -> void:
	var shown := item if item != null else symbol
	if shown == null:
		return
	var rect := Rect2((size - Vector2.ONE * ICON) * 0.5, Vector2.ONE * ICON)
	var role := &"GoldLabel" if button_pressed and item != null else &"Label"
	var color := get_theme_color(&"font_color", role if item != null else &"NoteLabel")
	if item == null:
		rect = Rect2((size - Vector2.ONE * ICON * 0.6) * 0.5, Vector2.ONE * ICON * 0.6)
	if dimmed:
		color.a *= 0.35
	ItemGlyph.paint(self, rect, shown, color)
	if item != null and count > 1:
		var font := get_theme_font(&"font", &"Label")
		var font_size := get_theme_font_size(&"font_size", &"MutedLabel")
		var text := "×%d" % count
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(size.x - width - 6, size.y - 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color(&"font_color", &"Label"))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null or not draggable or disabled:
		return null
	var held := item
	var extent := Vector2.ONE * ICON
	var preview := Control.new()
	var ghost := Control.new()
	ghost.size = extent
	ghost.position = -extent * 0.5
	var color := get_theme_color(&"font_color", &"GoldLabel")
	ghost.draw.connect(func(): ItemGlyph.paint(ghost, Rect2(Vector2.ZERO, extent), held, color))
	preview.add_child(ghost)
	set_drag_preview(preview)
	return self


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is ItemCell and data != self and can_accept.is_valid() and can_accept.call(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(data as ItemCell)
