extends SceneTree

# The way from starting the game to the three gates drawn for real: the
# opening (the gate's light alone, the lamps kindling, the logo being
# written, the logo standing), the lobby coming in and at rest (on the
# departure and on another entry), the view going up to the hall's gate,
# the departure (at rest, turning to another chapter, on a sealed one),
# and setting out (going in, the dark closing, the chapter's name in the
# dark, the dark opening, the hall of gates). All of it at 1600x900; the
# title, the lobby, the departure and the chapter's name also at 1280x720
# and 1920x1080, and in English. Images go to .godot/start_<state>_<width>.png
# (English: start_<state>_en_1600.png). Look at them: the hierarchy, what
# is chosen, the main action, any cut text, and that each frame reads as
# one picture. Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/start-capture.log --script res://tests/capture_start.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]

var main: Node
var hub: Node
var _tag := ""


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	for size in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		_tag = "_%d" % size.x
		await _pass("ja", size == SIZES[0])
	DisplayServer.window_set_size(SIZES[0])
	root.size = SIZES[0]
	_tag = "_en_%d" % SIZES[0].x
	await _pass("en", false)
	quit()


# The game started fresh and played to the gates, grabbed on the way. `whole`
# grabs every state; otherwise only the ones that rest.
func _pass(language: String, whole: bool) -> void:
	TranslationServer.set_locale(language)
	main = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.saving_enabled = false
	main.run_seed = 6
	main.meta.echo = 240
	main.meta.ranks["echo_lantern"] = 1
	main.meta.runs = 3
	main.meta.best_layer = 3
	main.meta.chapter_best[&"ash_corridor"] = 3
	main.meta.chapter_clears[&"ash_corridor"] = 1
	main.meta.met[&"wandering_sentinel"] = true
	main.meta.met[&"dashing_rat"] = true
	root.add_child(main)
	hub = main.get_node("Hub")
	hub.refresh(main.meta)
	var opening: HubOpening = hub.opening
	if whole:
		await _until(opening, 0.6)
		await _grab("opening_gate")
		await _until(opening, 1.3)
		await _grab("opening_lamps")
		await _until(opening, 1.9)
		await _grab("opening_logo")
	await _until(opening, HubOpening.SHEEN_AT + HubOpening.SHEEN_TIME + 0.2)
	await _grab("title")
	opening.begin()
	if whole:
		await _wait(0.25)
		await _grab("enter")
	await _wait(HubLobby.HERO_IN + HubLobby.PANEL_WAIT + HubLobby.PANEL_IN + 0.3)
	await _grab("lobby")
	if whole:
		hub.home_page.buttons[1].grab_focus()
		await _wait(HubHall.FOCUS_TIME * 2.0 + 0.3)
		await _grab("lobby_upgrade")
		hub.home_page.buttons[0].grab_focus()
		await _wait(0.3)
	hub.show_page("sortie")
	if whole:
		await _wait(hub.GATE_TIME * 0.5)
		await _grab("to_gate")
	await _wait(hub.GATE_TIME + 0.5)
	await _grab("sortie")
	if whole:
		hub.sortie_page.choose(hub.sortie_page.selected + 1)
		await _wait(HubSortie.TURN_TIME * 0.45)
		await _grab("sortie_turn")
		await _wait(HubSortie.TURN_TIME + 0.4)
		await _grab("sortie_sealed")
		hub.sortie_page.choose(hub.sortie_page.selected - 1)
		await _wait(HubSortie.TURN_TIME + 0.5)
	hub.sortie_page.set_out()
	var cover: SceneTransition = main.transition
	if whole:
		await _until_cover(cover, SceneTransition.PUSH_TIME * 0.55)
		await _grab("depart_in")
		await _until_cover(cover, SceneTransition.PUSH_TIME * 0.86)
		await _grab("depart_close")
	await _until_cover(cover, SceneTransition.PUSH_TIME + SceneTransition.NAME_TIME * 0.5)
	await _grab("depart_name")
	if whole:
		await _until_cover(cover, SceneTransition.PUSH_TIME + SceneTransition.NAME_TIME + SceneTransition.OPEN_TIME * 0.4)
		await _grab("depart_open")
	await _wait(SceneTransition.OPEN_TIME + RouteGates.RISE_TIME + 0.8)
	await _grab("gates")
	main.free()
	await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


# Waits until the opening's own clock reads `at`.
func _until(opening: HubOpening, at: float) -> void:
	while is_instance_valid(opening) and opening.time < at:
		await process_frame


# Waits until setting out's own clock reads `at`.
func _until_cover(cover: SceneTransition, at: float) -> void:
	while cover.departing and cover._time < at:
		await process_frame


func _grab(state: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/start_%s%s.png" % [state, _tag])
