extends CanvasLayer

# The base between runs: the lobby (HubLobby) over the hall painting, and the
# pages it opens: where to set out (HubSortie), the lasting upgrades
# (MetaUpgradePage), the status and skill slots (HubStatus), the
# encyclopedia (HubCodex) and the settings (HubSettings). Tab (View) goes
# between the upgrades and the status, and from the departure to the status
# and back. The header holds the page's name and the echo held; the footer,
# the keys. It shows a MetaProgress and asks Main to change it
# (start_requested, upgrade_requested, equip_requested); Main saves,
# refreshes it and calls present_action or present_equip for the moment.

signal start_requested
signal upgrade_requested(id: StringName)
signal equip_requested(slot: int, id: StringName)
signal settings_changed
# The settings chose another language; Main rebuilds the hub in it.
signal language_changed

# How close the header and the footer come to the screen's edges.
const EDGE_X := 40.0
const EDGE_TOP := 22.0
const EDGE_BOTTOM := 16.0
# The lobby's upper row of keys stands this far over the footer's.
const LOBBY_ROW_RISE := 30.0
# Page content for the 1600×900 base: 80px of hall either side, and the
# whole block shrinks together on smaller screens.
const CONTENT_SIZE := Vector2(1440, 810)

# The chapter the lobby shows and the departure opens on: the frontier at
# first, then the last one chosen, or one that has just opened.
var chapter: ChapterData = Chapters.ALL[0]
# The difficulty step the departure sets out at (0 until the steps open).
var step := 0
var echo_label: Label
var feedback: Label
var start_button: Button
var upgrade_button: Button
var save_label: Label
var back_button: Button
# The lobby's way out of the game: Esc (B) there asks before quitting, with
# the settings page's own words and action.
var quit_prompt: ChoicePrompt
# The lobby's keys stand in two rows, this one over the footer's: three hints
# in one row would run out past the lobby's rail into the hall.
var lobby_guide: KeyGuide
var title_label: Label
var home_page: HubLobby
var decide_button: Button
var hero_button: Button
var hero_speech: Panel
var settings := GameSettings.new()
var upgrade_page: MetaUpgradePage
var status_page: HubStatus
var settings_page: HubSettings
var codex_page: HubCodex
var sortie_page: HubSortie
var page := "home"
# The page a "?" mark opened the help from, which back returns to.
var help_return := ""
# The departure, when Tab (View) went from it to the status: back returns.
var status_return := ""
# The chapters open at the last refresh, to notice one that has just opened.
var _open_chapters: Array[ChapterData] = []
var purse: GoldPurse
var key_guide: KeyGuide
var _meta: MetaProgress
var _content: Control
var _page_host: Control
var _shell: VBoxContainer
var _frame: Control
var _ambience: HubAmbience
var _title_block: HBoxContainer


func _ready() -> void:
	# HintMarks find the hub here to open the help at their topic.
	add_to_group(&"hub")
	var background := TextureRect.new()
	background.texture = preload("res://art/hub/lobby_hall.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.16)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Flickering light and dust over the painting, beneath every panel.
	_ambience = HubAmbience.new()
	add_child(_ambience)
	_content = Control.new()
	_content.name = "Content"
	_content.theme = HubTheme.create()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_resize()
	get_viewport().size_changed.connect(_resize)
	_shell = VBoxContainer.new()
	_content.add_child(_shell)
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The header and the footer stand near the screen's edges, outside the
	# page block, in a layer of their own above the lobby; the shell keeps
	# their room so the pages sit where they did.
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.theme = _content.theme
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header_room := Control.new()
	header_room.custom_minimum_size.y = 56
	header_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(header_room)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(header)
	header.anchor_right = 1.0
	header.offset_left = EDGE_X
	header.offset_right = -EDGE_X
	header.offset_top = EDGE_TOP
	# Header: the screen's name on the left, the echo held on the right.
	_title_block = HBoxContainer.new()
	_title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_block)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_block.add_child(heading)
	title_label = HubUI.label(heading, tr("旅支度の間"), &"TitleLabel")
	purse = GoldPurse.new()
	purse.custom_minimum_size.x = 220
	purse.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	purse.tooltip_text = tr("残響：探索で得て、拠点の強化に使う")
	header.add_child(purse)
	echo_label = purse.value_label
	_page_host = Control.new()
	_page_host.custom_minimum_size.y = 600
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_child(_page_host)
	_build_home()
	# The pages' slabs run off the screen's edges, their contents lined up
	# with the title and the echo above them.
	var bleed := EDGE_X - (get_viewport().get_visible_rect().size.x - CONTENT_SIZE.x) * 0.5
	upgrade_page = _page(MetaUpgradePage.new(), &"upgrade") as MetaUpgradePage
	upgrade_page.offset_left = bleed
	upgrade_page.offset_right = -bleed
	upgrade_page.buy_requested.connect(func(id: StringName): upgrade_requested.emit(id))
	status_page = _page(HubStatus.new(), &"status") as HubStatus
	status_page.offset_left = bleed
	status_page.offset_right = -bleed
	status_page.equip_requested.connect(func(slot: int, id: StringName): equip_requested.emit(slot, id))
	status_page.view_changed.connect(func():
		if page == "status":
			_status_hints())
	codex_page = _page(HubCodex.new(), &"codex") as HubCodex
	codex_page.offset_left = bleed
	codex_page.offset_right = -bleed
	sortie_page = _page(HubSortie.new(), &"sortie") as HubSortie
	sortie_page.offset_left = bleed
	sortie_page.offset_right = -bleed
	sortie_page.chapter_chosen.connect(func(chosen: ChapterData): chapter = chosen)
	sortie_page.step_chosen.connect(func(chosen: int): step = chosen)
	sortie_page.departure_requested.connect(func(chosen: ChapterData):
		chapter = chosen
		start_requested.emit())
	settings_page = _page(HubSettings.new(), &"settings") as HubSettings
	settings_page.offset_left = bleed
	settings_page.offset_right = -bleed
	settings_page.changed.connect(func(): settings_changed.emit())
	settings_page.help_opened.connect(_settings_hints)
	settings_page.help_close_requested.connect(go_back)
	settings_page.language_changed.connect(func(): language_changed.emit())
	# Footer: the key guide at the bottom left, the same on every screen.
	var footer_room := Control.new()
	footer_room.custom_minimum_size.y = 44
	footer_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(footer_room)
	var footer := HBoxContainer.new()
	footer.theme_type_variation = &"KeyGuide"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(footer)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.anchor_right = 1.0
	footer.offset_left = EDGE_X
	footer.offset_right = -EDGE_X
	footer.offset_top = -EDGE_BOTTOM - 44
	footer.offset_bottom = -EDGE_BOTTOM
	key_guide = KeyGuide.new()
	key_guide.custom_minimum_size.y = 44
	footer.add_child(key_guide)
	back_button = key_guide.add_hint("Esc", "B", tr("戻る"), go_back)
	lobby_guide = KeyGuide.new()
	lobby_guide.custom_minimum_size.y = 44
	_frame.add_child(lobby_guide)
	lobby_guide.anchor_top = 1.0
	lobby_guide.anchor_bottom = 1.0
	lobby_guide.offset_left = EDGE_X
	lobby_guide.offset_bottom = -EDGE_BOTTOM - LOBBY_ROW_RISE
	lobby_guide.offset_top = lobby_guide.offset_bottom - 44
	lobby_guide.add_hint("↑ / ↓", "▲ / ▼", tr("選ぶ"))
	lobby_guide.hide()
	quit_prompt = ChoicePrompt.new()
	add_child(quit_prompt)
	quit_prompt.layer = 20
	quit_prompt.confirmed.connect(func():
		quit_prompt.hide()
		settings_page.quit_action.call())
	quit_prompt.canceled.connect(func():
		quit_prompt.hide()
		if page == "home":
			home_page.focus_selected())
	feedback = HubUI.label(footer, "", &"GoldLabel")
	feedback.custom_minimum_size.y = 44
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_label = HubUI.label(_shell, "", &"MutedLabel")
	# Above the lobby.
	move_child(_frame, get_child_count() - 1)
	UIMotion.bind_buttons(_content)
	UIMotion.bind_buttons(_frame)
	UIMotion.bind_buttons(home_page)


# A page in the content area; one with a mood of its own (ThemeMood, in
# ui/theme/moods/<mood>.tres) wears it.
func _page(control: Control, mood: StringName) -> Control:
	var worn := ThemeMood.theme_of(mood, _content.theme)
	if worn != null:
		control.theme = worn
	_page_host.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.hide()
	return control


# The lobby spans the whole screen over the hall painting, above the scaled
# page content, so the header's echo and settings stay reachable through it.
func _build_home() -> void:
	home_page = HubLobby.new()
	home_page.theme = _content.theme
	home_page.settings = settings
	add_child(home_page)
	home_page.hide()
	home_page.selection_changed.connect(func(id: StringName): _ambience.focus(id))
	home_page.activated.connect(_enter)
	start_button = home_page.buttons[0]
	upgrade_button = home_page.buttons[1]
	decide_button = home_page.decide_button
	hero_button = home_page.hero_button
	hero_speech = home_page.hero_speech


func _enter(id: StringName) -> void:
	match id:
		&"departure":
			show_page("sortie")
		&"upgrade":
			show_page("upgrade")
		&"status":
			show_page("status")
		&"codex":
			show_page("codex")
		&"settings":
			show_page("settings")


func _resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(1.0, minf((viewport.x - 40) / CONTENT_SIZE.x, (viewport.y - 36) / CONTENT_SIZE.y))
	_content.size = CONTENT_SIZE
	_content.scale = Vector2.ONE * factor
	_content.position = (viewport - _content.size * factor) * 0.5


func refresh(meta: MetaProgress, message: String = "") -> void:
	_pick_chapter(meta)
	_meta = meta
	step = clampi(step, 0, meta.steps_open())
	echo_label.text = UIFormat.amount(meta.echo)
	home_page.refresh(meta, chapter)
	sortie_page.refresh(meta, chapter, step)
	upgrade_page.refresh(meta)
	status_page.refresh(meta)
	codex_page.refresh(meta)
	feedback.text = message
	if not home_page.visible and page == "home":
		show_page("home")


# The first progress shown opens the departure on the frontier; afterwards a
# chapter that has just opened (a first clear) is the one offered next.
func _pick_chapter(meta: MetaProgress) -> void:
	var open: Array[ChapterData] = []
	for each in Chapters.ALL:
		if meta.chapter_open(each):
			open.append(each)
	if _meta == null:
		chapter = Chapters.frontier(meta)
	else:
		for each in open:
			if not _open_chapters.has(each):
				chapter = each
	if not meta.chapter_open(chapter):
		chapter = Chapters.frontier(meta)
	_open_chapters = open


func show_page(target: String) -> void:
	page = target
	hero_speech.hide()
	if page in ["home", "sortie"]:
		status_return = ""
	for control in [home_page, sortie_page, upgrade_page, status_page, codex_page, settings_page]:
		control.hide()
	key_guide.clear_hints()
	# The lobby has nowhere to go back to; it shows how to choose and enter.
	back_button.visible = page != "home"
	lobby_guide.visible = page == "home"
	# Echo stays where the eye looks for it; it is quiet where nothing costs.
	purse.quiet = page not in ["home", "upgrade"]
	for child in _title_block.get_children():
		child.visible = page != "home"
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if page == "home" else HORIZONTAL_ALIGNMENT_LEFT
	_ambience.focus(home_page.selected_id() if page == "home" else &"")
	feedback.text = ""
	GameMusic.cue(self, &"hub")
	if page != "home":
		GameAudio.play(self, &"ui_open", -20.0)
	match page:
		"home":
			title_label.text = tr("旅支度の間")
			if _meta != null:
				home_page.refresh(_meta, chapter)
			home_page.show()
			home_page.focus_selected()
			# Said short in the lobby (its context), where the keys stand
			# inside the rail.
			key_guide.add_hint("Enter", "A", tr("決定", "lobby"))
			key_guide.add_hint("Esc", "B", tr("終了"), ask_quit)
		"sortie":
			title_label.text = tr("出撃")
			sortie_page.show()
			if _meta != null:
				sortie_page.refresh(_meta, chapter, step)
			sortie_page.focus_selected()
			key_guide.add_hint("Enter", "A", tr("出撃"), sortie_page.set_out)
			key_guide.add_hint("← / →", "◀ / ▶", tr("選ぶ"))
			if _meta != null and _meta.steps_open() > 0:
				key_guide.add_hint("Q / E", "LB / RB", tr("段階"))
			key_guide.add_hint("Tab", "View", tr("装備", "gear"), _status_from_sortie)
		"upgrade":
			title_label.text = tr("強化")
			upgrade_page.show()
			upgrade_page.focus_first()
			key_guide.add_hint("Enter", "A", tr("強化"))
			key_guide.add_hint(tr("矢印"), tr("十字"), tr("選ぶ"))
			key_guide.add_hint(tr("ドラッグ"), tr("R スティック"), tr("動かす"))
			key_guide.add_hint(tr("ホイール"), "LT / RT", tr("拡大・縮小"))
			key_guide.add_hint("C", "Y", tr("中央へ"), upgrade_page.center_view)
			key_guide.add_hint("Tab", "View", tr("ステータスへ"), func(): show_page("status"))
		"status":
			title_label.text = tr("ステータス")
			status_page.show()
			if _meta != null:
				status_page.refresh(_meta)
			status_page.focus_first()
			_status_hints()
		"codex":
			title_label.text = tr("図鑑")
			codex_page.show()
			if _meta != null:
				codex_page.refresh(_meta)
			codex_page.focus_first()
			key_guide.add_hint("↑ / ↓", "▲ / ▼", tr("選ぶ"))
			key_guide.add_hint("Q / E", "LB / RB", tr("分類"))
		"settings":
			title_label.text = tr("設定")
			settings_page.show()
			settings_page.refresh(settings)
			settings_page.focus_first()
			_settings_hints()
	# Pages are anchored in a plain host, not laid out by a Container, so the
	# whole page can slide: forward pages from the right, home from the left.
	var side := -1.0 if page == "home" else 1.0
	for control in [home_page, sortie_page, upgrade_page, status_page, codex_page, settings_page]:
		if control.visible:
			UIMotion.of(control).enter(0.0, Vector2(side * UIMotion.PAGE_DISTANCE, 0), UIMotion.WINDOW_TIME)
			# Pages built in the screen grammar bring their parts in one by one.
			if control.has_method(&"play_entrance"):
				control.play_entrance()


# Routine save notes ("保存済み" and the like) stay out of sight so the hub
# does not read like a page footer; only a status that needs attention shows.
func show_save_status(text: String, alert: bool) -> void:
	save_label.text = text
	save_label.visible = alert


# Called only after a purchase was saved; the moment never owns its timing.
func present_action(id: StringName, echo_delta: int) -> void:
	preload("res://audio/game_audio.gd").play(self, &"level_up", -22.0)
	if echo_delta != 0:
		feedback.text += tr("  (残響 %+d)") % echo_delta
		UIMotion.of(echo_label).pulse(1.08, UIMotion.GOLD_TIME)
	UIMotion.of(feedback).reveal()
	upgrade_page.present_purchase(id)


# Called only after an equip was saved.
func present_equip() -> void:
	preload("res://audio/game_audio.gd").play(self, &"confirm", -18.0)
	UIMotion.of(feedback).reveal()
	status_page.present_equip()


# Opens the settings' help at a topic, from a "?" mark anywhere in the hub;
# back returns to where the mark was.
func open_help(topic: int) -> void:
	var from := page
	show_page("settings")
	help_return = from if from != "settings" else ""
	settings_page.open_help(topic)
	_settings_hints()


# The status's keys: those of a slot's chapter, or, turned to her figures,
# the way back to it.
func _status_hints() -> void:
	key_guide.clear_hints()
	if status_page.details_open:
		key_guide.add_hint("R", "Y", tr("装備に戻る"), status_page.toggle_details)
	else:
		key_guide.add_hint("Enter", "A", tr("装備"), status_page.seal)
		key_guide.add_hint("↑ / ↓", "▲ / ▼", tr("選ぶ"))
		key_guide.add_hint("X", "X", tr("外す"), status_page.clear_slot)
		key_guide.add_hint("R", "Y", tr("能力"), status_page.toggle_details)
	key_guide.add_hint("Q / E", "LB / RB", tr("章"))
	key_guide.add_hint("Tab", "View", tr("強化へ"), func(): show_page("upgrade"))


func _settings_hints() -> void:
	title_label.text = tr("ヘルプ") if settings_page.help_shown else tr("設定")
	key_guide.clear_hints()
	key_guide.add_hint("↑ / ↓", "▲ / ▼", tr("項目"))
	if not settings_page.help_shown:
		key_guide.add_hint("← / →", "◀ / ▶", tr("変更"))
		key_guide.add_hint("Q / E", "LB / RB", tr("分類"))


# From the lobby there is nowhere back to but out of the game: the question
# the settings ask (its way back focused first, so a stray press closes
# nothing).
func ask_quit() -> void:
	if page != "home" or quit_prompt.visible:
		return
	quit_prompt.ask("", tr("ゲームを終了しますか？"), tr(HubSettings.QUIT_BODY), tr("ゲームを終了する"), tr("戻る"), true)


# Opens the settings on the language's row: where a new language's hub
# starts (Main._change_language).
func open_language() -> void:
	show_page("settings")
	settings_page.focus_language()


func go_back() -> void:
	if page == "home":
		ask_quit()
		return
	GameAudio.play(self, &"ui_back", -18.0)
	if page == "settings" and settings_page.help_shown:
		if help_return.is_empty():
			settings_page.close_help()
			_settings_hints()
		else:
			var back := help_return
			help_return = ""
			show_page(back)
		return
	if page == "status" and not status_return.is_empty():
		show_page(status_return)
		return
	show_page("home")


# Tab (View) on the departure: the status, to change what she carries; back
# from there returns to the departure.
func _status_from_sortie() -> void:
	show_page("status")
	status_return = "sortie"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


# Tab (View) between the upgrades and the status, and from the departure to
# the status, before Tab moves the focus.
func _input(event: InputEvent) -> void:
	if not visible or page not in ["upgrade", "status", "sortie"]:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK
	if key or pad:
		if page == "sortie":
			_status_from_sortie()
		else:
			show_page("status" if page == "upgrade" else "upgrade")
		get_viewport().set_input_as_handled()
