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


func _ready() -> void:
	layer = 12
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := VBoxContainer.new()
	panel.name = "Panel"
	panel.add_theme_constant_override("separation", 20)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -250.0
	panel.offset_bottom = 250.0
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	panel.add_child(title_label)
	details = Label.new()
	details.add_theme_font_size_override("font_size", 20)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(680, 300)
	panel.add_child(details)
	accept = Button.new()
	accept.custom_minimum_size.y = 44
	accept.focus_mode = Control.FOCUS_NONE
	accept.pressed.connect(_accept)
	panel.add_child(accept)
	cancel = Button.new()
	cancel.text = "探索に戻る（Esc）"
	cancel.custom_minimum_size.y = 44
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): abort_cancelled.emit())
	panel.add_child(cancel)
	save_label = Label.new()
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(save_label)
	hide()


func show_save_status(message: String) -> void:
	save_label.text = message


func present(result: Dictionary) -> void:
	save_label.text = ""
	confirming = false
	title_label.text = "冒険クリア" if result.cleared else "冒険終了"
	var losses: PackedStringArray = []
	for label: String in result.items_lost:
		losses.append("%s ×%d" % [label, result.items_lost[label]])
	details.text = "到達階：%dF\n今回獲得：%d Gold\n失ったGold：%d　／　残り：%d\n失ったアイテム：%d個\n%s\n\n装備中の5枠は保持されます。" % [result.floor, result.earned_gold, result.gold_lost, result.gold, result.item_count_lost, "、".join(losses) if not losses.is_empty() else "なし"]
	accept.text = "拠点へ戻る（R）" if return_to_hub else "Lv1から再挑戦（R）"
	cancel.hide()
	show()


func confirm_abort() -> void:
	save_label.text = ""
	confirming = true
	title_label.text = "冒険を中断しますか？"
	details.text = "死亡時と同じペナルティが適用されます。\n\n・所持Goldの50%を失います。\n・非装備アイテムの50%を個数単位で失います。\n・装備中の5枠は保持されます。\n\n端数は切り捨て。Lv・EXP・能力は再挑戦時にリセットされます。"
	accept.text = "中断してリザルトへ"
	cancel.show()
	show()


func _accept() -> void:
	if confirming:
		abort_confirmed.emit()
	else:
		retry_requested.emit()
