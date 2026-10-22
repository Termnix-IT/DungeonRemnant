extends SceneTree

# The base between runs: the lobby's four entries and what each tells, the
# pages they open and the way back, buying a lasting upgrade (saved, read
# back after a restart, refused when the echo is short), the encyclopedia
# telling met foes from unmet ones, the help speaking of the real-time game,
# a save that cannot be read shown as an alert, and setting out on a run.

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
	check(lobby.title_label.text == hub.chapter.display_name and lobby.decide_button.text.ends_with("出撃する"), "The departure names its chapter")
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
	check(codex.cards[rat_index].text == "疾走ネズミ" and codex.cards[0].text == HubCodex.UNKNOWN_NAME, "A met foe is named, an unmet one is not")
	var picture: Texture2D = codex.cards[rat_index].icon
	var shadow: Texture2D = codex.cards[0].icon
	var shade := shadow.get_image()
	var dark := true
	for y in range(0, shade.get_height(), 8):
		for x in range(0, shade.get_width(), 8):
			var pixel := shade.get_pixel(x, y)
			if pixel.a > 0.1 and pixel.v > 0.05:
				dark = false
	check(picture != null and shadow != null and picture != shadow and dark, "Each tile shows its foe: the picture when met, a dark silhouette when not")
	var square := codex.cards.all(func(card: Button): return card.icon.get_width() == card.icon.get_height())
	check(square, "Every tile's picture is a square, so every name sits at the same height")
	codex._select(rat_index, false)
	check(codex.name_label.text == "疾走ネズミ" and codex.description_label.text.contains("飛びかかる"), "A met foe's account is told")
	codex._select(0, false)
	check(codex.name_label.text == HubCodex.UNKNOWN_NAME and codex.stats_label.text.is_empty(), "An unmet foe's figures stay hidden")
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
	check(settings_page.note_title.text == "効果音" and settings_page.note.text == HubSettings.NOTES[2], "The focused setting is told beside the rows")
	settings_page.tabs.step(1)
	await process_frame
	check(shown_rows.call() == [4, 5] and settings_page.shake_cycler.has_focus() and settings_page.note_title.text == "画面の揺れ", "The next tab shows the graphics rows and focuses the first")
	check(settings_page.display_cycler.get_node(settings_page.display_cycler.focus_neighbor_bottom) == settings_page.display_cycler, "The focus stays within the tab")
	settings_page.tabs.step(1)
	await process_frame
	check(shown_rows.call() == [6, 7, 8] and settings_page.controls_cycler.has_focus(), "The last tab holds the controls guide, the help and quitting")
	# As in the lobby, the pointer resting on a row (its caption or its
	# control) chooses it; a chosen row shows by its band, with no frame.
	settings_page._rows[8].gui_input.emit(InputEventMouseMotion.new())
	await create_timer(HubLobby.HOVER_INTENT + 0.05).timeout
	check(settings_page.quit_button.has_focus() and settings_page.focused_row == 8, "Pointing at a settings row chooses it")
	settings_page.help_button.mouse_entered.emit()
	await create_timer(HubLobby.HOVER_INTENT + 0.05).timeout
	check(settings_page.help_button.has_focus() and settings_page.note_title.text == "ヘルプ", "Pointing at a row's control chooses it too")
	check(settings_page.help_button.get_theme_stylebox(&"focus") is StyleBoxEmpty and settings_page.topic_buttons[0].get_theme_stylebox(&"focus") is StyleBoxEmpty, "Chosen settings and help rows draw no frame")
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
	check(HubSettings.HELP.size() == 4 and help_text.contains("残響") and help_text.contains("ダッシュ"), "The help tells the run, the echo and the controls")
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
	check(page.selected == MetaProgress.ROOT and (page.nodes[MetaProgress.ROOT] as Button).has_focus(), "The tree opens on its root")
	check(page.nodes.size() == MetaProgress.UPGRADES.size() + MetaUpgradePage.SEALS.size(), "Every upgrade and every sealed branch has its node")
	page.buy_button.pressed.emit()
	check(main.meta.rank(MetaProgress.ROOT) == 1 and main.meta.echo == 150 and hub.echo_label.text == "150", "Pressing the column's button buys the chosen node")
	check(page.buy_button.text == "習得済み" and page.buy_button.disabled and hub.feedback.text.contains("残響の灯"), "The column and the note show the purchase")
	# Moving the focus: left from the root to the body's branch.
	root.push_input(key(KEY_LEFT))
	await process_frame
	check(page.selected == &"sturdy_body" and page.name_label.text == "鍛えた体" and page.rank_label.text.contains("段階 0 / 3"), "Left goes to the body's branch and the column tells it")
	check(page.figure_label.text == "習得すると　最大HP 115", "The column tells what the first rank gives")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.rank(&"sturdy_body") == 1 and main.meta.echo == 70 and page.figure_label.text == "最大HP 115 → 130", "Enter on a node buys it, and the figure tells the next rank")
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(page.selected == &"double_dash" and page.buy_button.disabled and page.buy_button.tooltip_text.contains("足りない"), "Down goes along the branch to one the echo cannot pay for")
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
	# The status page: Tab from the upgrades, the slots and their tiles, a
	# skill moved to the other slot (saved), back from the tiles, the details.
	root.push_input(key(KEY_TAB))
	await process_frame
	var status: HubStatus = hub.status_page
	check(hub.page == "status" and status.slot_buttons[1].has_focus() and status.name_label.text == "叩きつけ", "Tab goes to the status page, on the first skill slot")
	check(status.slot_buttons.size() == 4 and status.slot_buttons[0].text.contains("剣") and status.slot_buttons[2].text.contains("空き") and status.slot_buttons[3].text.contains("封印"), "The slots tell the sword, the empty slot and the sealed special")
	var hp_row: Array = status.stat_rows()[0]
	check(hp_row[1] == "115" and hp_row[2] == "(+15)" and hp_row[3].contains("鍛えた体 +15"), "Her health shows what the upgrades add, and its breakdown")
	var always := status.stats.get_child_count()
	root.push_input(key(KEY_R))
	await process_frame
	check(status.details_open and status.stats.get_child_count() > always, "R opens the rest of her figures")
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(status.slot == 2 and status.tiles_label.text.contains("スキル2") and status.tile_ids == [HubStatus.CLEAR_ID, &"slam", &"thunder_flash", &"swallow_cut", &"blaze_ring"] and status.tiles[2].text == HubStatus.UNKNOWN_NAME, "Choosing the second slot shows its tiles")
	check(status.tiles[1].text.contains("スキル1"), "A tile tells the slot its skill is set in")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(status.tiles[0].has_focus(), "Enter on a slot goes into its tiles")
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(status.action_button.text == "入れ替える" and not status.action_button.disabled, "A skill set in the other slot offers to change places")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.loadout == [&"", &"slam"] and status.slot_buttons[2].has_focus() and hub.feedback.text.contains("スキル2"), "Enter on a tile sets it, and the focus returns to the slot")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	root.push_input(key(KEY_ESCAPE))
	await process_frame
	check(hub.page == "status" and status.slot_buttons[2].has_focus(), "Back from the tiles returns to their slot")
	# The special slot opens once a special move is learned.
	main.meta.ranks["learn_echo_burst"] = 1
	hub.refresh(main.meta, "")
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(status.slot == 3 and status.tile_ids == [HubStatus.CLEAR_ID, &"echo_burst", &"sky_rend"] and status.tiles[2].text == HubStatus.UNKNOWN_NAME and status.slot_buttons[3].text.contains("空き"), "Once a special move is learned, its slot opens with its tiles")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	root.push_input(key(KEY_RIGHT))
	await process_frame
	check(status.name_label.text == "残響解放" and status.action_button.text == "装備する", "The column tells the special move and offers to set it")
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(main.meta.special == &"echo_burst" and status.slot_buttons[3].text.contains("残響解放") and hub.feedback.text.contains("必殺技"), "Enter on it sets the special move")
	root.push_input(key(KEY_TAB))
	await process_frame
	check(hub.page == "upgrade", "Tab goes back to the upgrades")
	main.free()
	await process_frame
	var reader := MetaStore.new()
	reader.path = path
	var read_back := reader.load_progress()
	check(read_back.rank(&"sturdy_body") == 1 and read_back.rank(MetaProgress.ROOT) == 1 and read_back.echo == 70, "The purchases are still there after a restart")
	check(read_back.loadout == [&"", &"slam"] and read_back.special == &"echo_burst", "So are the skill and special slots")

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
	var run: RunDirector = main.active_run
	check(run != null and not hub.visible and run.returns_to_base and run.meta == main.meta, "The departure starts a run shaped by the progress")
	check(run.map_view.visible, "The run opens on its route")
	hub.home_page.activated.emit(&"departure")
	check(main.active_run == run, "A second departure is ignored while a run lasts")
	main.free()
	await process_frame

	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + name)
	DirAccess.remove_absolute(folder)
	print("Hub tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
