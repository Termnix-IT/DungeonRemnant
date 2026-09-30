class_name StageCardList
extends ItemCardList


func _init() -> void:
	theme_type_variation = &"StageCardList"


# unlock_hint explains a locked stage ("古代遺跡をクリアで解放").
func add_stage(stage: StageData, unlocked: bool, unlock_hint: String = "") -> void:
	var index := add_item(stage.display_name)
	set_item_metadata(index, {"stage": stage, "unlocked": unlocked and stage.available, "hint": unlock_hint})
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
		# Locked and upcoming stages are dimmed and padlocked so they never
		# read as choosable; the second line says how to open them.
		var locked: bool = not row.unlocked
		if stage.illustration != null:
			var visual := Rect2(at, Vector2(116, rect.size.y - 28))
			var texture_size := stage.illustration.get_size()
			var crop_size := visual.size / maxf(visual.size.x / texture_size.x, visual.size.y / texture_size.y)
			draw_texture_rect_region(stage.illustration, visual, Rect2((texture_size - crop_size) / 2, crop_size), Color(0.42, 0.42, 0.45) if locked else Color.WHITE)
			if locked:
				_draw_padlock(visual.get_center())
			at.x += 132
		var width := rect.end.x - at.x - 14
		var dim: StringName = &"MutedLabel" if locked else &""
		_line(stage.display_name, at, width, &"HeadingLabel", HORIZONTAL_ALIGNMENT_LEFT, dim)
		var status := "今後追加予定"
		if stage.available:
			status = "全%d階  /  %s" % [stage.floor_count, stage.difficulty]
			if locked:
				status += "  /  " + (row.hint if not String(row.hint).is_empty() else "未解放")
		_line(status, at + Vector2(0, 36), width, &"GoldLabel", HORIZONTAL_ALIGNMENT_LEFT, dim if locked else &"Label")
		_line(stage.description, at + Vector2(0, 72), width, &"MutedLabel")
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus"), Rect2(Vector2.ZERO, size))


func _draw_padlock(center: Vector2) -> void:
	var color := get_theme_color(&"font_color", &"Label")
	draw_circle(center, 24, Color(0, 0, 0, 0.45))
	draw_arc(center + Vector2(0, -4), 7, PI, TAU, 16, color, 2.5, true)
	draw_rect(Rect2(center + Vector2(-10, -4), Vector2(20, 15)), color)
	draw_rect(Rect2(center + Vector2(-1.5, 1), Vector2(3, 6)), Color(0.08, 0.08, 0.1))
