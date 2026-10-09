class_name ItemDrag
extends RefCounted

# The shared grammar for moving items with the mouse, on every screen that
# shows items (docs/MVP_SPEC.md, 個別画面のUI文法):
# - any item's icon or row can be picked up; what follows the pointer is the
#   item's glyph in gold (preview);
# - while it is held, every place that would take it lights up (ItemCell does
#   this for itself; a column or a row gets a DropGlow);
# - dropping does what the place does when it can be undone (move, equip,
#   take off, swap, set a spell); where Gold would change hands (buying,
#   selling) it chooses the item there and waits on the trade's button;
# - dropping anywhere else does nothing.
# A drag's data is the ItemCell picked up, or, from a list row that is no
# cell, a Dictionary with at least "item".


# What follows the pointer: the item's glyph, centred on it.
static func preview(item: ItemData, extent: float, color: Color) -> Control:
	var holder := Control.new()
	var ghost := Control.new()
	ghost.size = Vector2.ONE * extent
	ghost.position = -ghost.size * 0.5
	ghost.draw.connect(func(): ItemGlyph.paint(ghost, Rect2(Vector2.ZERO, ghost.size), item, color))
	holder.add_child(ghost)
	return holder


# The item a drag's data carries, or null when it carries none.
static func item_of(data: Variant) -> ItemData:
	if data is ItemCell:
		return (data as ItemCell).item
	if data is Dictionary and (data as Dictionary).get("item") is ItemData:
		return data.item
	return null


# Lets root and everything inside it that takes the pointer receive drops:
# a drop over a button or a label in a column counts as a drop on the column.
# With pick (returning the drag's data, or null), the same place can also be
# picked up, from anywhere in it but its buttons.
static func accept_drops(root: Control, can_drop: Callable, drop: Callable, pick: Callable = Callable()) -> void:
	var targets: Array[Control] = [root]
	for child in root.find_children("*", "Control", true, false):
		if (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE and not child is ItemCell:
			targets.append(child)
	for target in targets:
		var lift := Callable()
		if pick.is_valid() and not target is BaseButton:
			lift = func(_at: Vector2) -> Variant: return pick.call(target)
		target.set_drag_forwarding(lift, func(_at: Vector2, data: Variant) -> bool: return can_drop.call(data), func(_at: Vector2, data: Variant) -> void: drop.call(data))


# Lights target up while something it would take is held.
static func glow(target: Control, accepts: Callable) -> DropGlow:
	var lit := DropGlow.new()
	lit.accepts = accepts
	target.add_child(lit)
	return lit


# A gilt outline and a faint warm wash over a place that would take what is
# held; drawn above the place, never in the way of the pointer. It stands
# outside its parent's layout (top level), so a row or a column that is a
# Container does not lay it out as one of its parts, and takes the parent's
# rect when a drag begins.
class DropGlow:
	extends Control

	var accepts: Callable
	var active := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN:
			var place := get_parent() as Control
			active = place != null and place.is_visible_in_tree() and accepts.is_valid() and accepts.call(get_viewport().gui_get_drag_data())
			if active:
				global_position = place.global_position
				size = place.size
			queue_redraw()
		elif what == NOTIFICATION_DRAG_END:
			active = false
			queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var gold := get_theme_color(&"font_color", &"GoldLabel")
		draw_rect(Rect2(Vector2.ZERO, size), Color(gold, 0.06))
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1), Color(gold, 0.7), false, 1.0)
