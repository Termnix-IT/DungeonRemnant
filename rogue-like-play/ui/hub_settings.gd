class_name HubSettings
extends Control

# The settings page, as a list and a stage: every setting in one list down
# the left, under the names of their groups (sound, graphics, other), and on
# the right a stage that shows what the one under the cursor does, moving as
# it would in play. A volume is rings of sound from a bell, carrying as far
# as it is set, beside the four levels; the shake is a struck frame that
# shakes as hard as it is set; the screen is a window on a monitor or the
# whole of it; the language is a line of the game in it; the controls guide
# is the fight's foot with or without its keys; the help is its topics; the
# end of the game is what is kept. Under the stage stand the setting's name
# and value, large, and what it does.
#
# Up and down go through the list, left and right change the setting under
# the cursor, Q / E (LB / RB) jump from group to group, and Enter takes an
# action (or a choice's next value). The pointer chooses a row by resting on
# it or clicking, sets a volume by clicking or dragging along its bar, and
# changes a choice by the marks at its sides. Changes apply at once and are
# stored by GameSettings when the hub reports them, so the page holds no
# primary action.
# A row opens the help: the game's rules that the screens keep out of their
# way, by topic. A HintMark ("?") on another page opens it at its topic. The
# last row ends the game, once a prompt has asked.
# The same page opens over the dungeon from its menu (DungeonMenu), so it
# reaches nothing outside itself: whoever shows it listens to its signals.
#
# The list and the stage are one focusable control that draws itself in a
# design space of 1520x686 scaled to its rect, in the colours and faces of
# the theme's SettingsStage type. At the base a child behind it darkens the
# whole screen so the words read on the hall; over the dungeon the menu has
# darkened the field already. The help window and the question before the
# end of the game are built of nodes, on layers of their own.

signal changed
# The help opened from its row; the screen showing the page updates its keys.
signal help_opened
# The help's close was clicked (its key hint, or the dimmed backdrop round
# the window); whoever shows the page closes it as its own Esc would.
signal help_close_requested
# The language row chose another language (already set in the settings);
# whoever shows the page rebuilds its words in it.
signal language_changed

const QUIT_BODY := "設定と拠点での強化は保存済みです。"
# In a run nothing of it is kept (the base saves at a run's start and end).
const QUIT_BODY_IN_RUN := "探索の途中で終了すると、この探索のレベル・強化・得た残響は残らず、最後に保存した拠点の状態に戻ります。"

# The help window: over the page and the fight's menu, under the quit's
# question; its backdrop, size and topic column.
const HELP_LAYER := 15
const HELP_SHADE := Color(0.01, 0.015, 0.025, 0.7)
const HELP_SIZE := Vector2(1280, 780)
const HELP_TOPICS_WIDTH := 260.0
# The settings' groups: [name, the rows it lists].
# The language (row 9) leads the last group, and is changed at the base only:
# the dungeon's menu leaves it out (rows_of).
const TABS := [["サウンド", [0, 1, 2, 3]], ["グラフィック", [4, 5]], ["その他", [9, 6, 7, 8]]]
const LANGUAGE_ROW := 9
const CAPTIONS := ["全体の音量", "音楽", "効果音", "環境音", "画面の揺れ", "画面モード", "操作の案内", "ヘルプ", "ゲームの終了", "言語"]
const NOTES := ["すべての音の大きさ。0%で消音。", "拠点・戦場・ボスの曲の大きさ。", "攻撃・被弾・取得・決定などの効果音の大きさ。", "戦場の空気の音の大きさ。", "攻撃が当たったときや被弾したときの画面の揺れ。「なし」で揺らさない。", "ウィンドウか全画面。", "戦闘中、画面の下に操作の一覧を出す。", "探索の決まりごとと操作。", "ゲームを閉じる。確かめてから終了する。", "画面の文字の言語。"]
# The help's topics, in order: [title, points], each point a line of its own
# behind a gilt star, as action games' tips are told, in the polite form
# the game's other messages use. HintMarks name the topics by index.
const TOPIC_RUN := 0
const TOPIC_GROWTH := 1
const TOPIC_CONTROLS := 2
const TOPIC_CODEX := 3
const TOPIC_BOONS := 4
const TOPIC_EVENTS := 5
const HELP := [
	["探索の流れ", [
		"探索はいつもLv 1から始まります。分岐マップで行き先を選び、章の最後のボスを倒すと踏破です。",
		"フィールドは決まった時間を生き延びるか、決まった数の敵を倒すと制圧です。目標は画面上に出ます。",
		"アリーナは、すべてのウェーブを倒すと制圧です。",
		"宝石を拾うとレベルが上がり、カード3枚（拠点の強化で4枚）から強化を1つ選びます。カードは光ってから選べます。",
		"エリアの報酬（強化・回復・残響）は、制圧すると受け取れます。どのエリアも、制圧すると報酬とは別に残響を少し得られます。",
		"HPは次のエリアへ持ち越します。レベルとレベルアップの強化は、探索が終わると消えます。",
		"最後の章を踏破すると「難易度の段階」が開きます。出撃画面で段階を上げるほど制約が重なり、持ち帰る残響が1段階ごとに1割増えます。",
		"開いている最高の段階で最後の章を踏破すると、次の段階が開きます。",
	]],
	["残響と強化", [
		"残響は、エリアの制圧、残響の報酬、精鋭の撃破、ボスの撃破で手に入ります。踏破・敗北・中断のどれでも、すべて持ち帰れます。",
		"拠点の「強化」で残響を使うと、ずっと続く強化を習得できます。",
		"強化は「残響の灯」から枝分かれします。左は体、右はレベルアップ、上はスキル、右上は武器、下は必殺技の枝です。",
		"線でつながった手前の節を習得すると、次の節を買えます。",
		"覚えたスキル・武器・必殺技は、拠点の「ステータス」で付け替えます。",
		"習得した強化は自動で保存されます。",
	]],
	["操作", [
		"攻撃はマウス（ゲームパッドは右スティック。倒していなければ移動の向き）の方向へ振ります。向きは足元の矢じりで分かります。続けて押すと連撃、長押しで溜め攻撃です。",
		"ダッシュ中は攻撃を受けません。",
		"敵の攻撃の前には床に赤い印が出ます。印が埋まる前に外へ出るか、ダッシュで抜けてください。",
		"必殺技は、攻撃を当てる・敵を倒す・傷を負うとゲージが溜まり、満ちると使えます。",
		"拠点では、矢印キー（ゲームパッドは十字キー）で選び、Enter（A）で決定、Esc（B）で戻ります。",
	]],
	["図鑑", [
		"拠点の「図鑑」で、探索中に出会った敵を見返せます。",
		"出会っていない敵は、影と「？？？」で表示されます。",
		"Q・E（ゲームパッドはLB・RB）で種類を切り替えます。",
	]],
	["強化と状態異常", [
		"レベルアップの強化は、連撃・範囲・回避・属性・状態異常・スキル・守りの系統に分かれ、自由に組み合わせられます。",
		"感電した敵は、4秒のあいだ歩く速さが3割落ちます。",
		"燃えている敵は、3秒のあいだ0.5秒ごとに、燃やした一撃の3割のダメージを受けます。",
		"連鎖雷と放電は雷刃を、燃え移りは業火・炎の技・霊火の足跡のどれかを持っていると、カードに出ます。",
		"「締めの一撃」は連撃の最後の段です。剣と槍は3段目、大槌は2段目です。",
		"取った強化は、探索中のメニュー（Esc、ゲームパッドはSTART）で見返せます。",
	]],
	["イベントと呪い", [
		"分岐マップのイベントは、戦闘のない立ち寄り先です。残響やHPと引き換えに、強化や回復を得られます。",
		"呪いは探索の終わりまで残ります。1つ受けるごとに、以後のエリアで得る残響が5割増えます。",
		"脆さ：受けるダメージが2増えます。",
		"鈍足：移動速度が12%落ちます。",
		"渇き：あらゆる回復が半分になります。",
		"第4章の浄めの泉では、残響を払って呪いを解けます。",
	]],
]
# The controls topic's table, over its points: [what it does, the keys, the
# gamepad's buttons], each key on a cap of its own.
const HELP_KEYS := [
	["移動", ["WASD", "矢印キー"], ["左スティック", "十字キー"]],
	["攻撃", ["左クリック"], ["X", "RT"]],
	["狙い", ["マウス"], ["右スティック"]],
	["回避", ["Space"], ["A", "RB"]],
	["スキル", ["Q", "E"], ["Y", "B"]],
	["必殺技", ["R"], ["LB"]],
	["強化を選ぶ", ["1", "2", "3", "クリック"], ["◀ / ▶", "A"]],
	["メニュー", ["Esc"], ["START"]],
]
# The point's gilt star: its box, as tall as a line of the words.
const POINT_MARKER := Vector2(14, 25)
# The chosen topic's glow: the widths of its halo's outlines, each laid over
# the last, so the halo is brightest by the letters.
const TOPIC_GLOW: Array[int] = [14, 9, 5]

const DESIGN := Vector2(1520.0, 686.0)
const SLIDERS: Array[int] = [0, 1, 2, 3]
const SHAKE_ROW := 4
const DISPLAY_ROW := 5
const CONTROLS_ROW := 6
const HELP_ROW := 7
const QUIT_ROW := 8
const ACTION_WORDS := {7: "開く", 8: "終了する"}
# The list, the stage, and the heights of a row and of a group's name.
const LIST := Rect2(56.0, 14.0, 640.0, 640.0)
const STAGE := Rect2(776.0, 24.0, 688.0, 400.0)
const ROW := 44.0
const HEAD := 50.0
const GROUP_GAP := 14.0
const TRACK_LEFT := 220.0
const TRACK_WIDTH := 300.0
const MOVE_TIME := UIMotion.SELECT_TIME
const CHANGE_TIME := UIMotion.GOLD_TIME
# The veil runs this far past the screen's edges, to cover it as the page
# slides in.
const VEIL_MARGIN := 40.0

var quit_prompt: ChoicePrompt
# Set by the dungeon's menu, so the prompt says what a run loses.
var in_run := false
# What ending the game does; tests replace it.
var quit_action := func(): get_tree().quit()
var settings: GameSettings
# The row under the cursor (its place in CAPTIONS).
var focused_row := 0
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
# The help's page, which slides in from the right when what it tells changes.
var help_words: VBoxContainer
# What the help's page tells now: telling it again (a click lands as a focus
# and a press) does not slide it.
var _shown_topic := -1
var _hover_topic := -1
var _veil: Control
var _from := 0
var _clock := 0.0
var _kicks := {}
# [rect, id] of every place the pointer can act on; a volume's bar by row.
var _zones: Array = []
var _tracks := {}
var _hover: Variant = null
# The row the pointer rests on and since when, and the volume being dragged.
var _rest_row := -1
var _rest_since := 0.0
var _dragging := -1
var _origin := Vector2.ZERO
var _zoom := 1.0
var _quiet := true


func _ready() -> void:
	theme_type_variation = &"SettingsStage"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not in_run:
		_veil = Control.new()
		_veil.name = "Veil"
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_veil.show_behind_parent = true
		_veil.draw.connect(_draw_veil)
		add_child(_veil)
	quit_prompt = ChoicePrompt.new()
	add_child(quit_prompt)
	# Over the dungeon's menu as well as the hub.
	quit_prompt.layer = 20
	quit_prompt.confirmed.connect(func():
		quit_prompt.hide()
		quit_action.call())
	quit_prompt.canceled.connect(func():
		quit_prompt.hide()
		grab_focus())
	_build_help()
	resized.connect(_fit)
	theme_changed.connect(_fit)
	visibility_changed.connect(_fit)
	get_viewport().size_changed.connect(_fit.call_deferred)
	_fit()


# Places the design space in the rect, and the veil over the screen.
func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	if _veil != null:
		var screen := Rect2(Vector2.ZERO, size)
		if is_inside_tree():
			screen = get_global_transform().affine_inverse() * get_viewport_rect()
		_veil.position = screen.position - Vector2.ONE * VEIL_MARGIN
		_veil.size = screen.size + Vector2.ONE * VEIL_MARGIN * 2.0
		_veil.queue_redraw()
	queue_redraw()


# --- The settings ---

# A group's rows in order; in a run, without the language, whose change
# rebuilds the base's words.
func rows_of(group: int) -> Array[int]:
	var shown: Array[int] = []
	shown.assign(TABS[group][1])
	if in_run:
		shown.erase(LANGUAGE_ROW)
	return shown


# Every row shown, in the list's order.
func shown_rows() -> Array[int]:
	var shown: Array[int] = []
	for group in TABS.size():
		shown.append_array(rows_of(group))
	return shown


func group_of(row: int) -> int:
	for group in TABS.size():
		if (TABS[group][1] as Array).has(row):
			return group
	return 0


# &"slider" (a volume), &"cycle" (one of a few choices) or &"action".
static func kind(row: int) -> StringName:
	if SLIDERS.has(row):
		return &"slider"
	return &"action" if ACTION_WORDS.has(row) else &"cycle"


# A volume from 0 to 100.
func percent(row: int) -> int:
	return settings.volume_percent([settings.volume, settings.music_volume, settings.effects_volume, settings.ambience_volume][row])


# A choice's names, as shown.
func choices(row: int) -> Array[String]:
	var names: Array[String] = []
	match row:
		SHAKE_ROW:
			names.assign(GameSettings.SHAKE_NAMES.map(func(name: String) -> String: return tr(name)))
		DISPLAY_ROW:
			names.assign(GameSettings.DISPLAY_NAMES.map(func(name: String) -> String: return tr(name)))
		CONTROLS_ROW:
			names.assign(GameSettings.CONTROLS_NAMES)
		LANGUAGE_ROW:
			names.assign(GameSettings.LANGUAGE_NAMES)
	return names


# Which of a choice's names is set.
func chosen(row: int) -> int:
	match row:
		SHAKE_ROW:
			return settings.shake_level
		DISPLAY_ROW:
			return 1 if settings.fullscreen else 0
		CONTROLS_ROW:
			return 0 if settings.show_controls else 1
		LANGUAGE_ROW:
			return GameSettings.LANGUAGES.find(settings.shown_language())
	return 0


# The row's value as words: "80%", "標準", "開く".
func value_text(row: int) -> String:
	if settings == null:
		return ""
	match kind(row):
		&"slider":
			return "%d%%" % percent(row)
		&"cycle":
			return choices(row)[chosen(row)]
	return tr(ACTION_WORDS[row])


# What the setting under the cursor does.
func note_text() -> String:
	return tr(NOTES[focused_row])


# Sets a volume (0 to 100, in steps of 5) or a choice, applies it at once
# and reports it; false when nothing changed.
func put(row: int, to: int) -> bool:
	if settings == null:
		return false
	if kind(row) == &"slider":
		var level := clampi(roundi(to / 5.0) * 5, 0, 100)
		if level == percent(row):
			return false
		match row:
			0:
				settings.volume = level / 100.0
			1:
				settings.music_volume = level / 100.0
			2:
				settings.effects_volume = level / 100.0
			3:
				settings.ambience_volume = level / 100.0
		settings.apply_volume()
	elif kind(row) == &"cycle":
		var choice := clampi(to, 0, choices(row).size() - 1)
		if choice == chosen(row):
			return false
		match row:
			SHAKE_ROW:
				settings.shake_level = choice
			DISPLAY_ROW:
				settings.fullscreen = choice == 1
				settings.apply_display()
			CONTROLS_ROW:
				settings.show_controls = choice == 0
			LANGUAGE_ROW:
				settings.language = GameSettings.LANGUAGES[choice]
	else:
		return false
	_kick(&"change")
	_sound(&"ui_move")
	if row == LANGUAGE_ROW:
		language_changed.emit()
	else:
		changed.emit()
	queue_redraw()
	return true


# A step up or down for the setting under the cursor: 5% of a volume, the
# next or the last of a choice (round again past its ends, but for the
# language, which stops at them).
func change(by: int) -> bool:
	match kind(focused_row):
		&"slider":
			return put(focused_row, percent(focused_row) + by * 5)
		&"cycle":
			var count := choices(focused_row).size()
			var to := chosen(focused_row) + by
			return put(focused_row, clampi(to, 0, count - 1) if focused_row == LANGUAGE_ROW else posmod(to, count))
	return false


# Enter (A): the help opens, the game asks before it ends, or a choice
# takes its next value.
func accept() -> void:
	match focused_row:
		HELP_ROW:
			open_help(TOPIC_RUN)
			help_opened.emit()
		QUIT_ROW:
			ask_quit()
		_:
			if kind(focused_row) == &"cycle":
				change(1)


# Moves the cursor to a row.
func choose(row: int) -> void:
	if row == focused_row or not shown_rows().has(row):
		return
	_from = focused_row
	focused_row = row
	_kick(&"move")
	_sound(&"ui_move")
	queue_redraw()


# Moves the cursor along the list.
func step(by: int) -> void:
	var shown := shown_rows()
	choose(shown[clampi(shown.find(focused_row) + by, 0, shown.size() - 1)])


# Goes to the first row of the next group (the previous with -1).
func turn(by: int) -> void:
	show_group(posmod(group_of(focused_row) + by, TABS.size()))


# Puts the cursor on a group's first row.
func show_group(group: int) -> void:
	choose(rows_of(group)[0])


func refresh(value: GameSettings) -> void:
	settings = value
	queue_redraw()


func focus_first() -> void:
	if help_shown:
		close_help()
	focused_row = shown_rows()[0]
	_from = focused_row
	grab_focus()
	queue_redraw()


# Puts the cursor on the language's row.
func focus_language() -> void:
	focused_row = LANGUAGE_ROW
	_from = focused_row
	grab_focus()
	queue_redraw()


# Opening the page: the rows arrive top first.
func play_entrance() -> void:
	_kick(&"open")


func _sound(cue: StringName) -> void:
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, cue, -22.0)


# --- Clock ---

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_quiet = false
	_clock += delta
	# As in the lobby and the help, resting the pointer on a row chooses it.
	if _rest_row >= 0 and _rest_row != focused_row and _clock - _rest_since >= HubLobby.HOVER_INTENT and not help_shown and not quit_prompt.visible:
		choose(_rest_row)
	queue_redraw()


func _kick(what: StringName) -> void:
	_kicks[what] = _clock


func _since(what: StringName) -> float:
	return _clock - float(_kicks.get(what, -1000.0))


func _eased(what: StringName, time: float) -> float:
	var share := clampf(_since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


# A value's small jump as it changes (1 at rest).
func _pop() -> float:
	return 1.0 + 0.18 * (1.0 - _eased(&"change", CHANGE_TIME))


# --- Input ---

func _gui_input(event: InputEvent) -> void:
	if help_shown or quit_prompt.visible:
		return
	if event is InputEventMouseMotion:
		var zone: Variant = _zone_at(event.position)
		_hover = zone
		var row: int = (zone as Array)[1][1] if zone != null else -1
		if row != _rest_row:
			_rest_row = row
			_rest_since = _clock
		if _dragging >= 0:
			_drag_to(event.position)
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not event.pressed:
			_dragging = -1
			return
		grab_focus()
		var zone: Variant = _zone_at(event.position)
		if zone != null:
			_press((zone as Array)[1], event.position)
		accept_event()
		return
	var handled := true
	if event.is_action_pressed(&"ui_up", true):
		step(-1)
	elif event.is_action_pressed(&"ui_down", true):
		step(1)
	elif event.is_action_pressed(&"ui_left", true):
		change(-1)
	elif event.is_action_pressed(&"ui_right", true):
		change(1)
	elif event.is_action_pressed(&"ui_accept"):
		accept()
	elif _pressed(event, KEY_Q, JOY_BUTTON_LEFT_SHOULDER):
		turn(-1)
	elif _pressed(event, KEY_E, JOY_BUTTON_RIGHT_SHOULDER):
		turn(1)
	else:
		handled = false
	if handled:
		accept_event()


func _pressed(event: InputEvent, key: Key, button: int) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == key
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


# A place the pointer clicked: [&"item", row] (the cursor goes there),
# [&"step", row, by], [&"track", row] (a volume's bar, set where it was
# clicked and dragged from there) and [&"act", row].
func _press(id: Variant, at := Vector2.ZERO) -> void:
	var what: Array = id
	choose(what[1])
	match what[0]:
		&"step":
			change(what[2])
		&"track":
			_dragging = what[1]
			_drag_to(at)
		&"act":
			accept()


# Sets the volume being dragged from where the pointer is along its bar.
func _drag_to(point: Vector2) -> void:
	if not _tracks.has(_dragging):
		return
	var track: Rect2 = _tracks[_dragging]
	var x := (point.x - _origin.x) / _zoom
	put(_dragging, roundi(clampf((x - track.position.x) / track.size.x, 0.0, 1.0) * 100.0))


func _zone(rect: Rect2, id: Variant) -> void:
	_zones.append([rect, id])


func _zone_at(point: Vector2) -> Variant:
	var at := (point - _origin) / _zoom
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(at):
			return _zones[index]
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = null
		_rest_row = -1
		_dragging = -1


# --- Drawing ---

func _colour(item: StringName, share := 1.0) -> Color:
	var colour := get_theme_color(item)
	return Color(colour, colour.a * share)


func _face(item: StringName) -> Font:
	return get_theme_font(item)


func _size(item: StringName) -> int:
	return get_theme_font_size(item)


func _words(at: Vector2, words: String, face: StringName, size: StringName, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_face(face), at, words, align, width, _size(size), colour)


func _width(words: String, face: StringName, size: StringName) -> float:
	return _face(face).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(size)).x


# Japanese breaks between any two letters; a script with spaces, at them.
func _breaks() -> int:
	return TextServer.BREAK_MANDATORY | (TextServer.BREAK_GRAPHEME_BOUND if TranslationServer.get_locale().begins_with("ja") else TextServer.BREAK_WORD_BOUND)


func _plate(rect: Rect2, fill: Color, edge: Color, corner := 4) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1 if edge.a > 0.0 else 0)
	box.set_corner_radius_all(corner)
	draw_style_box(box, rect)


# A rect whose colour runs from `first` at its left to `last` at its right.
func _fall(canvas: CanvasItem, rect: Rect2, first: Color, last: Color) -> void:
	canvas.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([first, last, last, first]))


# A soft round light.
func _glow(centre: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([colour])
	for index in 33:
		points.append(centre + Vector2.from_angle(TAU * index / 32.0) * radius)
		colours.append(Color(colour, 0.0))
	for index in 32:
		draw_polygon(PackedVector2Array([points[0], points[index + 1], points[index + 2]]), PackedColorArray([colours[0], colours[index + 1], colours[index + 2]]))


# The veil over the hall: dark all over, darker still under the list.
func _draw_veil() -> void:
	var room := Rect2(Vector2.ZERO, _veil.size)
	_veil.draw_rect(room, _colour(&"veil", 0.78))
	_fall(_veil, Rect2(0.0, 0.0, room.size.x * 0.56, room.size.y), _colour(&"veil", 0.5), _colour(&"veil", 0.0))


func _draw() -> void:
	_zones.clear()
	_tracks.clear()
	if settings == null:
		return
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	var places := {}
	var y := LIST.position.y
	var order := 0
	for group in TABS.size():
		var rows := rows_of(group)
		if rows.is_empty():
			continue
		var here := group_of(focused_row) == group
		_words(Vector2(LIST.position.x, y + 30.0), tr(TABS[group][0]), &"title_font", &"head_size", _colour(&"gold") if here else _colour(&"dim"))
		HubUI.trail(self, Vector2(LIST.position.x, y + 42.0), Vector2(LIST.end.x, y + 42.0), _colour(&"line", 0.6 if here else 0.25))
		y += HEAD
		for row in rows:
			places[row] = y
			y += ROW
		y += GROUP_GAP
	# The cursor's bar slides from the row it left.
	var bar := lerpf(places.get(_from, places[focused_row]), places[focused_row], _eased(&"move", MOVE_TIME))
	_fall(self, Rect2(LIST.position.x - 24.0, bar, LIST.size.x + 48.0, ROW), _colour(&"line", 0.22 if has_focus() else 0.10), _colour(&"line", 0.0))
	draw_rect(Rect2(LIST.position.x - 24.0, bar, 3.0, ROW), _colour(&"gold") if has_focus() else _colour(&"dim"))
	for row: int in shown_rows():
		# The rows arrive top first as the page opens.
		var arrived := clampf((_since(&"open") - UIMotion.ROW_STAGGER * order) / UIMotion.ROW_TIME, 0.0, 1.0)
		_draw_row(row, Rect2(LIST.position.x, places[row], LIST.size.x, ROW), 1.0 - pow(1.0 - arrived, 3.0))
		order += 1
	_draw_stage()
	draw_set_transform(Vector2.ZERO)


func _draw_row(row: int, rect: Rect2, shown: float) -> void:
	var lit := row == focused_row
	var rested: bool = _hover is Array and (_hover as Array)[1][1] == row
	var ink := _colour(&"pale" if lit or rested else &"dim", shown)
	var base := rect.position.y + 29.0
	_zone(rect, [&"item", row])
	_words(Vector2(rect.position.x, base), tr(CAPTIONS[row]), &"bold_font" if lit else &"font", &"row_size", _colour(&"gold", shown) if lit else ink)
	match kind(row):
		&"slider":
			var track := Rect2(rect.position.x + TRACK_LEFT, rect.get_center().y - 2.0, TRACK_WIDTH, 4.0)
			var level := percent(row) / 100.0
			draw_rect(track, _colour(&"track", shown))
			draw_rect(Rect2(track.position, Vector2(track.size.x * level, 4.0)), _colour(&"gold", shown) if lit else _colour(&"line", 0.8 * shown))
			var knob := Vector2(track.position.x + track.size.x * level, rect.get_center().y)
			if lit:
				_glow(knob, 22.0, _colour(&"gold", 0.4))
			HubUI.lozenge(self, knob, 8.0 * (_pop() if lit else 1.0), _colour(&"gold", shown) if lit else _colour(&"line", shown))
			_words(Vector2(rect.position.x, base), value_text(row), &"title_font", &"value_size", ink, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x)
			_tracks[row] = track
			_zone(Rect2(track.position.x - 12.0, rect.position.y, track.size.x + 24.0, ROW), [&"track", row])
		&"cycle":
			var words := value_text(row)
			var wide := maxf(110.0, _width(words, &"bold_font", &"row_size"))
			var right := rect.end.x
			_words(Vector2(right - wide - 30.0, base), words, &"bold_font", &"row_size", ink, HORIZONTAL_ALIGNMENT_CENTER, wide)
			var at_first := row == LANGUAGE_ROW and chosen(row) == 0
			var at_last := row == LANGUAGE_ROW and chosen(row) == choices(row).size() - 1
			_words(Vector2(right - wide - 62.0, base), "〈", &"font", &"row_size", _colour(&"gold", shown) if lit and not at_first else _colour(&"dim", 0.5 * shown))
			_words(Vector2(right - 22.0, base), "〉", &"font", &"row_size", _colour(&"gold", shown) if lit and not at_last else _colour(&"dim", 0.5 * shown))
			_zone(Rect2(right - wide - 72.0, rect.position.y, 46.0, ROW), [&"step", row, -1])
			_zone(Rect2(right - 36.0, rect.position.y, 46.0, ROW), [&"step", row, 1])
		&"action":
			_words(Vector2(rect.position.x, base), value_text(row) + "　›", &"bold_font", &"row_size", (_colour(&"warn", shown) if row == QUIT_ROW else _colour(&"gold", shown)) if lit else ink, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x)
			_zone(Rect2(rect.end.x - 170.0, rect.position.y, 170.0, ROW), [&"act", row])


# The stage: what the setting under the cursor does, shown; under it, the
# setting's name and value, and what it does in words.
func _draw_stage() -> void:
	_plate(STAGE, _colour(&"ink"), _colour(&"line", 0.5))
	draw_rect(STAGE.grow(-7.0), _colour(&"line", 0.18), false, 1.0)
	_words(STAGE.position + Vector2(22.0, 32.0), tr("実演"), &"font", &"label_size", _colour(&"dim"))
	var centre := STAGE.get_center() + Vector2(0.0, 10.0)
	match focused_row:
		0, 1, 2, 3:
			_show_sound(centre)
		SHAKE_ROW:
			_show_shake(centre)
		DISPLAY_ROW:
			_show_screen(centre)
		LANGUAGE_ROW:
			_show_language(centre)
		CONTROLS_ROW:
			_show_guide(centre)
		HELP_ROW:
			_show_help()
		_:
			_show_quit(centre)
	var fade := 0.3 + 0.7 * _eased(&"move", MOVE_TIME)
	var y := STAGE.end.y + 58.0
	_words(Vector2(STAGE.position.x, y), tr(CAPTIONS[focused_row]), &"title_font", &"name_size", _colour(&"pale", fade))
	draw_string(_face(&"title_font"), Vector2(STAGE.position.x, y), value_text(focused_row), HORIZONTAL_ALIGNMENT_RIGHT, STAGE.size.x, int(_size(&"name_size") * _pop()), _colour(&"warn" if focused_row == QUIT_ROW else &"gold", fade))
	HubUI.trail(self, Vector2(STAGE.position.x, y + 20.0), Vector2(STAGE.end.x, y + 20.0), _colour(&"line", 0.4))
	draw_multiline_string(_face(&"font"), Vector2(STAGE.position.x, y + 54.0), note_text(), HORIZONTAL_ALIGNMENT_LEFT, STAGE.size.x, _size(&"body_size"), 3, _colour(&"pale", 0.92 * fade), _breaks())


# A bell whose rings carry as far as the volume under the cursor (under the
# volume of everything), beside the four levels.
func _show_sound(centre: Vector2) -> void:
	var bell := centre - Vector2(170.0, 0.0)
	var loud := percent(focused_row) / 100.0 * (percent(0) / 100.0 if focused_row != 0 else 1.0)
	for index in 5:
		var out := fmod(_clock * 0.6 + index / 5.0, 1.0)
		if loud > 0.0:
			draw_arc(bell, 30.0 + 150.0 * out * loud, -PI * 0.42, PI * 0.42, 32, _colour(&"gold", (1.0 - out) * (0.25 + 0.75 * loud)), 2.0, true)
	draw_circle(bell, 24.0, _colour(&"gold") if loud > 0.0 else _colour(&"dim"))
	draw_circle(bell, 15.0, _colour(&"ink"))
	if loud == 0.0:
		draw_line(bell + Vector2(-34.0, 34.0), bell + Vector2(34.0, -34.0), _colour(&"warn"), 4.0, true)
		_words(bell + Vector2(-80.0, 74.0), tr("消音"), &"bold_font", &"body_size", _colour(&"warn"), HORIZONTAL_ALIGNMENT_CENTER, 160.0)
	for index in SLIDERS.size():
		var row := SLIDERS[index]
		var x := centre.x + 70.0 + index * 56.0
		var level := percent(row) / 100.0
		draw_rect(Rect2(x, centre.y - 110.0, 24.0, 220.0), _colour(&"track"))
		draw_rect(Rect2(x, centre.y + 110.0 - 220.0 * level, 24.0, 220.0 * level), _colour(&"gold") if row == focused_row else _colour(&"line", 0.55))
		if row == focused_row:
			HubUI.mark(self, Vector2(x + 12.0, centre.y + 128.0), 5.0, _colour(&"gold"))


# A frame struck every second or so, shaking as hard as the shake is set.
func _show_shake(centre: Vector2) -> void:
	var beat := fmod(_clock, 1.3)
	var force := GameSettings.SHAKE_SCALES[settings.shake_level] * maxf(0.0, 1.0 - beat / 0.35)
	var shift := Vector2(sin(_clock * 71.0), cos(_clock * 53.0)) * 16.0 * force
	var frame := Rect2(centre - Vector2(210.0, 120.0) + shift, Vector2(420.0, 240.0))
	draw_rect(frame, _colour(&"scene"))
	draw_rect(frame, _colour(&"line", 0.7), false, 2.0)
	draw_rect(Rect2(frame.position.x, frame.end.y - 60.0, frame.size.x, 60.0), _colour(&"prop"))
	var hero := frame.position + Vector2(150.0, 158.0)
	draw_circle(hero, 18.0, _colour(&"pale"))
	draw_rect(Rect2(hero + Vector2(-12.0, 16.0), Vector2(24.0, 34.0)), _colour(&"pale"))
	var foe := frame.position + Vector2(290.0, 150.0)
	draw_rect(Rect2(foe - Vector2(26.0, 26.0), Vector2(52.0, 62.0)), _colour(&"foe"))
	if beat < 0.22:
		var cut := 1.0 - beat / 0.22
		draw_arc(hero + Vector2(40.0, 6.0), 86.0, -0.9, 0.7, 20, _colour(&"pale", cut), 6.0, true)
		draw_circle(foe, 40.0 * (1.0 - cut) + 12.0, _colour(&"gold", 0.6 * cut))


# A monitor: a window on it, or the whole of it.
func _show_screen(centre: Vector2) -> void:
	var monitor := Rect2(centre - Vector2(200.0, 130.0), Vector2(400.0, 230.0))
	draw_rect(monitor.grow(8.0), _colour(&"prop"))
	draw_rect(monitor, _colour(&"scene"))
	draw_rect(Rect2(centre.x - 30.0, monitor.end.y + 8.0, 60.0, 26.0), _colour(&"prop"))
	draw_rect(Rect2(centre.x - 80.0, monitor.end.y + 34.0, 160.0, 8.0), _colour(&"prop"))
	var grow := _eased(&"change", CHANGE_TIME)
	var small := Rect2(monitor.position + Vector2(70.0, 44.0), Vector2(260.0, 150.0))
	var a := monitor if not settings.fullscreen else small
	var b := small if not settings.fullscreen else monitor
	var game := Rect2(a.position.lerp(b.position, grow), a.size.lerp(b.size, grow))
	var art := Chapters.ALL[0].illustration
	if art != null:
		draw_texture_rect(art, game, false, _colour(&"pale"))
	if not settings.fullscreen:
		draw_rect(Rect2(game.position - Vector2(0.0, 16.0), Vector2(game.size.x, 16.0)), _colour(&"pale"))
		draw_circle(game.position + Vector2(game.size.x - 12.0, -8.0), 4.0, _colour(&"foe"))
	draw_rect(game, _colour(&"gold", 0.8), false, 2.0)


# The languages, the one shown marked, and a line of the game in it.
func _show_language(centre: Vector2) -> void:
	var names := choices(LANGUAGE_ROW)
	for index in names.size():
		var on := index == chosen(LANGUAGE_ROW)
		_words(Vector2(centre.x - 200.0 + index * 200.0, centre.y - 96.0), names[index], &"title_font", &"value_size", _colour(&"gold") if on else _colour(&"dim", 0.6), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		if on:
			draw_line(Vector2(centre.x - 160.0 + index * 200.0, centre.y - 82.0), Vector2(centre.x - 40.0 + index * 200.0, centre.y - 82.0), _colour(&"gold"), 2.0)
	var first := Chapters.ALL[0]
	_words(Vector2(STAGE.position.x, centre.y + 4.0), tr(first.display_name), &"title_font", &"name_size", _colour(&"pale"), HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x)
	draw_multiline_string(_face(&"font"), Vector2(STAGE.position.x + 60.0, centre.y + 52.0), tr(first.description), HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x - 120.0, _size(&"body_size"), 2, _colour(&"dim"), _breaks())


# The fight's foot, with its line of keys or without.
func _show_guide(centre: Vector2) -> void:
	var frame := Rect2(centre - Vector2(250.0, 130.0), Vector2(500.0, 250.0))
	draw_rect(frame, _colour(&"scene"))
	draw_rect(frame, _colour(&"line", 0.6), false, 1.5)
	draw_circle(frame.get_center() - Vector2(0.0, 20.0), 16.0, _colour(&"pale"))
	draw_rect(Rect2(frame.position + Vector2(18.0, 16.0), Vector2(150.0, 12.0)), _colour(&"foe"))
	var y := frame.end.y - 36.0
	if not settings.show_controls:
		draw_dashed_line(Vector2(frame.position.x + 12.0, y + 11.0), Vector2(frame.end.x - 12.0, y + 11.0), _colour(&"dim", 0.6), 1.5, 8.0)
		return
	var x := frame.position.x + 22.0
	for entry: Array in [HELP_KEYS[0], HELP_KEYS[1], HELP_KEYS[3], HELP_KEYS[4]]:
		var cap: String = tr(entry[1][0])
		var deed: String = tr(entry[0])
		var wide := _width(cap, &"bold_font", &"key_size") + 12.0
		if x + wide + _width(deed, &"font", &"key_size") + 8.0 > frame.end.x - 14.0:
			break
		_plate(Rect2(x, y, wide, 22.0), _colour(&"prop"), _colour(&"dim", 0.6), 3)
		_words(Vector2(x + 6.0, y + 16.0), cap, &"bold_font", &"key_size", _colour(&"pale"))
		_words(Vector2(x + wide + 6.0, y + 16.0), deed, &"font", &"key_size", _colour(&"dim"))
		x += wide + _width(deed, &"font", &"key_size") + 22.0
	draw_rect(Rect2(frame.position.x + 12.0, y - 8.0, frame.size.x - 24.0, 38.0), _colour(&"gold", 0.8), false, 1.5)


# The help's topics.
func _show_help() -> void:
	for index in HELP.size():
		var at := Vector2(STAGE.position.x + 80.0 + (index % 2) * 300.0, STAGE.position.y + 110.0 + (index / 2) * 92.0)
		HubUI.mark(self, at + Vector2(0.0, -8.0), 6.0, _colour(&"gold"))
		_words(at + Vector2(22.0, 0.0), tr(HELP[index][0]), &"title_font", &"value_size", _colour(&"pale"))


# Ending the game: a door, and what is kept (or, in a run, what is lost).
func _show_quit(centre: Vector2) -> void:
	var door := Rect2(centre - Vector2(46.0, 130.0), Vector2(92.0, 150.0))
	draw_rect(door, _colour(&"veil"))
	draw_rect(door, _colour(&"warn", 0.8), false, 2.0)
	draw_circle(door.position + Vector2(74.0, 80.0), 5.0, _colour(&"warn"))
	draw_multiline_string(_face(&"font"), Vector2(STAGE.position.x + 50.0, centre.y + 70.0), tr(QUIT_BODY_IN_RUN if in_run else QUIT_BODY), HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x - 100.0, _size(&"body_size"), 3, _colour(&"pale"), _breaks())


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
	var heading := HubUI.label(stack, tr("ヘルプ"), &"TitleLabel")
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
		var row := HubUI.button(topic_rows, tr(HELP[index][0]), select_topic.bind(index), &"HelpTopic")
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
	for title: String in ["", tr("キーボード"), tr("ゲームパッド")]:
		HubUI.label(help_keys, title, &"MutedLabel").autowrap_mode = TextServer.AUTOWRAP_OFF
	for entry: Array in HELP_KEYS:
		var action := HubUI.label(help_keys, tr(entry[0]), &"BodyLabel")
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
				var name := HubUI.label(cap, tr(key), &"HelpKeyName")
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
	guide.add_hint("↑ / ↓", "▲ / ▼", tr("話題"))
	help_close_hint = guide.add_hint("Esc", "B", tr("閉じる"), func(): help_close_requested.emit())
	# A page hidden behind another takes its help window with it.
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			help_layer.hide())


# Asks before ending the game; Esc or the cancel button keeps playing. The
# focus waits on the cancel button, so a second Enter never ends the game.
func ask_quit() -> void:
	quit_prompt.ask("", tr("ゲームを終了しますか？"), tr(QUIT_BODY_IN_RUN if in_run else QUIT_BODY), tr("ゲームを終了する"), tr("戻る"), true)
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
	focused_row = HELP_ROW
	_from = focused_row
	grab_focus()


func select_topic(index: int) -> void:
	selected_topic = index
	for other in topic_buttons.size():
		topic_buttons[other].set_pressed_no_signal(other == index)
	topic_rows.queue_redraw()
	if index == _shown_topic:
		return
	_shown_topic = index
	help_title.text = tr(HELP[index][0])
	help_keys.visible = index == TOPIC_CONTROLS
	for child in help_points.get_children():
		child.free()
	for point: String in HELP[index][1]:
		_help_point(tr(point))
	UIMotion.of(help_words).slide_in()


# One of the topic's points: a small gilt star by its first line, then
# the words.
func _help_point(text: String) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"HelpPoint"
	help_points.add_child(row)
	var marker := Control.new()
	marker.custom_minimum_size = POINT_MARKER
	marker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(func(): HubUI.mark(marker, marker.size * 0.5, 4.0, marker.get_theme_color(&"rail", &"HubLobby")))
	row.add_child(marker)
	var words := HubUI.label(row, text, &"DescriptionLabel")
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL


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
