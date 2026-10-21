class_name RunEndView
extends CanvasLayer

# The end of a real-time run, as roguelites sum a run up: over the chapter's
# illustration, darkened, a framed panel with the outcome (won, fallen or
# left) and where it ended, the run's figures as tiles (how far, how long,
# the foes felled, the level), the boons taken as their emblems, and the
# echo brought home counted up large; then whether that was saved, and the
# way on. Enter (or the button) goes on: back to the base when the run came
# from it, else a new run (a run played on its own).

signal again_requested

const BACKDROP := Color(0.02, 0.025, 0.035, 0.84)
const WIDTH := 860.0
const EMBLEM_SIZE := 52.0
# The echo counts up after the panel has come in.
const COUNT_DELAY := 0.35

var _art: TextureRect
var _title: Label
var _ending: Label
var _tiles: HBoxContainer
var _boons: HBoxContainer
var _no_boons: Label
var _echo: Label
var _save_note: Label
var _panel: PanelContainer
var _button: Button


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_art)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"MainPanel"
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_title = _centered(stack, &"VictoryTitle")
	_ending = _centered(stack, &"BodyLabel")
	HubUI.rule(stack)
	_tiles = HBoxContainer.new()
	stack.add_child(_tiles)
	_centered(stack, &"HeadingLabel").text = "取得した強化"
	_boons = HBoxContainer.new()
	_boons.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(_boons)
	_no_boons = _centered(stack, &"MutedLabel")
	_no_boons.text = "なし"
	HubUI.rule(stack)
	_centered(stack, &"MutedLabel").text = "持ち帰った残響"
	_echo = _centered(stack, &"PurseValue")
	_save_note = _centered(stack, &"MutedLabel")
	_save_note.hide()
	_button = HubUI.primary_action(stack, "新しいランを始める", func(): again_requested.emit())
	hide()


func _centered(parent: Node, role: StringName) -> Label:
	var label := HubUI.label(parent, "", role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


# {cleared, abandoned, layer, layers, chapter, time, kills, level, boons,
# emblems, echo}; `home` names the way on (back to the base, or a new run);
# `art` is the chapter's illustration, laid behind.
func present(result: Dictionary, home: bool = false, art: Texture2D = null) -> void:
	var won: bool = result.cleared
	var left: bool = result.get("abandoned", false)
	_art.texture = art
	_title.text = "踏破" if won else ("中断" if left else "敗北")
	_title.theme_type_variation = &"VictoryTitle" if won else &"DefeatTitle"
	_ending.text = "%s　%s" % [result.chapter, "ボスを撃破した" if won else ("第%d層で中断した" if left else "第%d層で倒れた") % (int(result.layer) + 1)]
	_button.text = "拠点へ戻る" if home else "新しいランを始める"
	for child in _tiles.get_children():
		child.free()
	var reached := "ボス" if won else "第%d層" % (int(result.layer) + 1)
	for pair: Array in [["到達", reached], ["戦った時間", "%d:%02d" % [floori(float(result.time) / 60.0), floori(float(result.time)) % 60]],
			["撃破", "%d体" % result.kills], ["レベル", "Lv %d" % result.level]]:
		_tile(pair[0], pair[1])
	for child in _boons.get_children():
		child.free()
	var emblems: Array = result.get("emblems", [])
	for entry: Array in emblems:
		var icon := TextureRect.new()
		icon.texture = EmblemIcons.texture(entry[0])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
		icon.tooltip_text = entry[1]
		_boons.add_child(icon)
	_boons.visible = not emblems.is_empty()
	_no_boons.visible = emblems.is_empty()
	var echo := int(result.echo)
	_echo.text = UIFormat.amount(echo)
	show()
	_button.grab_focus()
	UIMotion.bind_buttons(_panel)
	# Saved already; only the number counts up.
	UIMotion.of(_echo).count(0, echo, func(value: int) -> String: return UIFormat.amount(value), COUNT_DELAY)


# A figure of the run: a small caption over a large value, on an inset tile.
func _tile(caption: String, value: String) -> void:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"InsetPanel"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tiles.add_child(tile)
	var lines := VBoxContainer.new()
	tile.add_child(lines)
	_centered(lines, &"MutedLabel").text = caption
	_centered(lines, &"ValueLabel").text = value


# Whether the result was saved; shown only when there is something to say.
func show_save_status(text: String, alert: bool) -> void:
	_save_note.text = text
	_save_note.visible = alert


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		again_requested.emit()
