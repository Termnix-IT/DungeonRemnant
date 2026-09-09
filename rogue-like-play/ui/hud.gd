extends CanvasLayer

@onready var status: Label = $Status
@onready var message: Label = $Message


func refresh(hp: int, max_hp: int, turns: int, visible_enemies: int, log_text: String, floor_number: int, layout_name: String) -> void:
	status.text = "%d / 10F  %s     HP %d / %d     TURN %d     視界内の敵 %d" % [floor_number, layout_name, hp, max_hp, turns, visible_enemies]
	if hp <= 0:
		message.text = "死亡しました。リザルト画面を確認してください。"
	else:
		message.text = log_text


func show_aim(weapon_name: String, aiming: bool) -> void:
	status.text += "       " + weapon_name
	if aiming:
		message.text = "攻撃方向を選択中：方向キーで変更 / Spaceで確定 / Escでキャンセル"


func show_progress(level: int, exp: int, required: int) -> void:
	$Growth.text = "Lv %d    EXP %d / %d" % [level, exp, required] if required > 0 else "Lv 100    MAX"


func show_inventory(count: int) -> void:
	$Growth.text += "      Inventory %d / 40  (I)     武器切替: Tab" % count


func show_gold(gold: int) -> void:
	$Growth.text += "      Gold %d" % gold


func show_boss(text: String) -> void:
	if not has_node("Boss"):
		var label := Label.new()
		label.name = "Boss"
		label.position = Vector2(48, 88)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("efbb81"))
		add_child(label)
	$Boss.text = text
