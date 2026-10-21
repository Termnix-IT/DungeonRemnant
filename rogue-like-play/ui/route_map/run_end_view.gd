class_name RunEndView
extends CanvasLayer

# The end of a real-time run: won, fallen or left, how far it went, the
# time, the foes felled, the level and boons, the echo brought home, and
# whether that was saved. Enter (or the button) goes on: back to the base
# when the run came from it, else a new run (a run played on its own).

signal again_requested

const BACKDROP := Color(0.02, 0.025, 0.035, 0.92)

var _title: Label
var _lines: Label
var _save_note: Label
var _panel: PanelContainer
var _button: Button


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"MainPanel"
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)
	_title = HubUI.label(stack, "", &"VictoryTitle")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines = HubUI.label(stack, "", &"BodyLabel")
	_lines.autowrap_mode = TextServer.AUTOWRAP_OFF
	_save_note = HubUI.label(stack, "", &"MutedLabel")
	_save_note.hide()
	_button = HubUI.button(stack, "新しいランを始める", func(): again_requested.emit(), &"PrimaryButton")
	_button.custom_minimum_size.y = HubUI.PRIMARY_ACTION_HEIGHT
	hide()


# {cleared, abandoned, layer, layers, chapter, time, kills, level, boons,
# echo}; `home` names the way on (back to the base, or a new run).
func present(result: Dictionary, home: bool = false) -> void:
	var won: bool = result.cleared
	var left: bool = result.get("abandoned", false)
	_title.text = "踏破" if won else ("中断" if left else "敗北")
	_button.text = "拠点へ戻る" if home else "新しいランを始める"
	_title.theme_type_variation = &"VictoryTitle" if won else &"DefeatTitle"
	var minutes := floori(float(result.time) / 60.0)
	_lines.text = "\n".join([
		"%s　%s" % [result.chapter, "ボスを撃破" if won else ("第%d層で中断した" if left else "第%d層で倒れた") % (int(result.layer) + 1)],
		"戦った時間　%d分%02d秒" % [minutes, floori(float(result.time)) % 60],
		"撃破　%d体" % result.kills,
		"レベル　%d" % result.level,
		"強化　%s" % ("、".join(result.boons) if not (result.boons as Array).is_empty() else "なし"),
		"持ち帰った残響　%d" % result.echo,
	])
	show()
	_button.grab_focus()
	UIMotion.bind_buttons(_panel)


# Whether the result was saved; shown only when there is something to say.
func show_save_status(text: String, alert: bool) -> void:
	_save_note.text = text
	_save_note.visible = alert


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		again_requested.emit()
