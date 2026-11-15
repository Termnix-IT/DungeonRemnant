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

	# Where to set out: the chosen chapter's painting over the screen, told at its foot.
	lobby.activated.emit(&"departure")
	await process_frame
	var sortie: HubSortie = hub.sortie_page
	check(hub.page == "sortie" and sortie.visible and main.active_run == null, "The departure opens where to set out, without setting out")
	check(sortie.chosen() == Chapters.ALL[0] and sortie.selected == 0 and sortie.has_focus() and sortie.told.name == "灰の回廊" and sortie.told.number == "第1章", "It opens on the first chapter, the page holding the focus")
	check(sortie.state_of(0) == "未踏" and sortie.told.state == "未踏" and range(1, Chapters.ALL.size()).all(func(index: int): return sortie.state_of(index) == "封印中"), "Each view tells how far its chapter has been taken")
	check(sortie.told.route == "3層とボス" and sortie.told.record == "なし" and sortie.told.boss == HubSortie.UNKNOWN_NAME, "The foot tells the way, the record, and a boss not met yet unnamed")
	var ruin_king: FoeData = load("res://data/foes/ruin_king.tres")
	var first_foes := Chapters.foes(Chapters.ALL[0])
	check(sortie.foes.size() == first_foes.size() and first_foes.has(ruin_king) and not first_foes.has(load("res://data/foes/gale_wolf_king.tres")), "The foes of the chapter are shown, its own boss among them")
	check(sortie.foes.all(func(foe: Array): return foe[0] != null and foe[1] == HubSortie.UNKNOWN_NAME and not foe[2]), "Foes not met are pictured as shapes and not named")
	check(sortie.gear.size() == 2 and sortie.gear[0][1] == "剣", "What she carries is shown: the sword and the first skill")
	check(not sortie.action_button.disabled and sortie.action_button.text == "第1章へ出撃する", "An open chapter can be set out for")
	# The button is a crest for the pointer; the focus stays on the page,
	# where Enter sets out, and up and down move nothing.
	var crest := sortie.action_button as CrestButton
	check(crest != null and crest.focus_mode == Control.FOCUS_NONE and is_zero_approx(crest.stand), "The set-out button is a crest that leaves the focus on the page")
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(sortie.has_focus() and sortie.selected == 0 and main.active_run == null, "Down neither leaves the page nor sets out")
	# The sealed chapter: chosen to read what opens it, not set out for.
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(sortie.chosen().id == &"gale_woods" and not sortie.told.open and sortie.told.state == "封印中" and sortie.has_focus(), "Right turns to the sealed chapter, shown sealed")
	check(sortie.action_button.disabled and sortie.action_button.text == "第2章は封印中" and (sortie.told.description as String).contains("第1章を踏破") and sortie.action_button.tooltip_text.contains("第1章を踏破"), "A sealed chapter says how it opens and cannot be set out for")
	root.push_input(key(KEY_RIGHT))
	root.push_input(key(KEY_RIGHT))
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(sortie.selected == Chapters.ALL.size() - 1, "Right stops at the last chapter")
	sortie._press([&"chapter", 1])
	check(sortie.chosen().id == &"gale_woods", "The pointer turns to a chapter by its view")
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
	check(hub.chapter.id == &"gale_woods" and sortie.chosen().id == &"gale_woods" and sortie.told.open, "A chapter that has just opened is the one offered next")
	check(not sortie.action_button.disabled and sortie.action_button.text == "第2章へ出撃する" and sortie.state_of(0) == "踏破 1回", "Once the first chapter is cleared, the second opens")
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(hub.chapter.id == &"ash_corridor" and sortie.told.boss == ruin_king.display_name, "Choosing an open chapter makes it the next departure, and a boss met is named")
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
	check(sortie.told.steps == 0 and not sortie.action_button.text.contains("段階"), "Before the ending the departure offers no step")
	main.meta.chapter_clears[final.id] = 1
	hub.refresh(main.meta)
	check(sortie.told.steps == 1 and sortie.step == 0 and sortie.told.step_note == "制約なし" and sortie.told.step_echo == "" and sortie.told.step_hint == "", "The ending opens the step row, at the game as it is")
	root.push_input(key(KEY_E))
	await process_frame
	check(hub.step == 1 and sortie.step == 1 and sortie.told.step_note == DifficultySteps.ALL[0].summary and sortie.told.step_echo == "残響 +10%", "E raises the step and tells what it adds and brings back")
	check(sortie.action_button.text.ends_with("（段階1）") and (sortie.told.constraints as String).contains(DifficultySteps.ALL[0].summary), "The button names the step, and pointing at the line lists what is in play")
	root.push_input(key(KEY_E))
	await process_frame
	check(hub.step == 1 and sortie.step == 1 and (sortie.told.step_hint as String).contains("段階1で%sを踏破" % Chapters.short_name(final)), "No step past the highest open; its arrow says how the next opens")
	root.push_input(key(KEY_Q))
	await process_frame
	check(hub.step == 0 and sortie.told.step_note == "制約なし", "Q lowers it")
	main.meta.chapter_clears.clear()
	hub.refresh(main.meta)
	check(sortie.told.steps == 0 and hub.step == 0, "Without the ending the row is gone again")
	hub.show_page("home")
	for pair: Array in [[&"upgrade", "upgrade"], [&"status", "status"], [&"codex", "codex"], [&"settings", "settings"]]:
		lobby.activated.emit(pair[0])
		check(hub.page == pair[1], "%s opens its page" % pair[0])
		hub.go_back()
		check(hub.page == "home", "Back returns to the lobby")

	# The bestiary: a folio of plates. A foe met is drawn and named with its
	# notes; one not met is a flat shade with nothing told.
	main.meta.met[&"dashing_rat"] = true
	hub.refresh(main.meta)
	hub.show_page("codex")
	var codex: HubCodex = hub.codex_page
	check(codex.has_focus() and codex.listed.size() == FoeCatalog.FOES.size() and codex.tally(0) == [1, FoeCatalog.FOES.size()], "The tray holds every foe, and the tally is of those met")
	var rat_index := FoeCatalog.FOES.find(load("res://data/foes/dashing_rat.tres"))
	var shadow := FoeIcon.of(FoeCatalog.FOES[0].visual_id, false).get_image()
	var dark := true
	for y in range(0, shadow.get_height(), 8):
		for x in range(0, shadow.get_width(), 8):
			var pixel := shadow.get_pixel(x, y)
			if pixel.a > 0.1 and pixel.v > 0.05:
				dark = false
	check(dark, "A foe not met is a dark silhouette in its icon")
	check(FoeIcon.of(FoeCatalog.FOES[0].visual_id, true).get_width() == FoeIcon.SIZE and FoeIcon.of(FoeCatalog.FOES[0].visual_id, true) == FoeIcon.of(FoeCatalog.FOES[0].visual_id, true), "An icon is one round size, made once and kept")
	codex.go_to(rat_index)
	check(codex.told.known and codex.told.name == "疾走ネズミ" and (codex.told.account[0] as String).contains("飛びかかる") and not (codex.told.account[1] as String).is_empty(), "A met foe's plate names it and tells how it behaves and where it is found")
	check(codex.told.stats.size() == 3 and codex.told.stats[0] == ["hp", "HP", 14] and codex.told.stats[2][0] == "speed", "Its figures are its notes: HP, the force of its blow, its pace")
	var portrait := codex.get_node_or_null(^"Figure/Portrait") as Sprite2D
	check(portrait != null and portrait.texture == EnemySprites.codex_portrait(codex.listed[rat_index].visual_id) and portrait.material == null, "The foe stands on the plate as its painted portrait")
	var king_met := codex.meta.met.has(ruin_king.id)
	codex.meta.met[ruin_king.id] = true
	codex.refresh(codex.meta)
	codex.go_to(FoeCatalog.FOES.find(ruin_king))
	check(codex.told.name == "遺跡王" and codex.told.epithet == "灰の回廊を統べる者" and codex.told.kind == "ボス", "A boss met carries its epithet and its kind")
	if not king_met:
		codex.meta.met.erase(ruin_king.id)
	codex.refresh(codex.meta)
	codex.go_to(0)
	check(not codex.told.known and codex.told.name == HubCodex.UNKNOWN_NAME and codex.told.stats.is_empty() and codex.told.epithet.is_empty() and codex.told.account == [HubCodex.UNKNOWN_NOTE, ""], "An unmet foe's name, figures, epithet and account stay hidden")
	check(portrait.material is ShaderMaterial and ((portrait.material as ShaderMaterial).shader as Shader).resource_path.ends_with("flat_shape.gdshader"), "An unmet foe stands on the plate as a flat shade, none of its painting showing")
	codex.go_to(FoeCatalog.FOES.find(ruin_king))
	check(not codex.told.known and codex.told.epithet.is_empty() and codex.told.kind == "ボス", "An unmet boss gives away its kind and nothing else")
	codex.go_to(0)
	# Its keys: left and right turn the plates, Q/E change the kind, R the order.
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(codex.place == 1 and codex.told.name == "疾走ネズミ", "Right turns to the next plate")
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(codex.place == 0, "Left turns back")
	root.push_input(key(KEY_E))
	await process_frame
	check(codex.kind == 1 and codex.place == 0 and codex.listed.all(func(foe: FoeData): return FoeCatalog.kind_of(foe) == 1), "E turns to the next kind, whose tray holds only that kind")
	root.push_input(key(KEY_R))
	await process_frame
	check(codex.sort == 1 and codex.listed[0].id == &"dashing_rat" and codex.listed.slice(1).all(func(foe: FoeData): return not codex.known(foe)), "R orders the tray by a figure: the foes met first, those not met after them all")
	check(codex.listed[codex.place].id == &"wandering_sentinel", "The plate open stays open when the order changes")
	codex._press([&"ribbon", 3])
	codex._press([&"specimen", 1])
	check(codex.kind == 3 and codex.place == 1 and FoeCatalog.kind_of(codex.listed[1]) == 3, "The pointer opens a kind by its ribbon and a plate by its specimen")
	codex._press([&"sort", 0])
	codex._press([&"sort", 0])
	codex._press([&"sort", 0])
	codex._press([&"ribbon", 0])
	check(codex.sort == 0 and codex.kind == 0, "The order comes round to the catalog's own")
	hub.show_page("home")

	# The settings: every row in one list under its group's name, the one
	# under the cursor shown and told beside it.
	hub.show_page("settings")
	var settings_page: HubSettings = hub.settings_page
	check(settings_page.has_focus() and settings_page.focused_row == 0 and settings_page.shown_rows() == [0, 1, 2, 3, 4, 5, 9, 6, 7, 8], "The settings open on the first of all ten rows, the language leading the last group")
	check(HubSettings.TABS.map(func(tab: Array): return tab[0]) == ["サウンド", "グラフィック", "その他"] and settings_page.value_text(0) == "100%" and settings_page.value_text(4) == "標準" and settings_page.value_text(7) == "開く", "The rows stand in three groups, each telling its value")
	root.push_input(key(KEY_DOWN))
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(settings_page.focused_row == 2 and settings_page.note_text() == HubSettings.NOTES[2], "Down goes through the list, and the row under the cursor is told beside it")
	var effects_before: float = hub.settings.effects_volume
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(is_equal_approx(hub.settings.effects_volume, effects_before - 0.05) and settings_page.value_text(2) == "95%", "Left turns a volume down a step, at once")
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(is_equal_approx(hub.settings.effects_volume, effects_before) and not settings_page.change(1), "Right turns it up again, no higher than all of it")
	root.push_input(key(KEY_E))
	await process_frame
	check(settings_page.focused_row == HubSettings.SHAKE_ROW and settings_page.note_text() == HubSettings.NOTES[4], "E jumps to the next group's first row")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(hub.settings.shake_level == 1 and settings_page.value_text(4) == "弱め", "Enter on a choice takes its next")
	settings_page.put(HubSettings.SHAKE_ROW, 0)
	root.push_input(key(KEY_E))
	await process_frame
	check(settings_page.focused_row == HubSettings.LANGUAGE_ROW and settings_page.note_text() == HubSettings.NOTES[9], "The last group opens on the language")
	root.push_input(key(KEY_E))
	await process_frame
	check(settings_page.focused_row == 0, "E from the last group comes round to the first")
	# The pointer: resting on a row chooses it, a click on a volume's bar
	# sets it there, and a mark beside a choice steps it.
	settings_page._rest_row = HubSettings.QUIT_ROW
	settings_page._rest_since = settings_page._clock
	await create_timer(HubLobby.HOVER_INTENT + 0.1).timeout
	check(settings_page.focused_row == HubSettings.QUIT_ROW, "Pointing at a settings row chooses it")
	settings_page._rest_row = -1
	settings_page._tracks[1] = Rect2(276.0, 0.0, 300.0, 4.0)
	settings_page._press([&"track", 1], settings_page._origin + Vector2(276.0 + 150.0, 0.0) * settings_page._zoom)
	check(settings_page.focused_row == 1 and settings_page.percent(1) == 50, "A click on a volume's bar sets it there")
	settings_page._dragging = -1
	settings_page.put(1, 80)
	settings_page._press([&"step", HubSettings.CONTROLS_ROW, 1])
	check(settings_page.focused_row == HubSettings.CONTROLS_ROW and not hub.settings.show_controls, "A mark beside a choice steps it")
	settings_page.put(HubSettings.CONTROLS_ROW, 0)
	check(settings_page.topic_buttons[0].get_theme_stylebox(&"focus") is StyleBoxEmpty, "Chosen help rows draw no frame")
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
	# Quitting's way back says so, beside the way out.
	settings_page.choose(HubSettings.QUIT_ROW)
	settings_page.accept()
	check(settings_page.quit_prompt.visible and settings_page.quit_prompt.cancel_button.text == "戻る" and settings_page.quit_prompt.cancel_button.has_focus(), "Quitting asks first, its way back named and waiting")
	settings_page.quit_prompt.canceled.emit()
	check(not settings_page.quit_prompt.visible and settings_page.has_focus() and settings_page.focused_row == HubSettings.QUIT_ROW, "The way back returns to the row it was asked from")
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
	check(not settings_page.help_layer.visible and settings_page.has_focus() and settings_page.focused_row == HubSettings.HELP_ROW and hub.title_label.text == "設定", "Clicking the close returns to the settings")
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
	check(page.selected == MetaProgress.ROOT and page.has_focus(), "The chart opens on its lantern, the focus on the chart")
	var stars := 0
	var apart := true
	for one in MetaProgress.UPGRADES:
		stars += 1 if page._places.has(one.id) else 0
		for other in MetaProgress.UPGRADES:
			if one != other and (page._places[one.id] as Vector2).distance_to(page._places[other.id]) < MetaUpgradePage.STAR * 2.0 + 6.0:
				apart = false
	check(stars == MetaProgress.UPGRADES.size() and apart, "Every upgrade has a star of its own, none standing on another")
	var sky := Rect2(Vector2.ZERO, Vector2(MetaUpgradePage.CARD.position.x, MetaUpgradePage.DESIGN.y))
	check(MetaProgress.UPGRADES.all(func(one: MetaUpgrade) -> bool: return sky.grow(-MetaUpgradePage.STAR).has_point(page._places[one.id])), "Every star is in sight at once, left of the card")
	check(page.state_of(MetaProgress.ROOT) == MetaUpgradePage.State.BUY and page.state_of(&"sturdy_body") == MetaUpgradePage.State.LOCKED, "A star tells whether the echo can light it or it waits on another")
	page.buy_button.pressed.emit()
	check(main.meta.rank(MetaProgress.ROOT) == 1 and main.meta.echo == 150 and hub.echo_label.text == "150", "Pressing the card's button buys the chosen star")
	check(page.buy_button.text == "習得済み" and page.buy_button.disabled and hub.feedback.text.contains("残響の灯"), "The card and the note show the purchase")
	check(page.told.state == MetaUpgradePage.State.FULL and page.told.price < 0, "A star with all its ranks held has no price")
	check(page.moment(MetaProgress.ROOT) < 1.0 and page.moment(&"sturdy_body") == 1.0, "The star bought has its moment, and only it")
	# Moving the cursor: left from the lantern to the body's constellation.
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(page.selected == &"sturdy_body" and page.told.name == "鍛えた体" and page.told.part == "身体", "Left goes to the body's constellation and the card tells the star")
	check(page.buy_button is CrestButton and page.told.price == 80 and page.told.held == 150 and page.told.missing == 0, "The card sets the price beside the echo held, over a crest button")
	check(page.told.figure == "習得すると　最大HP 115（+15）" and page.told.note == "" and page.told.ranks == 3, "The card tells what the first rank gives in one line, without the description saying it again")
	check(page.tally(&"body") == [0, 17], "A constellation counts the ranks held in it")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.rank(&"sturdy_body") == 1 and main.meta.echo == 70 and page.told.figure == "最大HP 115 → 130（+15）", "Enter on the chart buys the star, and the figure tells the next rank")
	check(page.tally(&"body") == [1, 17] and page.told.rank == 1, "The rank bought is counted")
	root.push_input(key(KEY_UP))
	await process_frame
	check(page.selected == &"double_dash" and page.buy_button.disabled and page.buy_button.tooltip_text.contains("足りない"), "Up goes along the constellation to a star the echo cannot light")
	check(page.told.state == MetaUpgradePage.State.SHORT and page.told.missing == 230 and page.told.held == 70, "The card says how much echo is missing")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.rank(&"double_dash") == 0 and main.meta.echo == 70, "One the echo cannot pay for is refused")
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(page.selected != &"double_dash" and MetaProgress.find(page.selected).parent == &"double_dash", "Left goes on to a star that grows from it")
	check(page.told.state == MetaUpgradePage.State.LOCKED and page.told.waits.contains("二段ダッシュ") and page.buy_button.disabled and page.buy_button.tooltip_text.contains("二段ダッシュ"), "A star that waits on another says which")
	page.choose(&"learn_echo_burst")
	check(page.buy_button.visible and page.told.name == "残響解放の習得" and page.told.part == "必殺技", "The special constellation's first star is a special move to learn")
	root.push_input(key(KEY_C))
	await process_frame
	check(page.selected == MetaProgress.ROOT, "C brings the lantern back")
	# Q/E go round the constellations, clockwise from the top.
	root.push_input(key(KEY_E))
	await process_frame
	check(page.selected == &"learn_thunder_flash", "E goes to the first constellation's first star")
	root.push_input(key(KEY_E))
	await process_frame
	check(page.selected == &"learn_spear", "E again goes to the next constellation")
	root.push_input(key(KEY_Q))
	root.push_input(key(KEY_Q))
	await process_frame
	check(page.selected == &"sturdy_body", "Q goes back round, past the top to the last")
	# The pointer chooses a star or a constellation and never buys by them;
	# the wheel goes round the constellations.
	var echo_before: int = main.meta.echo
	page._press([&"star", &"parting_blessing"])
	check(page.selected == &"parting_blessing" and main.meta.echo == echo_before, "A click on a star chooses it and buys nothing")
	page._press([&"part", &"weapon"])
	check(page.selected == &"learn_spear", "A click on a constellation's name goes to its first star")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	page._gui_input(wheel)
	check(page.selected == &"parting_blessing", "The wheel goes to the next constellation")
	page.return_to_root()
	check(page.selected == MetaProgress.ROOT, "The lantern is chosen again")
	# The status page, a book: Tab from the upgrades opens it at the first
	# skill's chapter; its index, her figures and back, a skill moved to the
	# other chapter (saved), a weapon taken up, the special's chapter sealed
	# and then opened.
	root.push_input(key(KEY_TAB))
	await process_frame
	var status: HubStatus = hub.status_page
	check(hub.page == "status" and status.has_focus() and status.slot == 1 and not status.details_open, "Tab goes to the status page, at the first skill's chapter")
	check(status.entry_ids() == [HubStatus.CLEAR_ID, &"slam", &"thunder_flash", &"swallow_cut", &"blaze_ring", &"wisp_shot", &"thunder_circle"], "The chapter's index lists what the slot can hold, the way to empty it first")
	check(status.entries[status.row].id == &"slam" and status.entries[status.row].state == HubStatus.State.HERE and status.told.name == "叩きつけ", "The cursor opens on what the slot holds, and the right page tells it")
	check(status.entries[1].note == "再使用 6秒" and status.entries[2].state == HubStatus.State.UNKNOWN and status.entries[2].name == HubStatus.UNKNOWN_NAME and status.entries[2].note == HubStatus.UNOWNED, "Each entry carries its short figure; one not learned is unknown and unowned")
	check(status.told.figures.size() == 3 and status.told.figures[0] == ["再使用", "6秒"] and status.told.figures[1][0] == "威力", "The right page tells the skill's figures a row each")
	check(not status.told.can and status.told.outcome.is_empty(), "What the slot already holds offers no seal")
	var hp_row: Array = status.stat_rows()[0]
	check(hp_row[1] == "115" and hp_row[2] == "(+15)" and hp_row[3].contains("鍛えた体 +15"), "Her health shows what the upgrades add, and its breakdown")
	root.push_input(key(KEY_R))
	await process_frame
	check(status.details_open and status.chapter() == HubStatus.FIGURES and status.shown_rows == status.stat_rows().size() and status.shown_rows >= 14, "R turns the book to all her figures")
	root.push_input(key(KEY_ESCAPE))
	await process_frame
	check(hub.page == "status" and not status.details_open and status.slot == 1 and status.has_focus(), "Back from her figures returns to the chapter left")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.loadout == [&"slam", &""], "Enter on what the slot already holds changes nothing")
	root.push_input(key(KEY_E))
	await process_frame
	check(status.slot == 2 and status.entries[status.row].id == &"slam" and status.entries[1].state == HubStatus.State.ELSEWHERE and status.entries[1].other == 1, "E turns to the second skill's chapter, where the skill is marked as set in the first")
	check(status.told.can and status.told.action == "入れ替える" and status.told.outcome == "Q から移す", "A skill set in the other slot offers to move, and says what that does")
	root.push_input(key(KEY_X))
	await process_frame
	check(main.meta.loadout == [&"slam", &""], "X on an empty slot changes nothing")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.loadout == [&"", &"slam"] and hub.feedback.text.contains("スキル2"), "Enter presses the seal: the skill moves to this slot")
	check(status.entries[status.row].id == &"slam" and status.entries[status.row].state == HubStatus.State.HERE and not status.told.can, "What the slot now holds is marked as held, the cursor on it")
	root.push_input(key(KEY_UP))
	await process_frame
	check(status.shown_id == HubStatus.CLEAR_ID and status.told.can and status.told.outcome == "「叩きつけ」を外す", "Up reaches the entry that empties the slot, which says what it would remove")
	root.push_input(key(KEY_DOWN))
	await process_frame
	# The attack's chapter: the sword held, the others unknown until learned;
	# learned, one is taken up there.
	root.push_input(key(KEY_Q))
	root.push_input(key(KEY_Q))
	await process_frame
	check(status.slot == 0 and status.entry_ids() == [&"sword", &"spear", &"hammer"] and status.entries[1].state == HubStatus.State.UNKNOWN and status.entries[0].state == HubStatus.State.HERE, "Q turns back to the attack's chapter: the sword held, the other weapons unknown")
	main.meta.ranks["learn_spear"] = 1
	hub.refresh(main.meta, "")
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(status.told.name == "槍" and status.told.action == "持ち替える" and status.told.figures[0] == ["連撃", "3段"] and status.told.outcome == "「剣」と替える", "The right page tells the spear and offers to take it up in the sword's place")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.weapon == &"spear" and status.entries[status.row].id == &"spear" and hub.feedback.text.contains("持ち替え"), "Enter on it takes the spear up")
	# The pointer: a tab turns to its chapter, a second click on the chosen row seals it.
	status._press([&"tab", HubStatus.SPECIAL_SLOT])
	await process_frame
	check(status.slot == 3 and status.entry_ids() == [&"echo_burst", &"sky_rend", &"crimson_lotus"] and status.entries.all(func(entry: Dictionary): return entry.state == HubStatus.State.UNKNOWN) and not status.told.can, "The sealed special's chapter lists its moves as shadows, none to be sealed")
	# The special's chapter opens once a special move is learned.
	main.meta.ranks["learn_echo_burst"] = 1
	hub.refresh(main.meta, "")
	check(status.slot == 3 and status.entry_ids() == [HubStatus.CLEAR_ID, &"echo_burst", &"sky_rend", &"crimson_lotus"] and status.entries[2].state == HubStatus.State.UNKNOWN, "Once a special move is learned, its chapter offers it and the way to empty the slot")
	status._press([&"row", 1])
	await process_frame
	check(status.told.name == "残響解放" and status.told.action == "装備する" and status.told.outcome == "R に付ける", "A click chooses the special move, and the page offers to set it")
	status._press([&"row", 1])
	await process_frame
	check(main.meta.special == &"echo_burst" and status.entries[1].state == HubStatus.State.HERE and hub.feedback.text.contains("必殺技"), "A second click on it sets the special move")
	status._press([&"tab", HubStatus.FIGURES])
	await process_frame
	check(status.details_open, "The last tab opens her figures")
	root.push_input(key(KEY_R))
	await process_frame
	check(not status.details_open and status.slot == 3, "R returns to the chapter left")
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
