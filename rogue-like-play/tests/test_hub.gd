extends SceneTree

# The base between runs: the lobby's four entries and what each tells, the
# pages they open and the way back, buying a lasting upgrade (saved, read
# back after a restart, refused when the echo is short), the encyclopedia
# telling met foes from unmet ones, the help speaking of the real-time game,
# a save that cannot be read shown as an alert, setting out on a run, and
# the difficulty steps: offered on the departure once the ending opens them,
# carried into the run, and the next opened by a clear at the highest.

var failures := 0
var checks := 0
var folder := ""


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func make_main(echo: int, save_path: String = "") -> Node:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.saving_enabled = not save_path.is_empty()
	if not save_path.is_empty():
		main.store.path = save_path
	root.add_child(main)
	if save_path.is_empty():
		main.meta.echo = echo
		main.get_node("Hub").refresh(main.meta)
	return main


func key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func run_tests() -> void:
	folder = "res://.godot/hub-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))

	# The lobby.
	var main := make_main(100)
	await process_frame
	var hub = main.get_node("Hub")
	var lobby: HubLobby = hub.home_page
	check(lobby.buttons.size() == 5 and HubLobby.ENTRIES.map(func(entry: Array): return entry[0]) == [&"departure", &"upgrade", &"status", &"codex", &"settings"], "The lobby offers departure, upgrades, status, encyclopedia and settings")
	check(hub.page == "home" and lobby.visible and hub.echo_label.text == "100", "The base opens on the lobby with the echo held")
	var music := GameMusic.find(main)
	check(music != null and music.track == &"hub" and not music.muffled, "The base plays its own music")
	check(lobby.route_value.text == "3層とボス" and lobby.best_value.text == "なし", "The departure tells the chapter's way and the deepest reached")
	check(lobby.upgrade_ready.text == "1 件" and lobby.codex_met.text == "0 / %d" % FoeCatalog.FOES.size(), "The entries tell what can be bought and what has been met")
	lobby.select(0)
	check(lobby.title_label.text == hub.chapter.display_name and lobby.decide_button.text == "出撃先を選ぶ", "The departure names the chapter it opens on")

	# Where to set out: the chapters as doors, the chosen one told beneath them.
	lobby.activated.emit(&"departure")
	await process_frame
	var sortie: HubSortie = hub.sortie_page
	check(hub.page == "sortie" and sortie.visible and main.active_run == null, "The departure opens where to set out, without setting out")
	check(sortie.cards.size() == Chapters.ALL.size() and sortie.chosen() == Chapters.ALL[0] and sortie.cards[0].button_pressed and not sortie.cards[1].button_pressed, "It opens on the first chapter, marked chosen")
	check(sortie.cards[0].state_label.text == "未踏" and sortie.cards.slice(1).all(func(door: ChapterDoor): return door.state_label.text == "封印中" and door.sealed), "Each door tells how far its chapter has been taken")
	check(sortie.route_value.text == "3層とボス" and sortie.record_value.text == "なし" and sortie.boss_value.text == HubSortie.UNKNOWN_NAME, "The band tells the way, the record, and a boss not met yet unnamed")
	var ruin_king: FoeData = load("res://data/foes/ruin_king.tres")
	var first_foes := Chapters.foes(Chapters.ALL[0])
	check(sortie.foe_row.get_child_count() == first_foes.size() and first_foes.has(ruin_king) and not first_foes.has(load("res://data/foes/gale_wolf_king.tres")), "The foes of the chapter are shown, its own boss among them")
	check(sortie.foe_row.get_children().all(func(picture: TextureRect): return picture.tooltip_text == HubSortie.UNKNOWN_NAME), "Foes not met are not named")
	check(sortie.gear_row.get_child_count() == 2 and sortie.gear_row.get_child(0).tooltip_text == "剣", "What she carries is shown: the sword and the first skill")
	check(not sortie.action_button.disabled and sortie.action_button.text == "第1章へ出撃する", "An open chapter can be set out for")
	# The button's crest kindles while the focus is on it, and settles again
	# once the focus goes back up to the doors; neither sets out.
	var crest := sortie.action_button as CrestButton
	check(crest != null and is_zero_approx(crest.stand), "The set-out button is a crest, resting while the doors hold the focus")
	root.push_input(key(KEY_DOWN))
	await process_frame
	await create_timer(UIMotion.DETAIL_SLIDE_TIME + 0.1).timeout
	check(crest.has_focus() and is_equal_approx(crest.stand, 1.0) and main.active_run == null, "Down moves to the button and its crest kindles")
	root.push_input(key(KEY_UP))
	await process_frame
	await create_timer(UIMotion.DETAIL_SLIDE_TIME + 0.1).timeout
	check(sortie.cards[0].has_focus() and is_zero_approx(crest.stand), "Up goes back to the chosen door and the crest settles")
	# The sealed chapter: chosen to read what opens it, not set out for.
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(sortie.chosen().id == &"gale_woods" and sortie.cards[1].sealed and sortie.cards[1].button_pressed and sortie.cards[1].has_focus(), "Right chooses the sealed chapter, shown sealed")
	check(sortie.action_button.disabled and sortie.action_button.text == "第2章は封印中" and sortie.description_label.text.contains("第1章を踏破") and sortie.action_button.tooltip_text.contains("第1章を踏破"), "A sealed chapter says how it opens and cannot be set out for")
	check(hub.chapter.id == &"ash_corridor", "Choosing a sealed chapter leaves the next departure where it was")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.active_run == null, "Enter on a sealed chapter does not set out")
	# Its first clear opens the next chapter, which is then the one offered.
	main.meta.chapter_clears[&"ash_corridor"] = 1
	main.meta.chapter_best[&"ash_corridor"] = 4
	main.meta.met[ruin_king.id] = true
	hub.refresh(main.meta)
	check(hub.chapter.id == &"gale_woods" and sortie.chosen().id == &"gale_woods" and not sortie.cards[1].sealed, "A chapter that has just opened is the one offered next")
	check(not sortie.action_button.disabled and sortie.action_button.text == "第2章へ出撃する" and sortie.cards[0].state_label.text == "踏破 1回", "Once the first chapter is cleared, the second opens")
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(hub.chapter.id == &"ash_corridor" and sortie.boss_value.text == ruin_king.display_name, "Choosing an open chapter makes it the next departure, and a boss met is named")
	# Tab (View) to change what she carries, and back again.
	root.push_input(key(KEY_TAB))
	await process_frame
	check(hub.page == "status", "Tab goes from the departure to the status")
	hub.go_back()
	check(hub.page == "sortie", "Back from there returns to the departure")
	hub.go_back()
	check(hub.page == "home" and lobby.title_label.text == Chapters.ALL[0].display_name, "Back from the departure returns to the lobby, which shows the chapter chosen")
	main.meta.chapter_clears.clear()
	main.meta.chapter_best.clear()
	main.meta.met.clear()
	hub.refresh(main.meta)
	check(lobby.best_value.text == "なし", "The lobby tells the chapter's record")
	var deep := MetaProgress.new()
	deep.chapter_best[&"ash_corridor"] = 2
	check(Chapters.record(deep, Chapters.ALL[0]) == "第2層まで", "A record names the deepest layer")
	deep.chapter_best[&"ash_corridor"] = Chapters.ALL[0].layers + 1
	check(Chapters.record(deep, Chapters.ALL[0]) == "ボスまで", "Past the last layer, the record is the boss")

	# The difficulty steps on the departure: no row until the ending opens them.
	var final: ChapterData = Chapters.ALL.back()
	hub.show_page("sortie")
	await process_frame
	check(not sortie.step_row.visible and not sortie.action_button.text.contains("段階"), "Before the ending the departure offers no step")
	main.meta.chapter_clears[final.id] = 1
	hub.refresh(main.meta)
	check(sortie.step_row.visible and sortie.step_value.text == "0" and sortie.step_note.text == "制約なし" and sortie.step_down.disabled and not sortie.step_up.disabled, "The ending opens the step row, at the game as it is")
	root.push_input(key(KEY_E))
	await process_frame
	check(hub.step == 1 and sortie.step == 1 and sortie.step_note.text.begins_with(DifficultySteps.ALL[0].summary) and sortie.step_note.text.ends_with("残響 +10%"), "E raises the step and tells what it adds and brings back")
	check(sortie.action_button.text.ends_with("（段階1）") and sortie.step_note.tooltip_text.contains(DifficultySteps.ALL[0].summary), "The button names the step, and pointing at the line lists what is in play")
	root.push_input(key(KEY_E))
	await process_frame
	check(hub.step == 1 and sortie.step_up.disabled and sortie.step_up.tooltip_text.contains("段階1で%sを踏破" % Chapters.short_name(final)), "No step past the highest open; its arrow says how the next opens")
	root.push_input(key(KEY_Q))
	await process_frame
	check(hub.step == 0 and sortie.step_note.text == "制約なし", "Q lowers it")
	main.meta.chapter_clears.clear()
	hub.refresh(main.meta)
	check(not sortie.step_row.visible and hub.step == 0, "Without the ending the row is gone again")
	hub.show_page("home")
	for pair: Array in [[&"upgrade", "upgrade"], [&"status", "status"], [&"codex", "codex"], [&"settings", "settings"]]:
		lobby.activated.emit(pair[0])
		check(hub.page == pair[1], "%s opens its page" % pair[0])
		hub.go_back()
		check(hub.page == "home", "Back returns to the lobby")

	# The encyclopedia: met foes named, unmet ones dark.
	main.meta.met[&"dashing_rat"] = true
	hub.refresh(main.meta)
	hub.show_page("codex")
	var codex: HubCodex = hub.codex_page
	check(codex.cards.size() == FoeCatalog.FOES.size() and codex.count_label.text.contains("1 / %d" % FoeCatalog.FOES.size()), "Every foe has a card, and the count is of those met")
	var rat_index := FoeCatalog.FOES.find(load("res://data/foes/dashing_rat.tres"))
	check(codex.cards[rat_index].text == "疾走ネズミ" and codex.cards[0].text == HubCodex.UNKNOWN_NAME, "A met foe is named in the list, an unmet one is not")
	check(codex.cards[rat_index].icon_texture != null and not codex.cards[rat_index].unknown and codex.cards[0].icon_texture != null and codex.cards[0].unknown, "Each row shows its foe's icon: its face when met, a shade when not")
	var shadow := FoeIcon.of(FoeCatalog.FOES[0].visual_id, false).get_image()
	var dark := true
	for y in range(0, shadow.get_height(), 8):
		for x in range(0, shadow.get_width(), 8):
			var pixel := shadow.get_pixel(x, y)
			if pixel.a > 0.1 and pixel.v > 0.05:
				dark = false
	check(dark, "A foe not met is a dark silhouette in its icon")
	check(codex.cards.all(func(card: FoeRow): return card.icon_texture.get_width() == FoeIcon.SIZE and card.icon_texture.get_height() == FoeIcon.SIZE), "Every icon is the same round size")
	check(FoeIcon.of(FoeCatalog.FOES[0].visual_id, true) == FoeIcon.of(FoeCatalog.FOES[0].visual_id, true), "An icon is made once and kept")
	codex._select(rat_index, false)
	check(codex.name_label.text == "疾走ネズミ" and codex.description_label.text.contains("飛びかかる") and codex.stats.get_child_count() == 3, "A met foe's account is told, its figures a row each")
	check(codex.stats.get_children().all(func(row: Node): return (row.get_node_or_null(^"Icon") as TextureRect) != null and row.get_node(^"Icon").texture != null), "Every figure has its icon")
	await create_timer(UIMotion.DETAIL_SLIDE_TIME + 0.1).timeout
	var stats_at := codex.stats.get_global_rect()
	var rat_account := codex.description_label.text.length()
	var king_met := codex.meta.met.has(ruin_king.id)
	codex.meta.met[ruin_king.id] = true
	codex._select(FoeCatalog.FOES.find(ruin_king), false)
	await create_timer(UIMotion.DETAIL_SLIDE_TIME + 0.1).timeout
	if not king_met:
		codex.meta.met.erase(ruin_king.id)
	check(codex.description_label.text.length() > rat_account and codex.stats.get_global_rect().is_equal_approx(stats_at), "The figures keep their place from foe to foe, however long the account")
	codex._select(rat_index, false)
	check(codex.cards[rat_index].chosen and codex.cards.filter(func(card: FoeRow): return card.chosen).size() == 1, "Only the row shown is lit")
	check(codex.stage.get_node_or_null(^"Figure") != null and codex.stage.get_node(^"Figure").modulate == Color.WHITE, "The foe chosen stands on the stage")
	var portrait := codex.stage.get_node_or_null(^"Figure/Portrait") as Sprite2D
	check(portrait != null and portrait.texture == EnemySprites.codex_portrait(codex.rows[rat_index].visual_id), "The foe chosen stands as its painted portrait")
	codex._select(0, false)
	check(codex.name_label.text == HubCodex.UNKNOWN_NAME and codex.stats.get_child_count() == 0 and codex.description_label.text == HubCodex.UNKNOWN_NOTE, "An unmet foe's figures and account stay hidden")
	check(codex.stage.get_node(^"Figure").modulate == HubCodex.SHADOW, "An unmet foe stands on the stage as a shade")
	codex.kind_tabs.step(1)
	check(codex.rows.all(func(foe: FoeData): return FoeCatalog.kind_of(foe) == 1), "The kind tabs filter the list")
	hub.show_page("home")

	# The settings: three tabs, one group of rows at a time, the focused one
	# told in the column beside.
	hub.show_page("settings")
	var settings_page: HubSettings = hub.settings_page
	var shown_rows := func() -> Array: return range(settings_page._rows.size()).filter(func(row: int): return settings_page._rows[row].visible)
	check(settings_page.tabs.tabs.map(func(tab: Button): return tab.text) == ["サウンド", "グラフィック", "その他"] and settings_page.tabs.selected == 0 and shown_rows.call() == [0, 1, 2, 3], "The settings open on the sound tab, its four volumes alone")
	settings_page.effects_slider.grab_focus()
	await process_frame
	check(settings_page.note.text == HubSettings.NOTES[2], "The focused setting is told under the rows")
	settings_page.tabs.step(1)
	await process_frame
	check(shown_rows.call() == [4, 5] and settings_page.shake_cycler.has_focus() and settings_page.note.text == HubSettings.NOTES[4], "The next tab shows the graphics rows and focuses the first")
	check(settings_page.display_cycler.get_node(settings_page.display_cycler.focus_neighbor_bottom) == settings_page.display_cycler, "The focus stays within the tab")
	settings_page.tabs.step(1)
	await process_frame
	check(shown_rows.call() == [6, 7, 8, 9] and settings_page.language_cycler.has_focus() and settings_page.note.text == HubSettings.NOTES[9], "The last tab holds the language (first), the controls guide, the help and quitting")
	# As in the lobby, the pointer resting on a row (its caption or its
	# control) chooses it; a chosen row draws no band or frame.
	settings_page._rows[8].gui_input.emit(InputEventMouseMotion.new())
	await create_timer(HubLobby.HOVER_INTENT + 0.05).timeout
	check(settings_page.quit_button.has_focus() and settings_page.focused_row == 8, "Pointing at a settings row chooses it")
	settings_page.help_button.mouse_entered.emit()
	await create_timer(HubLobby.HOVER_INTENT + 0.05).timeout
	check(settings_page.help_button.has_focus() and settings_page.note.text == HubSettings.NOTES[7], "Pointing at a row's control chooses it too")
	check(settings_page.help_button.get_theme_stylebox(&"focus") is StyleBoxEmpty and settings_page.topic_buttons[0].get_theme_stylebox(&"focus") is StyleBoxEmpty, "Chosen settings and help rows draw no frame")
	# From the lobby, Esc asks whether to leave the game; on a page it only goes back.
	var left := [0]
	var quit_before: Callable = settings_page.quit_action
	settings_page.quit_action = func(): left[0] += 1
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	hub._unhandled_input(cancel)
	await process_frame
	check(hub.page == "home" and not hub.quit_prompt.visible, "Esc on a page goes back to the lobby and asks nothing")
	var lobby_hints: Array = hub.key_guide.get_children().filter(func(hint: Node) -> bool: return hint is Button and (hint as Button).visible).map(func(hint: Button) -> String: return hint.text)
	var upper_hints: Array = hub.lobby_guide.get_children().filter(func(hint: Node) -> bool: return hint is Button).map(func(hint: Button) -> String: return hint.text)
	check(lobby_hints == ["決定", "終了"] and hub.lobby_guide.visible and upper_hints == ["選ぶ"], "The lobby's keys name the way out of the game, in two rows")
	var upper_row: Rect2 = hub.lobby_guide.get_global_rect()
	var lower_row: Rect2 = hub.key_guide.get_global_rect()
	var rail := HubLobby.MENU_WIDTH - 20.0
	check(upper_row.end.x < rail and lower_row.end.x < rail and upper_row.position.x >= hub.EDGE_X - 1.0 and is_equal_approx(upper_row.position.x, lower_row.position.x) and upper_row.get_center().y < lower_row.position.y + 8.0, "Both rows end inside the lobby's rail, one over the other")
	hub._unhandled_input(cancel)
	await process_frame
	check(hub.quit_prompt.visible and hub.quit_prompt.cancel_button.has_focus() and hub.quit_prompt.cancel_button.text == "戻る" and left[0] == 0, "Esc on the lobby asks before leaving, its way back focused")
	check(hub.quit_prompt.cancel_button.stand == 1.0 and hub.quit_prompt.accept_button.stand == 0.0 and hub.quit_prompt.accept_button.theme_type_variation == &"BandDangerButton", "Only the waiting answer is lit, and the way out is red")
	# The pointer moving over the way out chooses it, so only one answer is lit.
	var resting := InputEventMouseMotion.new()
	resting.relative = Vector2.ZERO
	hub.quit_prompt.accept_button.gui_input.emit(resting)
	check(hub.quit_prompt.cancel_button.has_focus(), "A pointer only resting on an answer chooses nothing")
	var onto_answer := InputEventMouseMotion.new()
	onto_answer.relative = Vector2(3, 0)
	hub.quit_prompt.accept_button.gui_input.emit(onto_answer)
	check(hub.quit_prompt.accept_button.has_focus() and left[0] == 0, "Moving the pointer onto an answer chooses it without answering")
	hub.quit_prompt.canceled.emit()
	check(not hub.quit_prompt.visible and hub.home_page.buttons[hub.home_page.selected].has_focus() and left[0] == 0, "The way back returns to the lobby's menu, and nothing is left")
	# Answered, the band fades out a moment longer, taking no input meanwhile.
	check(hub.quit_prompt._view.visible and hub.quit_prompt.accept_button.focus_mode == Control.FOCUS_NONE and hub.quit_prompt.shade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The answered question fades out without taking focus or clicks")
	await create_timer(ChoicePrompt.CLOSE_TIME + 0.1).timeout
	check(not hub.quit_prompt._view.visible, "Then it is gone")
	hub.ask_quit()
	hub.quit_prompt.confirmed.emit()
	check(left[0] == 1 and not hub.quit_prompt.visible, "The way out leaves the game")
	settings_page.quit_action = quit_before
	hub.show_page("settings")
	await process_frame
	hub.ask_quit()
	check(not hub.quit_prompt.visible and not hub.lobby_guide.visible, "It is the lobby's question only, and the lobby's upper row of keys shows there alone")
	settings_page.show_tab(2)
	# Quitting's way back says so, beside the way out.
	settings_page.ask_quit()
	check(settings_page.quit_prompt.visible and settings_page.quit_prompt.cancel_button.text == "戻る" and settings_page.quit_prompt.cancel_button.has_focus(), "Quitting asks first, its way back named and waiting")
	settings_page.quit_prompt.canceled.emit()
	settings_page.show_tab(0)
	# The help opens as a window over the dimmed page and closes back to it.
	settings_page.open_help(HubSettings.TOPIC_GROWTH)
	await process_frame
	check(settings_page.help_layer.visible and settings_page.is_visible_in_tree() and settings_page.help_title.text == HubSettings.HELP[HubSettings.TOPIC_GROWTH][0], "The help opens as a window over the page, at its topic")
	# As in the lobby, resting the pointer on a topic chooses it.
	settings_page.topic_buttons[HubSettings.TOPIC_CODEX].mouse_entered.emit()
	await create_timer(HubLobby.HOVER_INTENT + 0.05).timeout
	check(settings_page.selected_topic == HubSettings.TOPIC_CODEX and settings_page.topic_buttons[HubSettings.TOPIC_CODEX].has_focus() and settings_page.help_title.text == HubSettings.HELP[HubSettings.TOPIC_CODEX][0], "Pointing at a help topic moves the choice there")
	# The pointer moving over a row counts too, with no entry reported.
	var moved := InputEventMouseMotion.new()
	settings_page.topic_buttons[HubSettings.TOPIC_CONTROLS].gui_input.emit(moved)
	await create_timer(HubLobby.HOVER_INTENT + 0.05).timeout
	check(settings_page.selected_topic == HubSettings.TOPIC_CONTROLS and settings_page.help_title.text == HubSettings.HELP[HubSettings.TOPIC_CONTROLS][0], "Moving the pointer over a topic chooses it even when its entry went unreported")
	# The controls show their keys as a table over the points; a topic is told
	# a point a line.
	check(settings_page.help_keys.visible and settings_page.help_keys.get_child_count() == 3 * (HubSettings.HELP_KEYS.size() + 1) and settings_page.help_points.get_child_count() == HubSettings.HELP[HubSettings.TOPIC_CONTROLS][1].size(), "The controls are a table of keys over their points")
	settings_page.select_topic(HubSettings.TOPIC_RUN)
	check(not settings_page.help_keys.visible and settings_page.help_points.get_child_count() == HubSettings.HELP[HubSettings.TOPIC_RUN][1].size(), "Another topic is its points alone")
	# Its close can be clicked: the key hint, or the dimmed backdrop round it.
	check(settings_page.help_close_hint.mouse_filter != Control.MOUSE_FILTER_IGNORE, "The help's close hint takes a click")
	settings_page.help_close_hint.pressed.emit()
	await process_frame
	check(not settings_page.help_layer.visible and settings_page.help_button.has_focus() and hub.title_label.text == "設定", "Clicking the close returns to the settings")
	settings_page.open_help(HubSettings.TOPIC_RUN)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(settings_page.help_view.get_child(0) as Control).gui_input.emit(click)
	await process_frame
	check(not settings_page.help_shown, "A click outside the window closes the help too")
	hub.show_page("home")

	# The help speaks of the real-time game.
	var help_text := ""
	for topic: Array in HubSettings.HELP:
		help_text += topic[0] + "".join(topic[1])
	check(HubSettings.HELP.size() == 6 and help_text.contains("残響") and help_text.contains("ダッシュ"), "The help tells the run, the echo and the controls")
	# And of the rules as they are: every branch of the tree, what the
	# statuses do, and each curse by the name the run gives it.
	check(help_text.contains("必殺技の枝") and help_text.contains("武器") and not help_text.contains("まだ開いていません"), "The help names every branch of the upgrade tree")
	check(help_text.contains(Status.NAMES[Status.SHOCK]) and help_text.contains(Status.NAMES[Status.BURN].left(1)) and RunState.CURSES.values().all(func(curse: Array) -> bool: return help_text.contains(curse[0])), "The help tells the statuses and the curses")
	check(not help_text.contains("ターン") and not help_text.contains("倉庫") and not help_text.contains("Gold"), "The help no longer speaks of the turn-based game")
	main.free()
	await process_frame

	# Buying an upgrade is saved and read back after a restart.
	var path := folder + "/progress.json"
	var seed := MetaProgress.new()
	seed.echo = 200
	var writer := MetaStore.new()
	writer.path = path
	writer.save_progress(seed)
	main = make_main(0, path)
	await process_frame
	hub = main.get_node("Hub")
	check(main.meta.echo == 200 and hub.echo_label.text == "200", "The saved echo is read at the start")
	hub.show_page("upgrade")
	var page: MetaUpgradePage = hub.upgrade_page
	check(hub.title_label.text == "強化", "The page is titled as the lobby's menu names it")
	check(page.selected == MetaProgress.ROOT and (page.nodes[MetaProgress.ROOT] as Button).has_focus(), "The tree opens on its root")
	check(page.nodes.size() == MetaProgress.UPGRADES.size() + MetaUpgradePage.SEALS.size(), "Every upgrade and every sealed branch has its node")
	page.buy_button.pressed.emit()
	check(main.meta.rank(MetaProgress.ROOT) == 1 and main.meta.echo == 150 and hub.echo_label.text == "150", "Pressing the column's button buys the chosen node")
	check(page.buy_button.text == "習得済み" and page.buy_button.disabled and hub.feedback.text.contains("残響の灯"), "The column and the note show the purchase")
	# Moving the focus: left from the root to the body's branch.
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(page.selected == &"sturdy_body" and page.name_label.text == "鍛えた体" and not page.rank_label.visible, "Left goes to the body's branch and the column tells it, its ranks by sockets alone")
	check(page.buy_button is CrestButton and page.price_value.text == "80" and page.held_value.text == "150" and not page.short_label.visible, "The column sets the price beside the echo held, on a crest button")
	check(page.figure_label.text == "習得すると　最大HP 115（+15）" and not page.description_label.visible, "The column tells what the first rank gives in one line, without the description saying it again")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.rank(&"sturdy_body") == 1 and main.meta.echo == 70 and page.figure_label.text == "最大HP 115 → 130（+15）", "Enter on a node buys it, and the figure tells the next rank")
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(page.selected == &"double_dash" and page.buy_button.disabled and page.buy_button.tooltip_text.contains("足りない"), "Down goes along the branch to one the echo cannot pay for")
	check(page.short_label.visible and page.short_label.text.begins_with("残響があと") and page.held_value.text == "70", "The column says how much echo is missing")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.rank(&"double_dash") == 0 and main.meta.echo == 70, "One the echo cannot pay for is refused")
	(page.nodes[&"learn_echo_burst"] as Button).grab_focus()
	check(page.buy_button.visible and page.name_label.text == "残響解放の習得", "The special branch is open, its first node a special move to learn")
	root.push_input(key(KEY_C))
	await process_frame
	check(page.selected == MetaProgress.ROOT, "C brings the root back")
	# The pointer: resting on a node chooses it; a press that moves drags the board.
	var motion := InputEventMouseMotion.new()
	motion.position = page.canvas.position + page._centers[&"parting_blessing"]
	page.board.gui_input.emit(motion)
	await create_timer(HubLobby.HOVER_INTENT + 0.05).timeout
	check(page.selected == &"parting_blessing", "Resting the pointer on a node chooses it")
	var before: Vector2 = page.canvas.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = page.canvas.position + page._centers[MetaProgress.ROOT]
	page.board.gui_input.emit(press)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = press.position + Vector2(40, 0)
	drag.relative = Vector2(40, 0)
	page.board.gui_input.emit(drag)
	var release := press.duplicate()
	release.pressed = false
	release.position = drag.position
	page.board.gui_input.emit(release)
	check(page.canvas.position.x > before.x and page.selected == &"parting_blessing", "A drag moves the board and chooses nothing")
	# The wheel zooms around the pointer, within its bounds; C brings the first size back.
	var anchor: Vector2 = page.canvas.position + page._centers[&"sturdy_body"] * page.zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = anchor
	page.board.gui_input.emit(wheel)
	check(is_equal_approx(page.zoom, MetaUpgradePage.ZOOM_STEP) and page.canvas.scale.is_equal_approx(Vector2.ONE * page.zoom), "The wheel zooms the board in")
	check((page.canvas.position + page._centers[&"sturdy_body"] * page.zoom).distance_to(anchor) < 1.0, "The node under the pointer stays under it")
	press.position = anchor
	page.board.gui_input.emit(press)
	release.position = anchor
	page.board.gui_input.emit(release)
	check(page.selected == &"sturdy_body", "A click still finds the node at the zoomed size")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for notch in 12:
		page.board.gui_input.emit(wheel)
	check(is_equal_approx(page.zoom, MetaUpgradePage.ZOOM_MIN), "Zooming out stops at its bound")
	root.push_input(key(KEY_C))
	await process_frame
	check(page.zoom == 1.0 and page.selected == MetaProgress.ROOT, "C brings the root back at the first size")
	# The status page: Tab from the upgrades, her slots and the chosen one's
	# list, a skill moved to the other slot (saved), back from the list, her
	# figures in full.
	root.push_input(key(KEY_TAB))
	await process_frame
	var status: HubStatus = hub.status_page
	check(hub.page == "status" and status.slot_buttons[1].has_focus() and status.name_label.text == "叩きつけ", "Tab goes to the status page, on the first skill slot")
	check(status.slot_buttons.size() == 4 and status.slot_buttons[0].tooltip_text.contains("剣") and status.slot_buttons[2].tooltip_text.contains("空き") and status.slot_buttons[3].tooltip_text.contains("封印"), "The slots tell the sword, the empty slot and the sealed special")
	check(status.slot_buttons[0].emblem != null and status.slot_buttons[2].empty and status.slot_buttons[3].sealed, "The slots show the sword's emblem, a dashed ring for the empty slot and the dimmed seal")
	check(status.slot_buttons.map(func(row: LoadoutSlot): return row.key) == ["左クリック", "Q", "E", "R"] and status.slot_buttons[1].chosen and not status.slot_buttons[2].chosen, "Each slot carries its key as the fight's HUD does, the chosen one marked")
	check(status.slot_buttons[1].title == "スキル1" and status.slot_buttons[1].content == "叩きつけ" and status.slot_buttons[1].note == "再使用 6秒" and status.slot_buttons[2].content == "空き", "Each slot's row names the slot, what it holds and its short figure")
	check(status.shown_figures.size() == 3 and status.shown_figures[0] == ["再使用", "6秒"] and status.shown_figures[1][0] == "威力", "The stage tells the skill's figures a row each")
	check(not status.action_button.visible and status.outcome_label.text.is_empty(), "On a slot the stage only tells: the action waits for a choice")
	var hp_row: Array = status.stat_rows()[0]
	check(hp_row[1] == "115" and hp_row[2] == "(+15)" and hp_row[3].contains("鍛えた体 +15"), "Her health shows what the upgrades add, and its breakdown")
	var always := status.shown_rows
	check(always == 5 and status.strip.is_visible_in_tree(), "The strip shows her five main figures")
	var strip_words := status.strip.find_children("*", "Label", true, false).map(func(label: Label): return label.text)
	check(strip_words.has("115") and strip_words.has("(+15)"), "The strip tells what the upgrades add beside the value")
	root.push_input(key(KEY_R))
	await process_frame
	check(status.details_open and status.shown_rows == status.stat_rows().size() and status.shown_rows > always and not status.slot_buttons[1].is_visible_in_tree(), "R turns the page to all her figures")
	root.push_input(key(KEY_ESCAPE))
	await process_frame
	check(hub.page == "status" and not status.details_open and status.slot_buttons[1].has_focus() and status.shown_rows == always, "Back from her figures returns to the build")
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(status.slot == 2 and status.choice_ids == [HubStatus.CLEAR_ID, &"slam", &"thunder_flash", &"swallow_cut", &"blaze_ring", &"wisp_shot", &"thunder_circle"] and status.choices[2].state == LoadoutChoice.State.UNKNOWN and status.choices[2].tooltip_text == HubStatus.UNKNOWN_NOTE, "Choosing the second slot lists what it can hold, one not learned as its shadow")
	check(status.choices[0].clears and status.choices[0].idle and status.choices[1].state == LoadoutChoice.State.ELSEWHERE and status.choices[1].key == "Q" and status.choices[1].tag == HubStatus.HELD, "A choice tells the slot its skill is set in by that slot's key; clearing an empty slot is idle")
	check(status.choices[1].title == "叩きつけ" and status.choices[1].note == "再使用 6秒" and status.choices[2].title == HubStatus.UNKNOWN_NAME and status.choices[2].tag == HubStatus.UNOWNED, "Each choice is named with its short figure, one not learned as unknown and unowned")
	check(status.count_label.text == "習得  1 / 6", "The list counts the skills learned")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(status.choices[0].has_focus(), "Enter on a slot goes into its list")
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(status.action_button.visible and status.action_button.text == "入れ替える" and not status.action_button.disabled and status.outcome_label.text == "Q から移す", "A skill set in the other slot offers to change places, and says what that does")
	check(status.slot_buttons[2].preview == "叩きつけ" and status.slot_buttons[1].preview == "空き", "Both slots tell what they would hold afterwards")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.loadout == [&"", &"slam"] and status.slot_buttons[2].has_focus() and hub.feedback.text.contains("スキル2"), "Enter on a choice sets it, and the focus returns to the slot")
	check(status.choices[1].state == LoadoutChoice.State.HELD and status.choices[1].key.is_empty() and status.slot_buttons[1].empty and status.slot_buttons[2].preview.is_empty() and status.slot_buttons[2].content == "叩きつけ", "What the slot now holds is marked as held, and the slot it left is empty")
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(status.choices[1].has_focus() and status.action_button.disabled and status.action_button.text == HubStatus.HELD, "Right from a slot goes into its list too, on what the slot holds")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.loadout == [&"", &"slam"] and status.choices[1].has_focus(), "Enter on what the slot already holds changes nothing")
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(status.slot_buttons[2].has_focus(), "Left from the list returns to its slot")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	root.push_input(key(KEY_ESCAPE))
	await process_frame
	check(hub.page == "status" and status.slot_buttons[2].has_focus(), "Back from the list returns to its slot")
	# The attack slot: the sword held, the others unknown until learned;
	# learned, one is taken up there.
	root.push_input(key(KEY_UP))
	root.push_input(key(KEY_UP))
	await process_frame
	check(status.slot == 0 and status.choice_ids == [&"sword", &"spear", &"hammer"] and status.choices[1].state == LoadoutChoice.State.UNKNOWN and status.choices[0].state == LoadoutChoice.State.HELD and status.slot_buttons[0].tooltip_text.contains("剣"), "The attack slot lists the sword, the other weapons unknown")
	main.meta.ranks["learn_spear"] = 1
	hub.refresh(main.meta, "")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(status.name_label.text == "槍" and status.action_button.text == "持ち替える" and status.shown_figures[0] == ["連撃", "3段"] and status.outcome_label.text == "「剣」と替える", "The stage tells the spear and offers to take it up in the sword's place")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.weapon == &"spear" and status.slot_buttons[0].has_focus() and status.slot_buttons[0].tooltip_text.contains("槍") and hub.feedback.text.contains("持ち替え"), "Enter on it takes the spear up")
	root.push_input(key(KEY_DOWN))
	root.push_input(key(KEY_DOWN))
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(status.slot == 3 and status.choice_ids == [&"echo_burst", &"sky_rend", &"crimson_lotus"] and status.choices.all(func(row: LoadoutChoice): return row.state == LoadoutChoice.State.UNKNOWN) and status.name_label.text == "必殺技", "The sealed special slot lists its moves as shadows")
	# The special slot opens once a special move is learned.
	main.meta.ranks["learn_echo_burst"] = 1
	hub.refresh(main.meta, "")
	check(status.slot == 3 and status.choice_ids == [HubStatus.CLEAR_ID, &"echo_burst", &"sky_rend", &"crimson_lotus"] and status.choices[2].state == LoadoutChoice.State.UNKNOWN and status.slot_buttons[3].empty and status.slot_buttons[3].tooltip_text.contains("空き"), "Once a special move is learned, its slot opens with its choices")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(status.name_label.text == "残響解放" and status.action_button.text == "装備する" and status.outcome_label.text == "R に付ける", "The stage tells the special move and offers to set it")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.special == &"echo_burst" and status.slot_buttons[3].tooltip_text.contains("残響解放") and hub.feedback.text.contains("必殺技"), "Enter on it sets the special move")
	root.push_input(key(KEY_TAB))
	await process_frame
	check(hub.page == "upgrade", "Tab goes back to the upgrades")
	main.free()
	await process_frame
	var reader := MetaStore.new()
	reader.path = path
	var read_back := reader.load_progress()
	check(read_back.rank(&"sturdy_body") == 1 and read_back.rank(MetaProgress.ROOT) == 1 and read_back.echo == 70, "The purchases are still there after a restart")
	check(read_back.loadout == [&"", &"slam"] and read_back.special == &"echo_burst" and read_back.weapon == &"spear", "So are the skill, special and attack slots")

	# An unreadable save: an alert, and saving stopped.
	var broken := folder + "/broken.json"
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	main = make_main(0, broken)
	await process_frame
	hub = main.get_node("Hub")
	check(hub.save_label.visible and hub.save_label.text.contains("保存を停止"), "A save that cannot be read is told on the base")
	main.free()
	await process_frame

	# Setting out.
	main = make_main(50)
	main.run_seed = 4
	await process_frame
	hub = main.get_node("Hub")
	hub.home_page.activated.emit(&"departure")
	await process_frame
	var held := key(KEY_ENTER)
	held.echo = true
	root.push_input(held)
	await process_frame
	check(hub.page == "sortie" and main.active_run == null, "A held Enter's repeats do not set out from the page it opened")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	var run: RunDirector = main.active_run
	check(run != null and not hub.visible and run.returns_to_base and run.meta == main.meta and run.chapter == Chapters.ALL[0], "Enter on a chapter starts a run there, shaped by the progress")
	check(run.map_view.visible, "The run opens on its route")
	hub.sortie_page.set_out()
	check(main.active_run == run, "A second departure is ignored while a run lasts")
	main.free()
	await process_frame

	# The ending: the last chapter's first clear opens the steps, told on the
	# result; a clear of it at the highest step open opens the next.
	main = make_main(0)
	main.run_seed = 4
	await process_frame
	hub = main.get_node("Hub")
	for earlier: ChapterData in Chapters.ALL.slice(0, Chapters.ALL.size() - 1):
		main.meta.chapter_clears[earlier.id] = 1
	hub.refresh(main.meta)
	hub.home_page.activated.emit(&"departure")
	hub.sortie_page.set_out()
	await process_frame
	run = main.active_run
	check(run.chapter == Chapters.ALL.back() and run.step == 0, "The chapter just opened is set out for at the game as it is")
	run.finish(true)
	check(main.meta.ending_seen() and main.meta.steps_open() == 1 and run.end_view.record_label.text.contains("難易度の段階が開いた"), "Its first clear is the ending, which opens the steps, told on the result")
	run.end_view._button.pressed.emit()
	await process_frame
	# The ending it owes is played on the way home (tried below); skipped here.
	main.ending_view.finish()
	await process_frame
	hub.home_page.activated.emit(&"departure")
	hub.sortie_page.choose_step(1)
	hub.sortie_page.set_out()
	await process_frame
	run = main.active_run
	check(run.step == 1 and run.run.step == 1, "The step chosen on the departure is the run's")
	run.finish(true)
	check(main.meta.steps_open() == 2 and run.end_view.record_label.text.contains("段階2が開いた"), "Clearing the last chapter at the highest step opens the next, told on the result")
	main.free()
	await process_frame

	# The ending: owed by the last chapter's first clear, played on the way
	# home (the stills one by one, then the roll), skipped by holding Esc
	# (B); home after it, she speaks as one who has seen it.
	main = make_main(0)
	main.run_seed = 4
	await process_frame
	hub = main.get_node("Hub")
	check(HubLobby.lines_for(main.meta) == HubLobby.SPEECHES[0], "Before any clear she speaks of the first chapter")
	for earlier: ChapterData in Chapters.ALL.slice(0, Chapters.ALL.size() - 1):
		main.meta.chapter_clears[earlier.id] = 1
	check(HubLobby.lines_for(main.meta) == HubLobby.SPEECHES[Chapters.ALL.size() - 1], "Her lines follow the chapters cleared")
	hub.refresh(main.meta)
	hub.home_page.activated.emit(&"departure")
	hub.sortie_page.set_out()
	await process_frame
	run = main.active_run
	run.finish(true)
	check(main.ending_due, "The last chapter's first clear owes the ending")
	run.end_view._button.pressed.emit()
	await process_frame
	var ending: EndingView = main.ending_view
	check(ending != null and ending.visible and ending.scene == 0 and not hub.visible and not main.ending_due, "The way home plays the ending first, from its first still")
	ending.advance()
	check(ending.scene == 0, "A press before the still is up does nothing")
	for still in EndingView.SCENES.size() - 1:
		await create_timer(EndingView.LINE_DELAY + EndingView.STILL_TIME).timeout
		ending.advance()
	check(ending.scene == EndingView.SCENES.size() - 1 and not ending.rolling, "Enter moves on through the stills")
	await create_timer(EndingView.LINE_DELAY + EndingView.STILL_TIME).timeout
	ending.advance()
	check(ending.rolling and ending.roll.visible and not ending.art.visible, "After the last still, the staff roll")
	Input.action_press(&"ui_cancel")
	await create_timer(EndingView.HOLD_TIME * 0.5).timeout
	check(ending.visible and not ending.done, "Half a hold of Esc does not skip")
	await create_timer(EndingView.HOLD_TIME * 0.6 + 0.1).timeout
	Input.action_release(&"ui_cancel")
	await process_frame
	check(ending.done and not ending.visible and hub.visible and hub.page == "home", "Holding Esc to the full ring skips to home")
	check(hub.home_page._lines == HubLobby.SPEECHES.back(), "Home after the ending, she speaks as one who has seen it")
	main.free()
	await process_frame

	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + name)
	DirAccess.remove_absolute(folder)
	print("Hub tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
