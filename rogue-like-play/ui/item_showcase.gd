class_name ItemShowcase
extends HBoxContainer

var visual: ItemVisual
var title: Label
var category: Label
var effect: Label


func _init() -> void:
	visual = ItemVisual.new()
	add_child(visual)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(copy)
	title = HubUI.label(copy, "選択したアイテム", &"HeadingLabel")
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	category = HubUI.label(copy, "", &"MutedLabel")
	effect = HubUI.label(copy, "", &"GoldLabel")
	effect.max_lines_visible = 2
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func present(item: ItemData) -> void:
	visual.item = item
	title.text = item.label() if item != null else "アイテムを選択"
	category.text = ItemGlyph.category(item) if item != null else "一覧で詳細を確認できます"
	effect.text = ItemGlyph.main_effect(item) if item != null else ""
