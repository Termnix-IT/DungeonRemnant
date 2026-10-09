class_name ItemCardList
extends ItemTooltipList

const OPEN_TIP := 18.0

var selection_strength := 1.0:
	set(value):
		selection_strength = value
		queue_redraw()


# Open rows on a list right of the details (the warehouse) point their band
# left, at the details, and arrive from the right.
var points_left := false

# 0 to 1 while the rows arrive (UIMotion.intro_rows); 1 when settled.
var intro := 1.0:
	set(value):
		intro = value
		queue_redraw()
# The arriving row being drawn: its fade, shared by every colour it uses.
var _row_alpha := 1.0

# Said in the middle of an empty list instead of leaving it blank.
var empty_text := "":
	set(value):
		empty_text = value
		queue_redraw()

# The shared drag grammar (ItemDrag) for a list whose rows are items: given
# a row's index, drag_row returns the drag's data (a Dictionary with "item"),
# or null where the row cannot be picked up; can_take and take receive what
# is dropped on the list.
var drag_row := Callable()
var can_take := Callable()
var take := Callable()


func _get_drag_data(at_position: Vector2) -> Variant:
	if not drag_row.is_valid():
		return null
	var index := get_item_at_position(at_position, true)
	if index < 0:
		return null
	var data: Variant = drag_row.call(index)
	var item := ItemDrag.item_of(data)
	if item == null:
		return null
	set_drag_preview(ItemDrag.preview(item, 48.0, get_theme_color(&"font_color", &"GoldLabel")))
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return can_take.is_valid() and can_take.call(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	take.call(data)


func _ready() -> void:
	# Made here, not first in _draw, where the tree must not change.
	UIMotion.of(self)
	item_selected.connect(_on_selected)


func _on_selected(_index: int) -> void:
	# An open row's band already on show slides to the new row; a first
	# selection fades in where it lands.
	if not (_open_rows() and UIMotion.of(self).has_mark()):
		UIMotion.of(self).select_card()


# The rows arrive top first, from the left. Call where the list's content
# changes for the player (a page opening, a new filter), not on refresh.
func play_intro() -> void:
	UIMotion.of(self).intro_rows(_visible_rows())


func _visible_rows() -> int:
	if item_count == 0:
		return 0
	var height := get_item_rect(0).size.y
	return mini(item_count, ceili(size.y / maxf(height, 1.0)))


# The first row in view, which arrives first.
func _first_row() -> int:
	if item_count == 0:
		return 0
	return floori(get_v_scroll_bar().value / maxf(get_item_rect(0).size.y, 1.0))


# Open rows (theme constant open_rows): no card round each row, only a faint
# rule between them; the chosen row is the lobby menu's warm band, pointed at
# its right end towards the details, with gold text.
func _open_rows() -> bool:
	return get_theme_constant(&"open_rows") > 0


func _draw_open_row(rect: Rect2, selected: bool, hovered: bool, last: bool) -> void:
	# The chosen row's band is drawn on its own, where it slides.
	if selected:
		return
	var rail := get_theme_color(&"rail", &"HubLobby")
	if hovered:
		draw_rect(rect, _faded(get_theme_color(&"open_hover")))
	if not last:
		var y := rect.end.y
		draw_polyline_colors(PackedVector2Array([Vector2(rect.position.x, y), Vector2(rect.get_center().x, y), Vector2(rect.end.x, y)]), PackedColorArray([Color(rail, 0.0), _faded(Color(rail, 0.22)), Color(rail, 0.0)]), 1.0, true)


# The warm band, pointed at its right end towards the details.
func _draw_band(rect: Rect2, strength: float) -> void:
	var rail := get_theme_color(&"rail", &"HubLobby")
	var band := get_theme_color(&"band", &"HubLobby")
	var tip := rect.end.x
	var middle := rect.get_center().y
	var outline := PackedVector2Array([rect.position, Vector2(tip - OPEN_TIP, rect.position.y), Vector2(tip, middle), Vector2(tip - OPEN_TIP, rect.end.y), Vector2(rect.position.x, rect.end.y)])
	if points_left:
		var start := rect.position.x
		outline = PackedVector2Array([Vector2(rect.end.x, rect.position.y), Vector2(start + OPEN_TIP, rect.position.y), Vector2(start, middle), Vector2(start + OPEN_TIP, rect.end.y), rect.end])
	draw_polygon(outline, PackedColorArray([Color(band, band.a * 0.5 * strength), Color(band, band.a * 1.6 * strength), Color(band, band.a * 1.8 * strength), Color(band, band.a * 1.6 * strength), Color(band, band.a * 0.5 * strength)]))
	draw_polyline_colors(outline, PackedColorArray([Color(rail, 0.0), Color(rail, 0.85 * strength), Color(rail, strength), Color(rail, 0.85 * strength), Color(rail, 0.0)]), 1.5, true)


# Rows come in from the side the band points away from.
func _arrival_side() -> float:
	return 1.0 if points_left else -1.0


func _faded(color: Color) -> Color:
	return Color(color, color.a * _row_alpha)


func draw_selection_accent(rect: Rect2) -> void:
	var color := get_theme_color(&"font_color", &"GoldLabel")
	color.a = 0.38 * selection_strength
	draw_rect(rect.grow(-2), color, false, 1.0)


func _init() -> void:
	theme_type_variation = &"ItemCardList"


func add_card(item: ItemData, count: int, price: int = -1, context: String = "") -> void:
	# Keep native text for incremental search and accessibility. Theme hides only
	# its drawing; ItemList still owns selection, focus, tooltips and scrolling.
	var index := add_item("%s  ×%d / %s / %d G" % [item.label(), count, ItemGlyph.category(item), price])
	set_item_metadata(index, {"item": item, "count": count, "price": price, "context": context})
	set_item_tooltip(index, description(item))


func card_rect(index: int) -> Rect2:
	var rect := get_item_rect(index)
	rect.position.y -= get_v_scroll_bar().value
	return rect


func _draw() -> void:
	var inset := get_theme_constant(&"card_inset")
	var glyph_size := get_theme_constant(&"glyph_size")
	var gap := get_theme_constant(&"card_gap")
	var motion := UIMotion.of(self)
	var chosen := get_selected_items()
	if _open_rows() and not chosen.is_empty() and get_item_metadata(chosen[0]) is Dictionary:
		# The band lives in the list's content, so it scrolls with the rows,
		# and it arrives with its row.
		var band := motion.follow_mark(get_item_rect(chosen[0]).grow_individual(-2, -2, -2, -get_theme_constant(&"row_gap")))
		band.position.y -= get_v_scroll_bar().value
		var arrival := UIMotion.row_arrival(intro, chosen[0] - _first_row(), _visible_rows())
		draw_set_transform(Vector2(_arrival_side() * UIMotion.ROW_DISTANCE * (1.0 - arrival), 0))
		_draw_band(band, clampf(selection_strength, 0.0, 1.0) * arrival)
		draw_set_transform(Vector2.ZERO)
	elif _open_rows():
		motion.drop_mark()
	for index in item_count:
		var rect := card_rect(index)
		if rect.size.x <= 0 or rect.size.y <= 0 or size.x <= 0 or size.y <= 0:
			continue
		if not rect.intersects(Rect2(Vector2.ZERO, size)):
			continue
		_row_alpha = UIMotion.row_arrival(intro, index - _first_row(), _visible_rows())
		draw_set_transform(Vector2(_arrival_side() * UIMotion.ROW_DISTANCE * (1.0 - _row_alpha), 0))
		var data: Variant = get_item_metadata(index)
		if not data is Dictionary:
			_line(get_item_text(index), rect.position + Vector2(inset, gap), rect.size.x - inset * 2, &"MutedLabel")
			continue
		rect = rect.grow_individual(-2, -2, -2, -get_theme_constant(&"row_gap"))
		var selected := is_selected(index)
		var hovered := rect.has_point(get_local_mouse_position())
		if _open_rows():
			_draw_open_row(rect, selected, hovered, index == item_count - 1)
			# Keep the text clear of the band's point.
			rect.size.x -= OPEN_TIP
			if points_left:
				rect.position.x += OPEN_TIP
		else:
			draw_style_box(get_theme_stylebox(&"card_selected" if selected else (&"card_hover" if hovered else &"card")), rect)
			if selected:
				draw_selection_accent(rect)
		var price_width := get_theme_constant(&"price_width" if data.price >= 0 else &"quantity_width")
		var glyph := Rect2(rect.position + Vector2(inset, (rect.size.y - glyph_size) / 2.0), Vector2.ONE * glyph_size)
		var color := get_theme_color(&"font_color", &"GoldLabel" if is_selected(index) else &"Label")
		ItemGlyph.paint(self, glyph, data.item, _faded(color))
		var text_x := glyph.end.x + gap
		var price_x := rect.end.x - inset - price_width
		var text_width := maxf(0, price_x - gap - text_x)
		var top := rect.position.y + gap
		_line(data.item.label(), Vector2(text_x, top), text_width, &"ItemNameLabel")
		var second := top + get_theme_font(&"font").get_height(get_theme_font_size(&"font_size", &"ItemNameLabel")) + 2
		_line(ItemGlyph.main_effect(data.item), Vector2(text_x, second), text_width, &"MutedLabel")
		# A row's price reads in the body colour; gold is kept for the
		# selection and the money that the choice now spends.
		_line(UIFormat.gold(data.price) if data.price >= 0 else "×%d" % data.count, Vector2(price_x, top), price_width, &"GoldLabel", HORIZONTAL_ALIGNMENT_RIGHT, &"GoldLabel" if selected else &"Label")
		_line("所持 ×%d" % data.count if data.price >= 0 else data.get("context", ""), Vector2(price_x, second), price_width, &"MutedLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_row_alpha = 1.0
	draw_set_transform(Vector2.ZERO)
	if item_count == 0 and not empty_text.is_empty():
		_line(empty_text, Vector2(0, size.y * 0.5 - 12), size.x, &"MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus"), Rect2(Vector2.ZERO, size))


# color_role, when set, keeps the role's size but borrows another role's colour.
func _line(value: String, at: Vector2, width: float, role: StringName, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, color_role: StringName = &"") -> void:
	if width <= 0:
		return
	var line := TextLine.new()
	line.add_string(value, get_theme_font(&"font"), get_theme_font_size(&"font_size", role))
	line.width = width
	line.alignment = alignment
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if color_role.is_empty():
		color_role = role if has_theme_color(&"font_color", role) else &"Label"
	line.draw(get_canvas_item(), at, _faded(get_theme_color(&"font_color", color_role)))
