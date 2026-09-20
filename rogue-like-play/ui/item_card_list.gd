class_name ItemCardList
extends ItemTooltipList


func _init() -> void:
	theme_type_variation = &"ItemCardList"


func add_card(item: ItemData, count: int, price: int) -> void:
	# Keep native text for incremental search and accessibility. Theme hides only
	# its drawing; ItemList still owns selection, focus, tooltips and scrolling.
	var index := add_item("%s  ×%d / %s / %d Gold" % [item.label(), count, ItemGlyph.category(item), price])
	set_item_metadata(index, {"item": item, "count": count, "price": price})
	set_item_tooltip(index, description(item))


func card_rect(index: int) -> Rect2:
	var rect := get_item_rect(index)
	rect.position.y -= get_v_scroll_bar().value
	return rect


func _draw() -> void:
	var inset := get_theme_constant(&"card_inset")
	var glyph_size := get_theme_constant(&"glyph_size")
	var gap := get_theme_constant(&"card_gap")
	var price_width := get_theme_constant(&"price_width")
	for index in item_count:
		var rect := card_rect(index)
		if not rect.intersects(Rect2(Vector2.ZERO, size)):
			continue
		var data: Variant = get_item_metadata(index)
		if not data is Dictionary:
			_line(get_item_text(index), rect.position + Vector2(inset, gap), rect.size.x - inset * 2, &"MutedLabel")
			continue
		var glyph := Rect2(rect.position + Vector2(inset, (rect.size.y - glyph_size) / 2.0), Vector2.ONE * glyph_size)
		var color := get_theme_color(&"font_color", &"GoldLabel" if is_selected(index) else &"Label")
		ItemGlyph.paint(self, glyph, data.item, color)
		var text_x := glyph.end.x + gap
		var price_x := rect.end.x - inset - price_width
		var text_width := maxf(0, price_x - gap - text_x)
		var top := rect.position.y + gap
		_line(data.item.label(), Vector2(text_x, top), text_width, &"BodyLabel")
		var second := top + get_theme_font(&"font").get_height(get_theme_font_size(&"font_size", &"BodyLabel"))
		_line("%s  /  所持 ×%d" % [ItemGlyph.category(data.item), data.count], Vector2(text_x, second), text_width, &"MutedLabel")
		_line("%d Gold" % data.price, Vector2(price_x, top), price_width, &"GoldLabel", HORIZONTAL_ALIGNMENT_RIGHT)
		_line("単価", Vector2(price_x, second), price_width, &"MutedLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus"), Rect2(Vector2.ZERO, size))


func _line(value: String, at: Vector2, width: float, role: StringName, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if width <= 0:
		return
	var line := TextLine.new()
	line.add_string(value, get_theme_font(&"font"), get_theme_font_size(&"font_size", role))
	line.width = width
	line.alignment = alignment
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var color_role := role if has_theme_color(&"font_color", role) else &"Label"
	line.draw(get_canvas_item(), at, get_theme_color(&"font_color", color_role))
