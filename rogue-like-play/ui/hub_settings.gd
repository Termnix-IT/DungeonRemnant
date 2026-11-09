class_name HubSettings
extends Control

# The settings page, laid out as action roguelites commonly lay theirs: one
# panel in the middle of the screen, tabs over the rows (sound, graphics,
# other; Q / E or LB / RB, or a click) showing one group at a time, and
# under a gilt rule what the focused setting does, sliding in anew as the
# focus moves. With so few rows a column of its own for one line of account
# stood mostly empty. The focused row draws no band: the control on it shows
# the focus itself (the bar's knob glows, the selector's arrows light, the
# help's and the quit's words brighten). Changes apply at once and are
# stored by GameSettings when the hub reports them, so the page holds no
# primary action.
# A row opens the help: the game's rules that the screens keep out of their
# way, by topic. A HintMark ("?") on another page opens it at its topic. The
# last row ends the game, once a prompt has asked.
# The same page opens over the dungeon from its menu (DungeonMenu), so it
# reaches nothing outside itself: whoever shows it listens to its signals.

signal changed
# The help opened from its row; the screen showing the page updates its keys.
signal help_opened
# The help's close was clicked (its key hint, or the dimmed backdrop round
# the window); whoever shows the page closes it as its own Esc would.
signal help_close_requested

const QUIT_BODY := "設定と拠点での強化は保存済みです。"
# In a run nothing of it is kept (the base saves at a run's start and end).
const QUIT_BODY_IN_RUN := "ランの途中で終了すると、このランのレベル・強化・得た残響は残らず、最後に保存した拠点の状態に戻ります。"

const ROW_HEIGHT := 64.0
# The panel's width; its height holds the longest tab, so it keeps its size
# from tab to tab.
const PANEL_WIDTH := 1000.0
# The help window: over the page and the fight's menu, under the quit's
# question; its backdrop, size and topic column.
const HELP_LAYER := 15
const HELP_SHADE := Color(0.01, 0.015, 0.025, 0.7)
const HELP_SIZE := Vector2(1280, 780)
const HELP_TOPICS_WIDTH := 260.0
# The settings' tabs: [name, the rows it shows].
const TABS := [["サウンド", [0, 1, 2, 3]], ["グラフィック", [4, 5]], ["その他", [6, 7, 8]]]
const CAPTIONS := ["全体の音量", "音楽", "効果音", "環境音", "画面の揺れ", "画面モード", "操作の案内", "ヘルプ", "ゲームの終了"]
const NOTES := ["すべての音の大きさ。0%で消音。", "拠点・戦場・ボスの曲の大きさ。", "攻撃・被弾・取得・決定などの効果音の大きさ。", "戦場の空気の音の大きさ。", "攻撃が当たったときや被弾したときの画面の揺れ。「なし」で揺らさない。", "ウィンドウか全画面。", "戦闘中、画面の下に操作の一覧を出す。", "ランの決まりごとと操作。", "ゲームを閉じる。確かめてから終了する。"]
# The help's topics, in order: [title, points], each point a line of its own
# behind a gilt diamond, as action games' tips are told, in the polite form
# the game's other messages use. HintMarks name the topics by index.
const TOPIC_RUN := 0
const TOPIC_GROWTH := 1
const TOPIC_CONTROLS := 2
const TOPIC_CODEX := 3
const HELP := [
	["ランの流れ", [
		"出撃するたびに、Lv 1から始まります。分岐マップで次のエリアを選んで制圧しながら進み、章の最後にいるボスを倒すと踏破です。",
		"フィールドは、決められた時間を生き延びるか、決められた数の敵を倒すと制圧できます。どちらの目標かは、戦闘中の画面の上に表示されます。",
		"アリーナは、すべてのウェーブを倒すと制圧できます。",
		"敵が落とす宝石を拾うとレベルが上がり、そのたびに3枚（永続強化で4枚）のカードから強化を1つ選びます。カードは、並び終えて光ってから選べます。",
		"分岐マップのエリアに示された報酬（強化・回復・残響）は、そのエリアを制圧すると受け取れます。",
		"HPは次のエリアへ持ち越します。レベルと強化は、そのランが終わると消えます。",
		"最後の章を初めて踏破すると「難易度の段階」が開きます。出撃画面で段階を選ぶと、その段階までの制約がすべて加わる代わりに、持ち帰る残響が1段階ごとに1割増えます。",
		"開いている中で最も高い段階で最後の章を踏破すると、次の段階が開きます。",
	]],
	["残響と永続強化", [
		"残響はランの中で手に入ります。踏破しても、倒れても、ランを中断しても、得た分はすべて拠点へ持ち帰れます。",
		"拠点の「強化」で残響を使うと、次のランからずっと効く強化を習得できます。",
		"強化は、中央の「残響の灯」から枝分かれする木の形をしています。左の枝で体を、右の枝でレベルアップを強くし、上の枝でスキルを覚えます。",
		"節は、線でつながった1つ手前の節を習得すると買えるようになります。下の枝はまだ開いていません。",
		"習得した強化は、その場で自動的に保存されます。",
	]],
	["操作", [
		"攻撃は、マウスの方向（ゲームパッドは右スティックの方向）へ振ります。続けて押すと3段の連撃、長押しで溜め攻撃です。",
		"回避のダッシュをしている間は、攻撃を受けません。",
		"敵の攻撃の前には、床に赤い印が出ます。印が埋まる前に外へ出るか、ダッシュでくぐり抜けてください。",
		"スキルと必殺技は、拠点の「ステータス」で付け替えます。必殺技は、戦ってゲージを満たすと使えます。",
		"拠点の画面では、Enter（ゲームパッドはA）で項目を選び、もう一度押すと決定します。Esc（ゲームパッドはB）で前の画面に戻ります。",
	]],
	["図鑑", [
		"拠点の「図鑑」では、ランで出会った敵をいつでも見返せます。",
		"まだ出会っていない敵は、影と「？？？」で表示されます。どの種類の敵かだけは分かります。",
		"Q・E（ゲームパッドはLB・RB）で種類を切り替えます。",
	]],
]
# The controls topic's table, over its points: [what it does, the keys, the
# gamepad's buttons], each key on a cap of its own.
const HELP_KEYS := [
	["移動", ["WASD", "矢印キー"], ["左スティック", "十字キー"]],
	["攻撃", ["左クリック"], ["X"]],
	["狙い", ["マウス"], ["右スティック"]],
	["回避", ["Space"], ["A", "RB"]],
	["スキル", ["Q", "E"], ["Y", "B"]],
	["必殺技", ["R"], ["LB"]],
	["強化を選ぶ", ["1", "2", "3", "クリック"], ["◀ / ▶", "A"]],
	["メニュー", ["Esc"], ["START"]],
]
# The point's gilt diamond: its box, as tall as a line of the words.
const POINT_MARKER := Vector2(14, 25)
# The chosen topic's glow: the widths of its halo's outlines, each laid over
# the last, so the halo is brightest by the letters.
const TOPIC_GLOW: Array[int] = [14, 9, 5]

var volume_slider: GameSlider
var effects_slider: GameSlider
var music_slider: GameSlider
var ambience_slider: GameSlider
var help_button: Button
var quit_button: Button
var quit_prompt: ChoicePrompt
# Set by the dungeon's menu, so the prompt says what a run loses.
var in_run := false
# What ending the game does; tests replace it.
var quit_action := func(): get_tree().quit()
var volume_value: Label
var music_value: Label
var effects_value: Label
var ambience_value: Label
var shake_cycler: OptionCycler
var display_cycler: OptionCycler
var controls_cycler: OptionCycler
var settings: GameSettings
var rows: VBoxContainer
var note: Label
var focused_row := 0
var tabs: CategoryTabs
# Every row's control, in row order (their focus is chained within a tab).
var controls: Array[Control] = []
var help_shown := false
var help_layer: CanvasLayer
var help_view: Control
var help_window: PanelContainer
var help_close_hint: Button
var help_title: Label
# The chosen topic's table of keys (the controls only) and its points.
var help_keys: GridContainer
var help_points: VBoxContainer
var topic_rows: VBoxContainer
var topic_buttons: Array[Button] = []
var selected_topic := 0
var _rows: Array[Control] = []
var _columns: HBoxContainer
# The detail column (what the focused setting does) and the help's page,
# which slide in from the right when what they tell changes.
var info_column: VBoxContainer
var help_words: VBoxContainer
# What the column and the help's page tell now: telling it again (a click
# lands as a focus and a press) does not slide them.
var _shown_note := -1
var _shown_topic := -1
var _hover_topic := -1
var _hover_row := -1


func _ready() -> void:
	var columns := HBoxContainer.new()
	_columns = columns
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	var left := HubUI.open_column(columns, 1.0, &"SlabSolid")
	var panel := left.get_parent() as Control
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.clip_contents = true
	left.theme_type_variation = &"DetailStack"
	tabs = CategoryTabs.new()
	left.add_child(tabs)
	var names: Array[String] = []
	for tab: Array in TABS:
		names.append(tab[0])
	tabs.setup(names)
	tabs.changed.connect(func(_index: int): show_tab(tabs.selected, true))
	rows = VBoxContainer.new()
	rows.theme_type_variation = &"SettingsRows"
	var longest := 0
	for tab: Array in TABS:
		longest = maxi(longest, (tab[1] as Array).size())
	rows.custom_minimum_size.y = ROW_HEIGHT * longest
	left.add_child(rows)
	UIMotion.of(rows)
	rows.draw.connect(_draw_rows)
	# Four volumes, each a bar: everything, the music, the effects, the room tone.
	var volume_parts := _volume_row("全体の音量", "VolumeSlider")
	volume_slider = volume_parts[0]
	volume_value = volume_parts[1]
	var music_parts := _volume_row("音楽", "MusicSlider")
	music_slider = music_parts[0]
	music_value = music_parts[1]
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
	help_button = HubUI.button(help_row, "開く", func():
		open_help(TOPIC_RUN)
		help_opened.emit(), &"TextAction")
	help_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var quit_row := _row("ゲームの終了")
	quit_button = HubUI.button(quit_row, "終了する", ask_quit, &"TextAction")
	quit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quit_prompt = ChoicePrompt.new()
	add_child(quit_prompt)
	# Over the dungeon's menu as well as the hub.
	quit_prompt.layer = 20
	quit_prompt.confirmed.connect(func():
		quit_prompt.hide()
		quit_action.call())
	quit_prompt.canceled.connect(func():
		quit_prompt.hide()
		quit_button.grab_focus())
	controls = [volume_slider, music_slider, effects_slider, ambience_slider, shake_cycler, display_cycler, controls_cycler, help_button, quit_button]
	for index in controls.size():
		controls[index].focus_entered.connect(_focus_row.bind(index))
		# As in the lobby and the help, resting the pointer on a row chooses
		# it: read from the pointer entering or moving over the row or its
		# control.
		_rows[index].mouse_filter = Control.MOUSE_FILTER_PASS
		for watched: Control in [_rows[index], controls[index]]:
			watched.mouse_entered.connect(_hover_setting_row.bind(index))
			watched.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseMotion and _hover_row != index:
					_hover_setting_row(index))
	# What the focused setting does, under the rows.
	HubUI.rule(left)
	var info := VBoxContainer.new()
	left.add_child(info)
	info_column = info
	note = HubUI.label(info, NOTES[0], &"DescriptionLabel")
	_build_help()
	show_tab(0)


# The help, as action games commonly show their tips: a framed window over a
# dimmed backdrop (on a layer of its own, above the page and the fight's
# menu), its title over the topics listed on the left (the chosen one's words
# lit, no band behind them) and, on the right, a sunk frame holding the
# chosen one's title, a table of the keys for the controls, and its points a
# line each; the keys at the window's foot.
func _build_help() -> void:
	help_layer = CanvasLayer.new()
	help_layer.layer = HELP_LAYER
	add_child(help_layer)
	help_layer.hide()
	help_view = Control.new()
	help_view.theme = preload("res://ui/theme/dungeon_theme.tres")
	help_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_layer.add_child(help_view)
	var shade := ColorRect.new()
	shade.color = HELP_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	# A click outside the window closes it, as dialogs commonly do.
	shade.gui_input.connect(func(event: InputEvent):
		if help_shown and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			help_close_requested.emit())
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_view.add_child(shade)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_view.add_child(center)
	help_window = PanelContainer.new()
	help_window.theme_type_variation = &"QuietWindow"
	help_window.custom_minimum_size = HELP_SIZE
	center.add_child(help_window)
	var margin := MarginContainer.new()
	help_window.add_child(margin)
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"DetailStack"
	margin.add_child(stack)
	var heading := HubUI.label(stack, "ヘルプ", &"TitleLabel")
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	var body := HBoxContainer.new()
	body.theme_type_variation = &"HelpBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	var topics := VBoxContainer.new()
	topics.theme_type_variation = &"DetailStack"
	topics.custom_minimum_size.x = HELP_TOPICS_WIDTH
	body.add_child(topics)
	topic_rows = VBoxContainer.new()
	topic_rows.theme_type_variation = &"SlotRows"
	topics.add_child(topic_rows)
	topic_rows.draw.connect(_draw_topic_glow)
	for index in HELP.size():
		var row := HubUI.button(topic_rows, HELP[index][0], select_topic.bind(index), &"HelpTopic")
		row.toggle_mode = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 56
		row.focus_entered.connect(select_topic.bind(index))
		# As in the lobby, resting the pointer on a topic chooses it: read from
		# the pointer moving over the row, so a pointer already there when the
		# window opened, or an entry that went unreported, still counts.
		row.mouse_entered.connect(_hover_topic_row.bind(index))
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseMotion and _hover_topic != index:
				_hover_topic_row(index))
		row.mouse_exited.connect(func():
			if _hover_topic == index:
				_hover_topic = -1)
		topic_buttons.append(row)
	# The page, in a sunk frame of its own, slides in from the right, kept
	# inside the frame.
	var page := PanelContainer.new()
	page.theme_type_variation = &"HelpPage"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.clip_contents = true
	body.add_child(page)
	var words := VBoxContainer.new()
	words.theme_type_variation = &"DetailStack"
	page.add_child(words)
	help_words = words
	help_title = HubUI.label(words, "", &"HeadingLabel")
	HubUI.rule(words)
	help_keys = GridContainer.new()
	help_keys.theme_type_variation = &"HelpKeys"
	help_keys.columns = 3
	words.add_child(help_keys)
	for title: String in ["", "キーボード", "ゲームパッド"]:
		HubUI.label(help_keys, title, &"MutedLabel").autowrap_mode = TextServer.AUTOWRAP_OFF
	for entry: Array in HELP_KEYS:
		var action := HubUI.label(help_keys, entry[0], &"BodyLabel")
		action.autowrap_mode = TextServer.AUTOWRAP_OFF
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for keys: Array in [entry[1], entry[2]]:
			var caps := HBoxContainer.new()
			caps.theme_type_variation = &"HelpKeyCaps"
			help_keys.add_child(caps)
			for key: String in keys:
				var cap := PanelContainer.new()
				cap.theme_type_variation = &"HelpKeyCap"
				cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				caps.add_child(cap)
				var name := HubUI.label(cap, key, &"HelpKeyName")
				name.autowrap_mode = TextServer.AUTOWRAP_OFF
				name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	words.add_child(gap)
	help_points = VBoxContainer.new()
	help_points.theme_type_variation = &"HelpPoints"
	words.add_child(help_points)
	var guide := KeyGuide.new()
	guide.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(guide)
	guide.add_hint("↑ / ↓", "▲ / ▼", "話題")
	help_close_hint = guide.add_hint("Esc", "B", "閉じる", func(): help_close_requested.emit())
	# A page hidden behind another takes its help window with it.
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			help_layer.hide())


# Asks before ending the game; Esc or the cancel button keeps playing. The
# focus waits on the cancel button, so a second Enter never ends the game.
func ask_quit() -> void:
	quit_prompt.ask("", "ゲームを終了しますか？", QUIT_BODY_IN_RUN if in_run else QUIT_BODY, "終了する", "戻る", true)
	quit_prompt.cancel_button.grab_focus()


func open_help(topic: int) -> void:
	help_shown = true
	help_layer.show()
	select_topic(topic)
	topic_buttons[topic].grab_focus()
	UIMotion.of(help_window).appear(0.0, UIMotion.WINDOW_TIME)


func close_help() -> void:
	help_shown = false
	help_layer.hide()
	help_button.grab_focus()


func select_topic(index: int) -> void:
	selected_topic = index
	for other in topic_buttons.size():
		topic_buttons[other].set_pressed_no_signal(other == index)
	topic_rows.queue_redraw()
	if index == _shown_topic:
		return
	_shown_topic = index
	help_title.text = HELP[index][0]
	help_keys.visible = index == TOPIC_CONTROLS
	for child in help_points.get_children():
		child.free()
	for point: String in HELP[index][1]:
		_help_point(point)
	UIMotion.of(help_words).slide_in()


# One of the topic's points: a small gilt diamond by its first line, then
# the words.
func _help_point(text: String) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"HelpPoint"
	help_points.add_child(row)
	var marker := Control.new()
	marker.custom_minimum_size = POINT_MARKER
	marker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(func(): HubUI.diamond(marker, marker.size * 0.5, 4.0, marker.get_theme_color(&"rail", &"HubLobby")))
	row.add_child(marker)
	var words := HubUI.label(row, text, &"DescriptionLabel")
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _hover_setting_row(index: int) -> void:
	_hover_row = index
	await get_tree().create_timer(HubLobby.HOVER_INTENT).timeout
	if _hover_row != index or not is_visible_in_tree() or help_shown or quit_prompt.visible:
		return
	if _rows[index].visible and not controls[index].has_focus():
		controls[index].grab_focus()


func _hover_topic_row(index: int) -> void:
	_hover_topic = index
	await get_tree().create_timer(HubLobby.HOVER_INTENT).timeout
	if _hover_topic == index and help_shown and selected_topic != index:
		topic_buttons[index].grab_focus()
		select_topic(index)


# The chosen topic's words glow: a soft gilt halo under the gold letters,
# laid as outlines of the words, the widest faintest, so it gathers to the
# letters; the row itself draws no band or frame.
func _draw_topic_glow() -> void:
	var chosen := topic_buttons[selected_topic]
	var font := chosen.get_theme_font(&"font")
	var font_size := chosen.get_theme_font_size(&"font_size")
	var x := chosen.position.x + chosen.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT)
	var y := chosen.position.y + (chosen.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	var glow := chosen.get_theme_color(&"glow")
	for spread: int in TOPIC_GLOW:
		topic_rows.draw_string_outline(font, Vector2(x, y), chosen.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, spread, glow)


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
	var slider := GameSlider.new()
	slider.name = slider_name
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.tooltip_text = caption
	row.add_child(slider)
	var value := HubUI.label(row, "", &"SettingsValue")
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.custom_minimum_size.x = 72
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_volume_changed.bind(slider))
	return [slider, value]


# The rows are parted by faint rules; the focused one draws no band.
func _draw_rows() -> void:
	var rail := rows.get_theme_color(&"rail", &"HubLobby")
	var shown: Array[int] = []
	shown.assign(TABS[tabs.selected][1])
	for place in shown.size() - 1:
		var index := shown[place]
		var y := _rows[index].position.y + _rows[index].size.y
		rows.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(rows.size.x * 0.5, y), Vector2(rows.size.x, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.22), Color(rail, 0.0)]), 1.0, true)


func _focus_row(index: int) -> void:
	focused_row = index
	if index == _shown_note:
		return
	_shown_note = index
	note.text = NOTES[index]
	UIMotion.of(info_column).slide_in()


func refresh(value: GameSettings) -> void:
	settings = value
	for pair: Array in [[volume_slider, volume_value, settings.volume], [music_slider, music_value, settings.music_volume], [effects_slider, effects_value, settings.effects_volume], [ambience_slider, ambience_value, settings.ambience_volume]]:
		(pair[0] as GameSlider).set_value_no_signal(settings.volume_percent(pair[2]))
		(pair[0] as GameSlider).queue_redraw()
		(pair[1] as Label).text = "%d%%" % settings.volume_percent(pair[2])
	shake_cycler.select(settings.shake_level)
	display_cycler.select(1 if settings.fullscreen else 0)
	controls_cycler.select(0 if settings.show_controls else 1)


func focus_first() -> void:
	if help_shown:
		close_help()
	var first: int = TABS[tabs.selected][1][0]
	controls[first].grab_focus()
	_focus_row(first)


# Shows one tab's rows, their focus chained top to bottom; `take_focus` puts
# the focus on its first row (a tab changed from the keys or a click).
func show_tab(index: int, take_focus: bool = false) -> void:
	if tabs.selected != index:
		tabs.select(index)
	var shown: Array[int] = []
	shown.assign(TABS[index][1])
	for row in _rows.size():
		_rows[row].visible = shown.has(row)
	for place in shown.size():
		var control := controls[shown[place]]
		control.focus_neighbor_top = controls[shown[place - 1]].get_path() if place > 0 else control.get_path()
		control.focus_neighbor_bottom = controls[shown[place + 1]].get_path() if place < shown.size() - 1 else control.get_path()
	rows.queue_redraw()
	if take_focus:
		controls[shown[0]].grab_focus()
	_focus_row(shown[0])


# Q / E (LB / RB) step through the tabs while the page is shown and the help
# and the quit's question are not.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or help_shown or quit_prompt.visible:
		return
	var pad := event is InputEventJoypadButton
	if pad or event is InputEventKey:
		tabs.use_pad(pad)
	var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q) or (pad and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var next: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or (pad and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	if back or next:
		tabs.step(-1 if back else 1)
		get_viewport().set_input_as_handled()


# Opening the page: the rows arrive top first, the note a beat later.
func play_entrance() -> void:
	for index in _rows.size():
		UIMotion.of(_rows[index]).appear(UIMotion.ROW_STAGGER * index, UIMotion.ROW_TIME)
	UIMotion.of(note).appear(UIMotion.STAGGER_TIME)


func _volume_changed(percent: float, slider: GameSlider) -> void:
	var level := percent / 100.0
	if slider == music_slider:
		settings.music_volume = level
		music_value.text = "%d%%" % settings.volume_percent(level)
	elif slider == effects_slider:
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
