class_name TabUnderline
extends RefCounted

# The chosen text tab's gold underline (CategoryTab and its variations), drawn
# by the row that holds the tabs, under them, so it can slide from the last
# chosen tab to the next (UIMotion.follow_mark). The tabs' own chosen style
# carries no line.


static func attach(row: Container) -> void:
	UIMotion.of(row)
	row.draw.connect(_draw.bind(row))
	row.sort_children.connect(row.queue_redraw)
	# A tab redraws when it is chosen, also without its signal.
	for child in row.get_children():
		_watch(row, child)
	row.child_entered_tree.connect(func(child: Node): _watch(row, child))


static func _watch(row: Container, child: Node) -> void:
	# Moving the row between parents brings its tabs in again.
	if child is Button and not child.draw.is_connected(row.queue_redraw):
		child.draw.connect(row.queue_redraw)


static func _draw(row: Container) -> void:
	var chosen: Button = null
	for child in row.get_children():
		if child is Button and child.toggle_mode and child.button_pressed and child.visible:
			chosen = child
	if chosen == null:
		UIMotion.of(row).drop_mark()
		return
	var width := chosen.get_theme_constant(&"underline_width")
	var line := Rect2(chosen.position.x, chosen.position.y + chosen.size.y - width, chosen.size.x, width)
	row.draw_rect(UIMotion.of(row).follow_mark(line), chosen.get_theme_color(&"underline"))
