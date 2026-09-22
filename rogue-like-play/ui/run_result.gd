extends CanvasLayer

signal retry_requested
signal abort_confirmed
signal abort_cancelled

var confirming := false
var return_to_hub := false
var title_label: Label
var details: Label
var accept: Button
var cancel: Button
var save_label: Label
var presentation_panel: PanelContainer
var details_scroll: ScrollContainer


func _ready() -> void:
	layer = 12
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	presentation_panel = PanelContainer.new()
	presentation_panel.theme = preload("res://ui/theme/dungeon_theme.tres")
	presentation_panel.theme_type_variation = &"MainPanel"
	presentation_panel.custom_minimum_size.x = 730
	center.add_child(presentation_panel)
	var margin := MarginContainer.new()
	presentation_panel.add_child(margin)
	var panel := VBoxContainer.new()
	panel.name = "Panel"
	margin.add_child(panel)
	title_label = Label.new()
	title_label.theme_type_variation = &"TitleLabel"
	panel.add_child(title_label)
	details = Label.new()
	details.theme_type_variation = &"DescriptionLabel"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll = ScrollContainer.new()
	details_scroll.custom_minimum_size.y = 270
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(details_scroll)
	details_scroll.add_child(details)
	accept = Button.new()
	accept.theme_type_variation = &"PrimaryButton"
	accept.custom_minimum_size.y = 44
	accept.focus_mode = Control.FOCUS_NONE
	accept.pressed.connect(_accept)
	panel.add_child(accept)
	cancel = Button.new()
	cancel.theme_type_variation = &"SecondaryButton"
	cancel.text = "探索に戻る（Esc）"
	cancel.custom_minimum_size.y = 44
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): abort_cancelled.emit())
	panel.add_child(cancel)
	save_label = Label.new()
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_label.theme_type_variation = &"MutedLabel"
	panel.add_child(save_label)
	UIMotion.bind_buttons(panel)
	hide()


func show_save_status(message: String) -> void:
	save_label.text = message


func present(result: Dictionary) -> void:
	save_label.text = ""
	confirming = false
	title_label.text = "冒険クリア" if result.cleared else ("無事に帰還" if result.get("safe_return", false) else ("滞在上限：強制帰還" if result.get("forced_return", false) else "冒険終了"))
	var losses: PackedStringArray = []
	for label: String in result.items_lost:
		losses.append("%s ×%d" % [label, result.items_lost[label]])
	details.text = "到達階：%dF\n今回獲得：%d Gold\n失ったGold：%d　／　残り：%d\n失ったアイテム：%d個\n%s\n\n装備中の5枠は保持されます。" % [result.floor, result.earned_gold, result.gold_lost, result.gold, result.item_count_lost, "、".join(losses) if not losses.is_empty() else "なし"]
	accept.text = "拠点へ戻る（R）" if return_to_hub else "Lv1から再挑戦（R）"
	cancel.hide()
	show()
	_reveal()


func confirm_abort() -> void:
	save_label.text = ""
	confirming = true
	title_label.text = "冒険を中断しますか？"
	details.text = "死亡時と同じペナルティが適用されます。\n\n・所持Goldの50%を失います。\n・非装備の所持枠の半数をランダムに失います（切り上げ）。\n・装備中の5枠は保持されます。\n\nGoldの端数は切り捨て。Lv・EXP・能力は再挑戦時にリセットされます。"
	accept.text = "中断してリザルトへ"
	cancel.show()
	show()
	_reveal()


func _reveal() -> void:
	details_scroll.scroll_vertical = 0
	UIMotion.of(presentation_panel).reveal(UIMotion.WINDOW_TIME)
	UIMotion.of(title_label).pulse(1.025, UIMotion.WINDOW_TIME)


func _accept() -> void:
	if confirming:
		abort_confirmed.emit()
	else:
		retry_requested.emit()
