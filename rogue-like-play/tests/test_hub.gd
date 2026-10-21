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


func run_tests() -> void:
	folder = "res://.godot/hub-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))

	# The lobby.
	var main := make_main(100)
	await process_frame
	var hub = main.get_node("Hub")
	var lobby: HubLobby = hub.home_page
	check(lobby.buttons.size() == 4 and HubLobby.ENTRIES.map(func(entry: Array): return entry[0]) == [&"departure", &"upgrade", &"codex", &"settings"], "The lobby offers departure, upgrades, encyclopedia and settings")
	check(hub.page == "home" and lobby.visible and hub.echo_label.text == "100", "The base opens on the lobby with the echo held")
	check(lobby.route_value.text == "3層とボス" and lobby.best_value.text == "なし", "The departure tells the chapter's way and the deepest reached")
	check(lobby.upgrade_ready.text == "1 件" and lobby.codex_met.text == "0 / %d" % FoeCatalog.FOES.size(), "The entries tell what can be bought and what has been met")
	lobby.select(0)
	check(lobby.title_label.text == hub.chapter.display_name and lobby.decide_button.text.ends_with("出撃する"), "The departure names its chapter")
	for pair: Array in [[&"upgrade", "upgrade"], [&"codex", "codex"], [&"settings", "settings"]]:
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
	check(codex.cards[rat_index].icon is AtlasTexture and codex.cards[0].icon is ImageTexture, "Each tile shows its foe: the picture when met, a silhouette when not")
	codex._select(rat_index, false)
	check(codex.name_label.text == "疾走ネズミ" and codex.description_label.text.contains("飛びかかる"), "A met foe's account is told")
	codex._select(0, false)
	check(codex.name_label.text == HubCodex.UNKNOWN_NAME and codex.stats_label.text.is_empty(), "An unmet foe's figures stay hidden")
	codex.kind_tabs.step(1)
	check(codex.rows.all(func(foe: FoeData): return FoeCatalog.kind_of(foe) == 1), "The kind tabs filter the list")
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
	page.buttons[0].pressed.emit()
	check(main.meta.rank(&"sturdy_body") == 1 and main.meta.echo == 120 and hub.echo_label.text == "120", "Pressing an upgrade's button buys its rank")
	check(page.rank_labels[0].text == "段階 1 / 3" and hub.feedback.text.contains("鍛えた体"), "The page and the note show the purchase")
	page.buttons[1].pressed.emit()
	check(main.meta.rank(&"double_dash") == 0 and main.meta.echo == 120, "One the echo cannot pay for is refused")
	main.free()
	await process_frame
	var reader := MetaStore.new()
	reader.path = path
	var read_back := reader.load_progress()
	check(read_back.rank(&"sturdy_body") == 1 and read_back.echo == 120, "The purchase is still there after a restart")

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
