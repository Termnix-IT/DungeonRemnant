class_name ItemCell
extends Button

# One square of an inventory: an item's icon alone, a count in its corner. An
# empty equipment slot is the same square with the faint symbol of what it
# accepts. The square is also the hold for drag and drop: a cell with an item
# can be picked up, and a cell whose can_accept says yes takes what is dropped.
# Appearance (the surface, the gold of the chosen one) belongs to the Theme.

signal dropped(source: ItemCell)
# A right click: the menu of what can be done with this cell, at the pointer.
signal context_requested(at: Vector2)

const SIZE := 72.0
# The icons are 96px art: drawn at 48 or at 96 they stay crisp.
const ICON := 48.0
# The warm light behind an icon: faint at rest, brighter under the pointer or
# the focus, strongest while it is the chosen one.
const GLOW_COLOR := Color(1.0, 0.72, 0.4)
const GLOW_REST := 0.16
const GLOW_ACTIVE := 0.34
const GLOW_CHOSEN := 0.52

static var _glow: GradientTexture2D

var item: ItemData
# An empty slot's stand-in (ItemGlyph.slot_symbol) drawn faintly.
var symbol: ItemData
var count := 1
var draggable := true
# The icon's drawn size; a big cell sets 96 to show the art at its own size.
var icon_size := ICON
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
	if _glow == null:
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = fade
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func show_item(value: ItemData, amount: int = 1) -> void:
	item = value
	count = amount
	queue_redraw()


func _draw() -> void:
	if button_pressed:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-3), get_theme_color(&"font_color", &"GoldLabel"), false, 2.0)
	var shown := item if item != null else symbol
	if shown == null:
		return
	var extent := icon_size if item != null else icon_size * 0.6
	var rect := Rect2((size - Vector2.ONE * extent) * 0.5, Vector2.ONE * extent)
	if item != null and not dimmed:
		var strength := GLOW_CHOSEN if button_pressed else (GLOW_ACTIVE if (is_hovered() or has_focus()) else GLOW_REST)
		draw_texture_rect(_glow, Rect2(rect.position - rect.size * 0.35, rect.size * 1.7), false, Color(GLOW_COLOR, strength))
	var role := &"GoldLabel" if button_pressed and item != null else &"Label"
	var color := get_theme_color(&"font_color", role if item != null else &"NoteLabel")
	if dimmed:
		color.a *= 0.35
	ItemGlyph.paint(self, rect, shown, color)
	if item != null and count > 1:
		var font := get_theme_font(&"font", &"Label")
		var font_size := get_theme_font_size(&"font_size", &"MutedLabel")
		var text := "×%d" % count
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(size.x - width - 6, size.y - 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color(&"font_color", &"Label"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		context_requested.emit(get_global_mouse_position())


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null or not draggable or disabled:
		return null
	var held := item
	var extent := Vector2.ONE * icon_size
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
