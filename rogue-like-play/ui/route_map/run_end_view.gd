class_name RunEndView
extends CanvasLayer

# The provisional end of a real-time run (until Phase 5's result screen and
# the return to the base): won or fallen, how far it went, the time, the
# foes felled, the level and boons, and the echo earned. Enter (or the
# button) asks for a new run.

signal again_requested

const BACKDROP := Color(0.02, 0.025, 0.035, 0.92)

var _title: Label
var _lines: Label
var _panel: PanelContainer


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
	var again := HubUI.button(stack, "新しいランを始める", func(): again_requested.emit(), &"PrimaryButton")
	again.custom_minimum_size.y = HubUI.PRIMARY_ACTION_HEIGHT
	hide()


# {cleared, layer, layers, chapter, time, kills, level, boons, echo}
func present(result: Dictionary) -> void:
	var won: bool = result.cleared
	_title.text = "踏破" if won else "敗北"
	_title.theme_type_variation = &"VictoryTitle" if won else &"DefeatTitle"
	var minutes := floori(float(result.time) / 60.0)
	_lines.text = "\n".join([
		"%s　%s" % [result.chapter, "ボスを撃破" if won else "第%d層で倒れた" % (int(result.layer) + 1)],
		"戦った時間　%d分%02d秒" % [minutes, floori(float(result.time)) % 60],
		"撃破　%d体" % result.kills,
		"レベル　%d" % result.level,
		"強化　%s" % ("、".join(result.boons) if not (result.boons as Array).is_empty() else "なし"),
		"残響　%d" % result.echo,
	])
	show()
	UIMotion.bind_buttons(_panel)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		again_requested.emit()
