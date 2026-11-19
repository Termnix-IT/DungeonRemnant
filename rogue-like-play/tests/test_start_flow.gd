extends SceneTree

# The way from starting the game to the three gates: the game's opening
# over the hall (its lamps out of the dark, the logo, any key), the lobby's
# things held back and brought in, the view going up to the hall's gate for
# the departure and back, the departure's living painting and its views,
# and setting out (the painting gone into, the chapter's name in the dark,
# the dark opening on the hall of gates, which opens at that moment).
# The rules under it are untouched: what is saved, which chapters are open
# and the run that starts are checked by test_hub and test_run_cycle.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func settle(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame


func key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func start(opening: bool) -> Node:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.show_opening = opening
	main.saving_enabled = false
	main.run_seed = 11
	main.meta.runs = 2
	main.meta.chapter_clears[&"ash_corridor"] = 1
	root.add_child(main)
	await process_frame
	return main


func run_tests() -> void:
	# --- The opening ---
	var main: Node = await start(true)
	var hub = main.get_node("Hub")
	var hall: HubHall = hub.hall
	var lobby: HubLobby = hub.home_page
	var opening: HubOpening = hub.opening
	check(main.show_opening and opening != null and opening.playing and hub.opening_up(), "Starting the game plays its opening over the hall")
	check(is_zero_approx(hall.ambient) and is_zero_approx(hall.gate_lit) and range(HubHall.LAMPS.size()).all(func(index: int) -> bool: return is_zero_approx(hall.lamp(index))), "It begins in the dark: no lamp lit, the gate's light out")
	check(hall.zoom > HubOpening.TITLE_ZOOM and hall.eye.distance_to(HubOpening.START_VIEW) < 0.05, "The camera begins close on the hall's gate")
	check(hub.page == "home" and lobby.visible and lobby.menu.position.x < -HubLobby.PILLAR_WIDTH and is_zero_approx(lobby.hero.modulate.a) and is_zero_approx(lobby.panel.modulate.a) and is_zero_approx(hub._frame.modulate.a), "The lobby is there underneath, its things held back out of sight")
	check(opening.byname.text == "残響の迷宮" and is_zero_approx(opening.byname.modulate.a), "The game's name in the player's language waits its turn under the logo")
	# The key that started the game does not answer it.
	root.push_input(key(KEY_ENTER))
	await process_frame
	check(opening.playing and main.active_run == null and hub.page == "home", "The very first moment is deaf, so the key that started the game does not skip it")
	root.push_input(key(KEY_ENTER, false))
	# Keys do not reach the lobby under it.
	await settle(HubOpening.DEAF)
	root.push_input(key(KEY_ESCAPE))
	await process_frame
	check(not hub.quit_prompt.visible, "Nothing under the opening answers a key")
	# It was answered by Esc all the same: any key is the answer.
	check(not opening.playing, "Any key answers the opening, even while the hall is still coming out of the dark")
	main.free()
	await process_frame

	main = await start(true)
	hub = main.get_node("Hub")
	hall = hub.hall
	lobby = hub.home_page
	opening = hub.opening
	# Left alone it plays through: the gate, the lamps one after another, the hall, the logo, the prompt.
	await settle(HubOpening.LAMPS_AT + HubOpening.LAMP_STEP * 2.0 + HubOpening.LAMP_TIME)
	check(hall.gate_lit > 0.3 and hall.lamp(0) > 0.9 and hall.lamp(HubHall.LAMPS.size() - 1) < 0.1 and hall.ambient < 0.5, "The gate's light comes first, and the lamps kindle one after another from the gate outward")
	await settle(HubOpening.HALL_AT + HubOpening.HALL_TIME - opening.time + 0.1)
	check(opening.playing and is_equal_approx(hall.ambient, 1.0) and hall.lamp(HubHall.LAMPS.size() - 1) > 0.9 and opening.byname.modulate.a > 0.9, "Then the hall stands whole behind the logo and the game's name")
	check(hall.zoom < HubOpening.START_ZOOM and hall.zoom >= HubOpening.TITLE_ZOOM - 0.001 and main.active_run == null and HubOpening.AUTO_AT > HubOpening.HALL_AT + HubOpening.HALL_TIME + 1.0, "The camera has drawn back from the gate, and the logo is given a moment to stand")
	var began := [0]
	opening.begun.connect(func(): began[0] += 1)
	root.push_input(key(KEY_SPACE))
	await process_frame
	check(began[0] == 1 and not opening.playing and not hub.opening_up() and lobby.buttons[lobby.selected].has_focus(), "A key answers it: the lobby takes the focus at once")
	root.push_input(key(KEY_SPACE, false))
	root.push_input(key(KEY_DOWN))
	await process_frame
	check(lobby.selected_id() == &"upgrade", "The lobby answers keys while its things are still coming in")
	await settle(maxf(HubLobby.HERO_IN, HubOpening.LOBBY_TIME + 0.25) + HubLobby.PANEL_WAIT + HubLobby.PANEL_IN)
	check(is_zero_approx(lobby.menu.position.x) and is_equal_approx(lobby.hero.modulate.a, 1.0) and is_equal_approx(lobby.panel.modulate.a, 1.0) and hub._frame.modulate.a > 0.99, "The pier, the heroine, the plate and the keys have come to their places")
	check(is_equal_approx(hall.zoom, 1.0) and hall.eye.is_equal_approx(Vector2(0.5, 0.5)) and is_equal_approx(hall.ambient, 1.0), "The camera rests on the lobby's view of the hall")
	check(not is_instance_valid(opening) or opening.is_queued_for_deletion() or not opening.playing, "The opening is gone and does not play again in the sitting")
	# Left alone it asks for nothing: it goes on to the lobby by itself.
	hub.play_opening()
	var alone: HubOpening = hub.opening
	check(alone.playing and lobby.menu.position.x < 0.0, "Asked for again it would play (Main asks once)")
	alone.time = HubOpening.AUTO_AT - 0.05
	await settle(0.2)
	check(not alone.playing and lobby.buttons[lobby.selected].has_focus(), "Left alone, the opening goes on to the lobby by itself")
	await settle(0.1)

	# --- The lobby's menu in the light ---
	lobby.buttons[0].grab_focus()
	await settle(HubHall.FOCUS_TIME + 0.1)
	check(lobby.selected_id() == &"departure" and is_equal_approx(hall.gate_power, HubHall.GATE_CHOSEN) and is_zero_approx(hall.focus_power), "The departure's thing in the hall is the gate: it shines harder while that entry is chosen")
	lobby.buttons[1].grab_focus()
	await settle(HubHall.FOCUS_TIME * 2.0 + 0.1)
	check(hall.focus_id == &"upgrade" and is_equal_approx(hall.focus_power, 1.0) and is_equal_approx(hall.gate_power, HubHall.GATE_REST), "Another entry lights its own thing and lets the gate rest")
	check(lobby._icons.size() == HubLobby.ENTRIES.size() and lobby._icons[1].texture == HubLobby.ICONS[&"upgrade"] and lobby._icons[1].scale.x > lobby._icons[0].scale.x and lobby._icons[1].modulate.r > lobby._icons[0].modulate.r, "Each entry has its medallion; the chosen one stands larger and brighter")
	check(HubLobby.ENTRIES.all(func(entry: Array) -> bool: return HubHall.FOCUS.has(entry[0]) or entry[0] == HubHall.GATE_ENTRY), "Every entry of the menu has a thing in the hall")
	var rows: Array = range(HubLobby.ENTRIES.size()).map(func(index: int) -> Rect2: return lobby._row_rect(index))
	var panel := Rect2(HubLobby.PILLAR_PANEL.position.x * HubLobby.PILLAR_WIDTH, HubLobby.PILLAR_PANEL.position.y * HubLobby.PILLAR_WIDTH * HubLobby.PILLAR.get_size().y / HubLobby.PILLAR.get_size().x, HubLobby.PILLAR_PANEL.size.x * HubLobby.PILLAR_WIDTH, HubLobby.PILLAR_PANEL.size.y * HubLobby.PILLAR_WIDTH * HubLobby.PILLAR.get_size().y / HubLobby.PILLAR.get_size().x)
	check(rows.all(func(row: Rect2) -> bool: return panel.grow(2.0).encloses(row)), "The menu's rows stand inside the pier's panel")

	# --- Up to the gate, and back ---
	lobby.buttons[0].grab_focus()
	await settle(0.1)
	hub.show_page("sortie")
	var sortie: HubSortie = hub.sortie_page
	check(lobby.visible and lobby.leaving and sortie.visible and sortie.has_focus(), "To the departure the lobby leaves by itself, and the departure has the focus at once")
	await settle(hub.GATE_TIME + 0.2)
	check(not lobby.visible and not lobby.leaving and is_equal_approx(hall.zoom, hub.GATE_ZOOM) and hall.eye.is_equal_approx(hub.GATE_VIEW) and is_equal_approx(hall.gate_power, hub.GATE_SHINE) and is_equal_approx(sortie.modulate.a, 1.0), "The view has gone up to the hall's gate, which shines, and the chapter's painting has come through its light")
	hub.go_back()
	await process_frame
	check(hub.page == "home" and lobby.visible and not lobby.leaving and lobby.buttons[0].has_focus() and lobby.menu.position.x < 0.0, "Back from the departure the lobby's things come in again")
	await settle(hub.HOME_TIME + 0.2)
	check(is_equal_approx(hall.zoom, 1.0) and is_zero_approx(lobby.menu.position.x) and is_equal_approx(lobby.hero.modulate.a, 1.0), "The view has drawn back from the gate to the lobby")
	# Gone to and come back from at once: nothing is left half way.
	hub.show_page("sortie")
	await process_frame
	hub.go_back()
	await settle(hub.HOME_TIME + 0.3)
	check(hub.page == "home" and lobby.visible and not lobby.leaving and is_zero_approx(lobby.menu.position.x) and is_equal_approx(lobby.hero.modulate.a, 1.0) and is_equal_approx(lobby.panel.modulate.a, 1.0) and is_equal_approx(hall.zoom, 1.0), "Turning back at once leaves the lobby whole")
	hub.show_page("upgrade")
	await settle(UIMotion.WINDOW_TIME + 0.1)
	check(not lobby.visible and is_equal_approx(hall.zoom, 1.0), "The other pages are opened as before, the view where it was")
	hub.go_back()
	await settle(UIMotion.WINDOW_TIME + 0.1)
	check(lobby.visible and is_zero_approx(lobby.menu.position.x) and is_equal_approx(lobby.hero.modulate.a, 1.0), "And the lobby returns from them whole")

	# --- The departure's painting and views ---
	hub.show_page("sortie")
	await settle(hub.GATE_TIME + 0.2)
	check(sortie._views.size() == Chapters.ALL.size() and sortie._seals.size() == Chapters.ALL.size(), "Every chapter has its window, and a seal for it")
	var chosen := sortie.selected
	check(sortie._view_share[chosen] > 0.9 and sortie._views[chosen].scale.x > sortie._views[(chosen + 1) % 4].scale.x and not sortie._seals[chosen].visible and sortie._seals[3].visible, "The view turned to stands larger; a chapter not open is under its seal")
	for chapter in Chapters.ALL:
		var place: Dictionary = HubSortie.PLACES.get(chapter.id, {})
		var way: Vector2 = place.get(&"way", Vector2(-1.0, -1.0))
		check(not place.is_empty() and Rect2(0.0, 0.0, 1.0, 1.0).has_point(way) and (place.fires as Array).size() <= HubSortie.FIRES, "%s's painting has its way in and its fires marked" % chapter.id)
	var look := sortie._vista.material as ShaderMaterial
	check(look.get_shader_parameter(&"place") == sortie.chosen().illustration and is_zero_approx(look.get_shader_parameter(&"still")), "The vista shows the chosen chapter's painting, alive")
	var outlook: Dictionary = hub.outlook()
	var window: Vector4 = outlook[&"window"]
	check(outlook[&"chapter"] == sortie.chosen() and window.z > 0.5 and window.z <= 1.0 and window.x >= 0.0 and window.x + window.z <= 1.001 and window.y >= 0.0 and window.y + window.w <= 1.001, "The departure tells what part of the painting the screen shows")
	check(Rect2(window.x, window.y, window.z, window.w).has_point(outlook[&"way"]), "The painting's way in is on the screen")
	sortie.choose(3)
	await settle(HubSortie.TURN_TIME + 0.2)
	check(is_equal_approx(look.get_shader_parameter(&"still"), 1.0) and not sortie._motes.emitting and sortie.action_button.disabled, "A sealed chapter's painting is dark and still, and cannot be set out for")
	var crest := sortie.action_button as CrestButton
	check(crest != null and crest.medal == HubSortie.MEDAL, "The set-out button carries the departure's medallion")
	sortie.choose(chosen)
	await settle(HubSortie.TURN_TIME + 0.2)
	check(hub.outlook().is_empty() == false and hub.page == "sortie", "Turned back, it can be set out for again")

	# --- Setting out ---
	var transition: SceneTransition = main.transition
	var chapter: ChapterData = sortie.chosen()
	sortie.set_out()
	# Untyped: a RunDirector-typed local here leaves list errors (p_elem) at quit.
	var run = main.active_run
	check(run != null and run.chapter == chapter and not hub.visible, "Setting out starts the run at once, under the cover")
	check(transition.covering and transition.departing and transition.stage.visible and transition.title.text == Chapters.title(chapter) and transition.kicker.text == Chapters.short_name(chapter), "The cover is the chapter's painting, gone into")
	var stage := transition.stage.material as ShaderMaterial
	check(stage.get_shader_parameter(&"place") == chapter.illustration and (stage.get_shader_parameter(&"window") as Vector4).distance_to(window) < 0.03 and (stage.get_shader_parameter(&"way") as Vector2).is_equal_approx(outlook[&"way"]), "It begins on the painting as the departure showed it, and goes toward its way in")
	var gates: RouteGates = run.map_view.page
	var opened_at: float = gates._kicks[&"open"]
	root.push_input(key(KEY_RIGHT))
	root.push_input(key(KEY_RIGHT, false))
	await process_frame
	check(gates.cursor == 0 and not gates.asked, "Keys do not reach the gates under the cover")
	await settle(SceneTransition.PUSH_TIME * 0.5)
	check(float(stage.get_shader_parameter(&"push")) > 0.05 and float(stage.get_shader_parameter(&"push")) < 0.6 and transition.heading.modulate.a < 0.01, "Half way in, the view has gone in toward the way in and no name shows yet")
	await settle(SceneTransition.PUSH_TIME * 0.5 + SceneTransition.NAME_TIME * 0.5)
	check(is_equal_approx(float(stage.get_shader_parameter(&"close")), 1.0) and transition.heading.visible and transition.heading.modulate.a > 0.9 and transition.covering, "The dark has closed on the way's light, and the chapter's name stands in it")
	await settle(SceneTransition.NAME_TIME * 0.5 + SceneTransition.OPEN_TIME * 0.5)
	check(transition._arrived and float(gates._kicks[&"open"]) > opened_at and transition.veil.modulate.a < 0.9 and transition.veil.modulate.a > 0.05, "As the dark opens the hall of gates opens again, now seen")
	await settle(SceneTransition.OPEN_TIME * 0.5 + 0.2)
	check(not transition.covering and not transition.departing and not transition.visible and gates.has_focus() and run.map_view.visible, "The cover is gone, and the gates have the focus")
	await settle(RouteGates.RISE_TIME + 0.4)
	root.push_input(key(KEY_RIGHT))
	root.push_input(key(KEY_RIGHT, false))
	await process_frame
	check(gates.cursor == 1, "The gates answer keys once the cover is gone")
	check(run.run.route != null and run.run.layer == 0 and main.meta.runs == 2, "The run under it is the one that was asked for, nothing of it spent")
	main.free()
	await process_frame

	# --- Hurried ---
	main = await start(false)
	hub = main.get_node("Hub")
	check(hub.opening == null and is_equal_approx(hub.home_page.hero.modulate.a, 1.0) and is_zero_approx(hub.home_page.menu.position.x) and is_equal_approx(hub.hall.ambient, 1.0), "Without its opening the game starts on the lobby, whole and lit")
	hub.show_page("sortie")
	await settle(hub.GATE_TIME + 0.2)
	hub.sortie_page.set_out()
	transition = main.transition
	await process_frame
	root.push_input(key(KEY_ENTER))
	root.push_input(key(KEY_ENTER, false))
	await process_frame
	check(is_equal_approx(transition._speed, SceneTransition.HURRY) and transition.covering, "Enter hurries setting out")
	await settle((SceneTransition.PUSH_TIME + SceneTransition.NAME_TIME + SceneTransition.OPEN_TIME) / SceneTransition.HURRY + 0.25)
	check(not transition.covering and main.active_run != null and main.active_run.map_view.page.has_focus() and not main.active_run.map_view.page.asked, "Hurried, it is over in a quarter of the time, and the key asked nothing of the gates")
	main.free()
	await process_frame
	# Setting out from anywhere else (no painting on the screen) still covers and opens.
	main = await start(false)
	check((main.get_node("Hub").outlook() as Dictionary).is_empty(), "Away from the departure there is no painting on the screen to set out from")
	main.start_run()
	check(main.active_run != null and main.transition.departing and main.transition.covering, "Setting out from there takes the chapter's painting whole")
	main.transition._depart(SceneTransition.PUSH_TIME + SceneTransition.NAME_TIME + SceneTransition.OPEN_TIME + 0.1)
	check(not main.transition.covering, "And opens on the gates the same")
	main.free()
	await process_frame
	print("Start flow tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
