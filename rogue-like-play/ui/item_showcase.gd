class_name ItemShowcase
extends BoxContainer

# A row (art beside the text) by default; stack() turns it into a column.
# The spacing follows the matching container role of the shared Theme.

var visual: ItemVisual
var title: Label
var category: Label
var effect: Label


func _init() -> void:
	theme_type_variation = &"HBoxContainer"
	visual = ItemVisual.new()
	add_child(visual)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(copy)
	# The title wraps without a line limit, so the full name is always here
	# and the details below never need to repeat it.
	title = HubUI.label(copy, "選択したアイテム", &"HeadingLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	category = HubUI.label(copy, "", &"MutedLabel")
	effect = HubUI.label(copy, "", &"GoldLabel")
	effect.max_lines_visible = 2
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


# Stacks the art above centred text, at `extent` px, for a narrow column
# with height to spare (the equipment page). The row layout stays default.
func stack(extent: float) -> void:
	vertical = true
	theme_type_variation = &"VBoxContainer"
	visual.custom_minimum_size = Vector2(extent, extent)
	visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for label: Label in [title, category, effect]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func present(item: ItemData) -> void:
	visual.item = item
	title.text = item.label() if item != null else "アイテムを選択"
	category.text = ItemGlyph.category(item) if item != null else "一覧で詳細を確認できます"
	effect.text = ItemGlyph.main_effect(item) if item != null else ""
