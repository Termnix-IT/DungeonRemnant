extends SceneTree

# The English translation: the table (locale/text.csv) holds a row for every
# Japanese text the game shows and none for text it no longer shows; its
# imported translation is the table as written; the language is chosen in
# the settings, saved, and rebuilds the base in it; and every word on the
# screens goes through tr(). The last is checked with pseudolocalization,
# which marks every translated text ⟦like this⟧: Japanese outside the marks
# was shown without being translated.

const TextCatalog := preload("res://tools/text_catalog.gd")
const OPEN := "⟦"
const CLOSE := "⟧"
# The text a node shows that is not its `text`: drawn by the node itself.
const SHOWN_PROPERTIES: Array[StringName] = [&"text", &"tooltip_text", &"caption", &"note", &"placeholder_text"]

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


# The text left outside the pseudolocalization's marks. A mark cut by
# slicing a translated text (Chapters.short_name) still marks its side.
static func unmarked(text: String) -> String:
	var left := ""
	var depth := 0
	var last_open := text.rfind(OPEN)
	var cut := text.rfind(CLOSE)
	if cut >= 0 and text.count(CLOSE) > text.count(OPEN):
		text = text.substr(cut + 1)
	elif last_open >= 0 and text.count(OPEN) > text.count(CLOSE):
		text = text.substr(0, last_open)
	for letter in text:
		if letter == OPEN:
			depth += 1
		elif letter == CLOSE:
			depth = maxi(depth - 1, 0)
		elif depth == 0:
			left += letter
	return left


# "path: text" for every shown text under `node` with Japanese outside the
# marks, each text once.
func untranslated(node: Node, found: Dictionary = {}) -> Dictionary:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return found
	var texts: Array[String] = []
	for property in SHOWN_PROPERTIES:
		var value = node.get(property)
		if value is String:
			texts.append(value)
	for meta: StringName in [&"keys", &"buttons"]:
		if node.has_meta(meta):
			texts.append(String(node.get_meta(meta)))
	for text in texts:
		# The languages are named in their own words in every language.
		if GameSettings.LANGUAGE_NAMES.has(text):
			continue
		if TextCatalog.has_japanese(unmarked(text)) and not found.has(text):
			found[text] = "%s: %s" % [node.get_path(), text.replace("\n", "⏎")]
	for child in node.get_children():
		untranslated(child, found)
	return found


func report(where: String, found: Dictionary) -> void:
	for text: String in found:
		print("  untranslated (%s) %s" % [where, found[text]])
	check(found.is_empty(), "Every word shown on %s goes through tr() (%d do not)" % [where, found.size()])


func pseudo(on: bool) -> void:
	ProjectSettings.set_setting("internationalization/pseudolocalization/prefix", OPEN)
	ProjectSettings.set_setting("internationalization/pseudolocalization/suffix", CLOSE)
	ProjectSettings.set_setting("internationalization/pseudolocalization/replace_with_accents", false)
	TranslationServer.pseudolocalization_enabled = on
	TranslationServer.reload_pseudolocalization()


func wait(seconds: float) -> void:
	for index in roundi(seconds * 60.0):
		await process_frame


func make_main() -> Node:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.saving_enabled = false
	root.add_child(main)
	main.meta.echo = 500
	main.get_node("Hub").refresh(main.meta)
	return main


func run_tests() -> void:
	# The table and the game agree.
	var table := TextCatalog.read_table()
	var found := TextCatalog.gather()
	var missing: Array[String] = []
	var gathered := {}
	for row in found:
		var id := TextCatalog.row_id(row.key, row.context)
		gathered[id] = true
		if not table.has(id):
			missing.append(row.key)
	var stale: Array[String] = []
	for id: String in table:
		if not gathered.has(id):
			stale.append(table[id].key)
	check(missing.is_empty(), "Every Japanese text has a row in the table (run tools/text_catalog.gd): %s" % [missing.slice(0, 5)])
	check(stale.is_empty(), "No row is left for a text the game no longer shows: %s" % [stale.slice(0, 5)])
	var english := 0
	var mismatched: Array[String] = []
	TranslationServer.set_locale("en")
	for id: String in table:
		var row: Dictionary = table[id]
		if row.en == "":
			continue
		english += 1
		if String(TranslationServer.translate(row.key, row.context)) != row.en:
			mismatched.append(row.key)
	TranslationServer.set_locale("ja")
	check(mismatched.is_empty(), "The imported translation is the table as written (import again): %s" % [mismatched.slice(0, 5)])
	print("  %d of %d rows have English" % [english, table.size()])
	check(String(TranslationServer.translate(found[0].key)) == found[0].key, "In Japanese the text is shown as written")

	# The language is a setting of its own, saved, and the machine's decides
	# until one is chosen.
	var settings := GameSettings.new()
	settings.path = "user://translation-test-settings.cfg"
	check(settings.language == "" and settings.shown_language() == GameSettings.machine_language(), "Until chosen, the machine's language is shown")
	settings.language = "en"
	settings.save_settings()
	var read_back := GameSettings.new()
	read_back.path = settings.path
	read_back.load_settings()
	check(read_back.language == "en", "The chosen language is saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))

	# Choosing a language in the settings rebuilds the base in it, opened on
	# the language's row.
	var main := make_main()
	await process_frame
	var hub: Node = main.get_node("Hub")
	hub.show_page("settings")
	hub.settings_page.focus_language()
	await process_frame
	check(hub.settings_page.language_cycler.has_focus() and hub.settings_page.tabs.selected == 2, "The language leads the settings' last tab")
	hub.settings_page.language_cycler.step(1)
	await process_frame
	await process_frame
	var rebuilt: Node = main.get_node("Hub")
	check(rebuilt != hub and TranslationServer.get_locale() == "en" and rebuilt.settings.language == "en", "Another language rebuilds the base in it")
	check(rebuilt.page == "settings" and rebuilt.settings_page.language_cycler.has_focus() and rebuilt.settings_page.language_cycler.text == "English", "The rebuilt base opens on the language's row")
	rebuilt.settings_page.language_cycler.step(1)
	await process_frame
	await process_frame
	check(TranslationServer.get_locale() == "ja", "And back to Japanese")
	main.queue_free()
	await process_frame

	# Every word the base shows is translated.
	pseudo(true)
	main = make_main()
	await process_frame
	hub = main.get_node("Hub")
	var seen := {}
	for page: String in ["home", "sortie", "upgrade", "status", "codex", "settings"]:
		hub.show_page(page)
		await process_frame
		untranslated(hub, seen)
		if page == "settings":
			for tab in hub.settings_page.TABS.size():
				hub.settings_page.show_tab(tab)
				await process_frame
				untranslated(hub, seen)
			for topic in hub.settings_page.HELP.size():
				hub.settings_page.open_help(topic)
				await process_frame
				untranslated(hub, seen)
			hub.settings_page.close_help()
	report("the base", seen)
	main.queue_free()
	await process_frame

	# And every word a run shows: the map, its menu and its question, each
	# event, a fight's HUD with the first lessons, the level-up's cards, the
	# fight's menu with its settings, and the result.
	main = make_main()
	main.run_seed = 5
	await process_frame
	main.start_run()
	await wait(0.5)
	var director: RunDirector = main.active_run
	seen = {}
	untranslated(director, seen)
	director.open_map_menu()
	await process_frame
	untranslated(director, seen)
	director.map_menu.open_controls()
	await process_frame
	untranslated(director, seen)
	director.map_menu.back()
	director.map_menu.open_settings()
	await process_frame
	untranslated(director, seen)
	director.map_menu.back()
	director.map_menu.resume()
	await process_frame
	var first: RouteMap.Waypoint = director.map_view.current[0]
	director.map_view.pick(first)
	await process_frame
	untranslated(director, seen)
	for path: String in ["res://data/areas/event_merchant.tres", "res://data/areas/event_altar.tres", "res://data/areas/event_curse.tres", "res://data/areas/event_spring.tres", "res://data/areas/event_shelf.tres"]:
		var point := RouteMap.Waypoint.new(load(path), AreaData.Reward.BOON, 0)
		director.run.route.layers[0].append(point)
		director.show_map()
		director.enter(point)
		await process_frame
		untranslated(director, seen)
		director._leave_event()
		await process_frame
		# Leaving moves on a layer; each event is visited from the first.
		director.run.layer = 0
	director.show_map()
	director.enter(first)
	await wait(1.0)
	untranslated(director, seen)
	var area := director.area
	area.run.progression.pending_choices = 1
	area._offer()
	await process_frame
	untranslated(director, seen)
	director.choice._select(0)
	await wait(0.3)
	area.open_menu()
	await process_frame
	untranslated(director, seen)
	area.menu.open_controls()
	await process_frame
	untranslated(director, seen)
	area.menu.back()
	area.menu.open_settings()
	for tab in area.menu.settings_page.TABS.size():
		area.menu.settings_page.show_tab(tab)
		await process_frame
		untranslated(director, seen)
	area.menu.back()
	area.menu.resume()
	await process_frame
	director.finish(false)
	await wait(0.5)
	untranslated(director, seen)
	report("a run", seen)
	paused = false
	main.queue_free()
	await process_frame

	# The prologue's and the ending's stills, the staff roll and the thanks.
	seen = {}
	for scenes: Array in [EndingView.PROLOGUE, EndingView.SCENES]:
		var view := EndingView.new()
		view.scenes = scenes
		root.add_child(view)
		await process_frame
		for index in scenes.size():
			view._show_scene(index)
			await process_frame
			untranslated(view, seen)
		if scenes == EndingView.SCENES:
			view._start_roll()
			await process_frame
			untranslated(view, seen)
			view._thank()
			await process_frame
			untranslated(view, seen)
		view.queue_free()
		await process_frame
	report("the prologue and the ending", seen)
	pseudo(false)

	print("Translation tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
