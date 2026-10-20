class_name HudWeapons
extends Control

# The two weapons the hero carries, beside the level in the vitals plate: the
# one in hand first in a gold box, the other in a faint one. Tab swaps them,
# and the boxes trade places with a small pulse. An empty second slot shows the
# faint weapon symbol. The names are the tooltip; range and the rest are in
# the inventory (I).
const BOX := 40.0
const GAP := 8.0
# The glyph sits this far inside its box.
const INSET := 4.0

var held: ItemData
var spare: ItemData


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Painted icons are drawn far below their size; sample them smoothly.
	texture_filter = ItemIcons.filter()


func _get_minimum_size() -> Vector2:
	return Vector2(BOX * 2 + GAP, BOX)


func show_weapons(main: ItemData, sub: ItemData) -> void:
	if main == held and sub == spare:
		return
	# A swap, not the first showing or a new weapon worn.
	var swapped := held != null and main == spare and sub == held
	held = main
	spare = sub
	tooltip_text = "%s: %s\n%s: %s" % [Equipment.SLOT_NAMES[0], _name(held), Equipment.SLOT_NAMES[1], _name(spare)]
	queue_redraw()
	if swapped:
		UIMotion.of(self).pulse(1.08, 0.2)


func _name(item: ItemData) -> String:
	return item.label() if item != null else HudEquipment.EMPTY


func _draw() -> void:
	var gold := get_theme_color(&"font_color", &"GoldLabel")
	var muted := get_theme_color(&"font_color", &"HudCaption")
	var body := get_theme_color(&"font_color", &"Label")
	for index in 2:
		var item := held if index == 0 else spare
		var box := Rect2(index * (BOX + GAP), 0, BOX, BOX)
		draw_rect(box, Color(0, 0, 0, 0.45))
		draw_rect(box, gold if index == 0 and item != null else Color(muted, 0.45), false, 2.0 if index == 0 else 1.0)
		if item == null:
			ItemGlyph.paint(self, box.grow(-INSET - 7), ItemGlyph.slot_symbol(Equipment.Slot.SUB), Color(muted, 0.45))
		else:
			ItemGlyph.paint(self, box.grow(-INSET), item, body)
