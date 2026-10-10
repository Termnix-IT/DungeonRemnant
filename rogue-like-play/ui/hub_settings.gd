class_name HubSettings
extends Control

# The settings page, in the shared grammar: the settings as open rows on a
# slab from the screen's left edge that melts into the hall at its right,
# as tall as they are and level with the
# middle of the screen, the focused row on the lobby's warm band (sliding
# between rows) and what it does in the hall beside the band's tip, level with
# the row. Changes apply at once and are
# stored by GameSettings when the hub reports them, so the page holds no
# primary action.
# The last row opens the help: the game's rules that the screens keep out of
# their way, by topic. A HintMark ("?") on another page opens it at its topic.
# The same page opens over the dungeon from its menu (DungeonMenu), so it
# reaches nothing outside itself: whoever shows it listens to its signals.

signal changed
# The help opened from its row; the screen showing the page updates its keys.
signal help_opened

const ROW_HEIGHT := 80.0
const BAND_TIP := 18.0
# The band starts at the screen's left edge, as the lobby menu's does.
const EDGE_REACH := 40.0
# The note's column in the hall, from the band's tip.
const NOTE_INSET := 36.0
const NOTE_WIDTH := 420.0
const NOTES := ["すべての音の大きさ。0%で消音。", "攻撃・被弾・取得・決定などの効果音の大きさ。", "ダンジョンの空気の音の大きさ。", "被弾したときの画面の揺れ。「なし」で揺らさない。", "ウィンドウか全画面。", "探索中、画面の右下に今できる操作の札を出す。", "冒険の決まりごとと操作。"]
# The help's topics, in order: [title, paragraphs]. HintMarks name them by index.
const TOPIC_RUN := 0
const TOPIC_LOSS := 1
const TOPIC_PREPARATION := 2
const TOPIC_GROWTH := 3
const TOPIC_CONTROLS := 4
const HELP := [
	["冒険の流れ", [
		"冒険はいつもLv 1から始まる。冒険中に得たレベルと能力は、冒険が終わると消える。",
		"10階ごとに中ボスがいる。倒すとその階の入口に脱出口が現れ、乗ると持ち物をすべて持ったまま拠点へ帰れる。",
		"50階の主を倒すとそのステージを踏破し、次のステージへの道が開く。",
	]],
	["失うもの", [
		"倒れたとき、冒険を中断したとき、階の滞在ターンの上限を超えたときは、Goldの半分と、持ち込みの品のおよそ半分を失う。",
		"装備中の5枠の品と、倉庫の品は失わない。",
	]],
	["拠点の準備", [
		"持ち込み（40枠）は次の冒険へ持っていく品。倉庫（120枠）の品は持っていかないが、失うこともない。",
		"装備は、持ち込みと倉庫のどちらからでも直接付けられる。",
		"装備中の品と、魔法を込めた杖は売れない。",
		"準備の操作はそのたびに自動で保存される。",
	]],
	["永久強化と開始地点", [
		"永久強化はGoldで買い、効果は次の冒険からずっと続く。",
		"左端の基礎HPを上限まで上げると4本の枝が開き、各段を上限まで上げると次の段が開く。",
		"中ボスを倒した階の次の階（11F・21F・31F・41F）から始められるよう、Goldで開始地点を解放できる。どの階から始めてもLv 1で、永久強化と装備・持ち込みは引き継ぐ。",
	]],
	["操作", [
		"移動：WASD・矢印キー・テンキー。斜めはQ・E・Z・C。",
		"攻撃：Spaceで構え、向きを選んでもう一度Space。",
		"持ち物：I。主武器と副武器の切り替え：Tab。メニュー（設定・冒険の中断）：Esc。中断の確認へ直接：R。",
		"拠点では、Enterで選んだものの操作へ移り、もう一度Enterで実行する。Escで戻る。",
	]],
]

var volume_slider: GameSlider
var effects_slider: GameSlider
var ambience_slider: GameSlider
var help_button: Button
var volume_value: Label
var effects_value: Label
var ambience_value: Label
var shake_cycler: OptionCycler
var display_cycler: OptionCycler
var controls_cycler: OptionCycler
var settings: GameSettings
var rows: VBoxContainer
var note: Label
var focused_row := 0
var help_shown := false
var help_view: Control
var help_title: Label
var help_body: Label
var topic_rows: VBoxContainer
var topic_buttons: Array[Button] = []
var selected_topic := 0
var _rows: Array[Control] = []
var _columns: HBoxContainer
var _hall: Control
var _note_shade: PanelContainer


func _ready() -> void:
	var columns := HBoxContainer.new()
	_columns = columns
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := HubUI.open_column(columns, 1.5, &"SlabBand")
	left.theme_type_variation = &"DetailStack"
	# A few settings make a band, not a full-height column of empty slab.
	(left.get_parent() as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rows = VBoxContainer.new()
	rows.theme_type_variation = &"SettingsRows"
	left.add_child(rows)
	UIMotion.of(rows)
	rows.draw.connect(_draw_rows)
	# Three volumes, each a bar: everything, the effects, the room tone.
	var volume_parts := _volume_row("全体の音量", "VolumeSlider")
	volume_slider = volume_parts[0]
	volume_value = volume_parts[1]
	var effects_parts := _volume_row("効果音", "EffectsSlider")
	effects_slider = effects_parts[0]
	effects_value = effects_parts[1]
	var ambience_parts := _volume_row("環境音", "AmbienceSlider")
	ambience_slider = ambience_parts[0]
	ambience_value = ambience_parts[1]
	var shake_row := _row("画面の揺れ")
	shake_cycler = OptionCycler.new()
	shake_cycler.name = "ShakeCycler"
	shake_cycler.custom_minimum_size = Vector2(300, 52)
	shake_cycler.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shake_cycler.tooltip_text = "画面の揺れ"
	shake_row.add_child(shake_cycler)
	shake_cycler.setup(GameSettings.SHAKE_NAMES)
	shake_cycler.item_selected.connect(func(index: int):
		settings.shake_level = index
		changed.emit())
	var display_row := _row("画面モード")
	display_cycler = OptionCycler.new()
	display_cycler.name = "DisplayCycler"
	display_cycler.custom_minimum_size = Vector2(300, 52)
	display_cycler.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	display_cycler.tooltip_text = "画面モード"
	display_row.add_child(display_cycler)
	display_cycler.setup(GameSettings.DISPLAY_NAMES)
	display_cycler.item_selected.connect(func(index: int):
		settings.fullscreen = index == 1
		settings.apply_display()
		changed.emit())
	var controls_row := _row("操作の案内")
	controls_cycler = OptionCycler.new()
	controls_cycler.name = "ControlsCycler"
	controls_cycler.custom_minimum_size = Vector2(300, 52)
	controls_cycler.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls_cycler.tooltip_text = "操作の案内"
	controls_row.add_child(controls_cycler)
	controls_cycler.setup(GameSettings.CONTROLS_NAMES)
	controls_cycler.item_selected.connect(func(index: int):
		settings.show_controls = index == 0
		changed.emit())
	var help_row := _row("ヘルプ")
	help_button = HubUI.button(help_row, "遊び方と決まりごとを読む  ›", func():
		open_help(TOPIC_RUN)
		help_opened.emit(), &"TextAction")
	help_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var controls: Array[Control] = [volume_slider, effects_slider, ambience_slider, shake_cycler, display_cycler, controls_cycler, help_button]
	for index in controls.size():
		var control := controls[index]
		if index > 0:
			control.focus_neighbor_top = controls[index - 1].get_path()
		if index < controls.size() - 1:
			control.focus_neighbor_bottom = controls[index + 1].get_path()
		control.focus_entered.connect(_focus_row.bind(index))
	# The hall stays open on the right, as beside the lobby menu. The focused
	# row's note stands in it at the row's height, where the band points.
	_hall = Control.new()
	_hall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_hall)
	_note_shade = PanelContainer.new()
	_note_shade.theme_type_variation = &"ShadeColumn"
	_note_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_shade.position.x = NOTE_INSET
	_hall.add_child(_note_shade)
	note = HubUI.label(_note_shade, NOTES[0], &"NoteLabel")
	note.custom_minimum_size.x = NOTE_WIDTH
	_build_help()


# The help: topics as rows on a slab from the left edge, the chosen topic's
# paragraphs beside them.
func _build_help() -> void:
	help_view = HBoxContainer.new()
	help_view.theme_type_variation = &"ShopColumns"
	add_child(help_view)
	help_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_view.hide()
	var topics := HubUI.open_column(help_view, 0.7, &"SlabSolid")
	topics.theme_type_variation = &"DetailStack"
	topic_rows = VBoxContainer.new()
	topic_rows.theme_type_variation = &"SlotRows"
	topics.add_child(topic_rows)
	UIMotion.of(topic_rows)
	topic_rows.draw.connect(_draw_topic_band)
	for index in HELP.size():
		var row := HubUI.button(topic_rows, HELP[index][0], select_topic.bind(index), &"HelpTopic")
		row.toggle_mode = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 56
		row.focus_entered.connect(select_topic.bind(index))
		topic_buttons.append(row)
	# About 40 characters a line at most, the Xbox Accessibility Guideline 101
	# limit for Japanese; the hall shows past them.
	var page := HubUI.open_column(help_view, 1.0, &"SlabColumn")
	page.theme_type_variation = &"DetailStack"
	help_title = HubUI.label(page, "", &"HeadingLabel")
	HubUI.rule(page)
	help_body = HubUI.label(page, "", &"BodyLabel")
	var hall := Control.new()
	hall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hall.size_flags_stretch_ratio = 0.7
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_view.add_child(hall)


func open_help(topic: int) -> void:
	help_shown = true
	_columns.hide()
	help_view.show()
	select_topic(topic)
	topic_buttons[topic].grab_focus()
	UIMotion.of(help_view).appear(0.0, UIMotion.WINDOW_TIME)


func close_help() -> void:
	help_shown = false
	help_view.hide()
	_columns.show()
	help_button.grab_focus()


func select_topic(index: int) -> void:
	selected_topic = index
	for other in topic_buttons.size():
		topic_buttons[other].set_pressed_no_signal(other == index)
	help_title.text = HELP[index][0]
	help_body.text = "\n\n".join(HELP[index][1])
	topic_rows.queue_redraw()
	UIMotion.reveal_selection([help_body])


func _draw_topic_band() -> void:
	var chosen := topic_buttons[selected_topic]
	_draw_band(topic_rows, UIMotion.of(topic_rows).follow_mark(Rect2(chosen.position + Vector2(-EDGE_REACH, 2), chosen.size + Vector2(EDGE_REACH, -4))))


func _row(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"SettingsRow"
	row.custom_minimum_size.y = ROW_HEIGHT
	rows.add_child(row)
	_rows.append(row)
	var label := HubUI.label(row, caption, &"ItemNameLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 150
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


# A volume as a bar from 0 to 100% in 5% steps, its value at the right.
# Returns [the bar, the value].
func _volume_row(caption: String, slider_name: String) -> Array:
	var row := _row(caption)
	_hint(row, "← 小")
	var slider := GameSlider.new()
	slider.name = slider_name
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.tooltip_text = caption
	row.add_child(slider)
	_hint(row, "大 →")
	var value := HubUI.label(row, "", &"SettingsValue")
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.custom_minimum_size.x = 72
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_volume_changed.bind(slider))
	return [slider, value]


func _hint(row: HBoxContainer, text: String) -> void:
	var hint := HubUI.label(row, text, &"NoteLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# The focused row stands on the lobby's warm band, pointing right at the
# note; the others are parted by faint rules.
func _draw_rows() -> void:
	var rail := rows.get_theme_color(&"rail", &"HubLobby")
	var chosen := _rows[focused_row]
	var mark := UIMotion.of(rows).follow_mark(Rect2(chosen.position + Vector2(-EDGE_REACH, 4), chosen.size + Vector2(EDGE_REACH + BAND_TIP, -8)))
	_draw_band(rows, mark)
	_place_note(mark)
	for index in _rows.size() - 1:
		if index == focused_row or index + 1 == focused_row:
			continue
		var y := _rows[index].position.y + _rows[index].size.y
		rows.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(rows.size.x * 0.5, y), Vector2(rows.size.x, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.22), Color(rail, 0.0)]), 1.0, true)


# The note keeps level with the band, sliding with it between rows.
func _place_note(mark: Rect2) -> void:
	_note_shade.size = _note_shade.get_combined_minimum_size()
	var middle := rows.global_position.y + mark.get_center().y - _hall.global_position.y
	_note_shade.position.y = middle - _note_shade.size.y * 0.5


# The lobby's warm band, pointed at its right end.
func _draw_band(canvas: Control, rect: Rect2) -> void:
	var rail := canvas.get_theme_color(&"rail", &"HubLobby")
	var band := canvas.get_theme_color(&"band", &"HubLobby")
	var tip := rect.end.x
	var middle := rect.get_center().y
	var outline := PackedVector2Array([rect.position, Vector2(tip - BAND_TIP, rect.position.y), Vector2(tip, middle), Vector2(tip - BAND_TIP, rect.end.y), Vector2(rect.position.x, rect.end.y)])
	canvas.draw_polygon(outline, PackedColorArray([Color(band, band.a * 0.5), Color(band, band.a * 1.6), Color(band, band.a * 1.8), Color(band, band.a * 1.6), Color(band, band.a * 0.5)]))
	canvas.draw_polyline_colors(outline, PackedColorArray([Color(rail, 0.0), Color(rail, 0.85), rail, Color(rail, 0.85), Color(rail, 0.0)]), 1.5, true)


func _focus_row(index: int) -> void:
	focused_row = index
	note.text = NOTES[index]
	rows.queue_redraw()
	UIMotion.reveal_selection([note])


func refresh(value: GameSettings) -> void:
	settings = value
	for pair: Array in [[volume_slider, volume_value, settings.volume], [effects_slider, effects_value, settings.effects_volume], [ambience_slider, ambience_value, settings.ambience_volume]]:
		(pair[0] as GameSlider).set_value_no_signal(settings.volume_percent(pair[2]))
		(pair[0] as GameSlider).queue_redraw()
		(pair[1] as Label).text = "%d%%" % settings.volume_percent(pair[2])
	shake_cycler.select(settings.shake_level)
	display_cycler.select(1 if settings.fullscreen else 0)
	controls_cycler.select(0 if settings.show_controls else 1)


func focus_first() -> void:
	if help_shown:
		close_help()
	volume_slider.grab_focus()
	_focus_row(0)


# Opening the page: the rows arrive top first, the note a beat later.
func play_entrance() -> void:
	for index in _rows.size():
		UIMotion.of(_rows[index]).appear(UIMotion.ROW_STAGGER * index, UIMotion.ROW_TIME)
	UIMotion.of(note).appear(UIMotion.STAGGER_TIME)


func _volume_changed(percent: float, slider: GameSlider) -> void:
	var level := percent / 100.0
	if slider == effects_slider:
		settings.effects_volume = level
		effects_value.text = "%d%%" % settings.volume_percent(level)
	elif slider == ambience_slider:
		settings.ambience_volume = level
		ambience_value.text = "%d%%" % settings.volume_percent(level)
	else:
		settings.volume = level
		volume_value.text = "%d%%" % settings.volume_percent(level)
	settings.apply_volume()
	changed.emit()
