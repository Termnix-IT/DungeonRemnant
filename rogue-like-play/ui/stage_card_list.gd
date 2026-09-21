class_name StageCardList
extends ItemCardList


func _init() -> void:
	theme_type_variation = &"StageCardList"


func add_stage(stage: StageData, unlocked: bool) -> void:
	var index := add_item(stage.display_name)
	set_item_metadata(index, {"stage": stage, "unlocked": unlocked})
	set_item_tooltip(index, stage.display_name + "\n" + stage.description)


func _draw() -> void:
	for index in item_count:
		var rect := card_rect(index)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		if not rect.intersects(Rect2(Vector2.ZERO, size)):
			continue
		rect = rect.grow_individual(-2, -2, -2, -8)
		var row: Dictionary = get_item_metadata(index)
		var stage: StageData = row.stage
		draw_style_box(get_theme_stylebox(&"card_selected" if is_selected(index) else &"card"), rect)
		if is_selected(index):
			draw_selection_accent(rect)
		var at := rect.position + Vector2(14, 14)
		if stage.illustration != null:
			var visual := Rect2(at, Vector2(116, rect.size.y - 28))
			var texture_size := stage.illustration.get_size()
			var crop_size := visual.size / maxf(visual.size.x / texture_size.x, visual.size.y / texture_size.y)
			draw_texture_rect_region(stage.illustration, visual, Rect2((texture_size - crop_size) / 2, crop_size))
			at.x += 132
		var width := rect.end.x - at.x - 14
		_line(stage.display_name, at, width, &"HeadingLabel")
		_line("全%d階  /  %s%s" % [stage.floor_count, stage.difficulty, "" if row.unlocked else "  /  未解放"] if stage.available else "今後追加予定", at + Vector2(0, 36), width, &"GoldLabel")
		_line(stage.description, at + Vector2(0, 72), width, &"MutedLabel")
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus"), Rect2(Vector2.ZERO, size))
