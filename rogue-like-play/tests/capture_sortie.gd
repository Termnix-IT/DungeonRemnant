extends SceneTree

# The departure's vista drawn for real, state by state: as it opens on the
# frontier (at 1600x900, 1280x720 and 1920x1080), then at 1600x900 a chapter
# cleared, the turn from one place to the next part of the way through, a
# sealed chapter, the moment of setting out, a new player's departure, the
# difficulty steps past the ending (one chosen, then the highest open), and
# a chapter in English. Images go to .godot/sortie_<state>_<width>.png.
# Look at them: whether the name and the words at the foot read on every
# painting, whether the chosen view stands out, whether the step and the
# button keep clear of each other, and any cut text. Needs a rendering
# display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/sortie-capture.log --script res://tests/capture_sortie.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]
var shots := {}
var main: Node
var hub


func _initialize() -> void:
	call_deferred("capture")


# A game part of the way through: the first chapter cleared, the second entered.
func _midway() -> void:
	var all := Chapters.ALL
	main.meta.chapter_clears = {all[0].id: 2}
	main.meta.chapter_best = {all[0].id: all[0].layers + 1, all[1].id: 3}
	main.meta.chapter_steps = {}
	main.meta.met = {}
	for foe in Chapters.foes(all[0]):
		main.meta.met[foe.id] = true
	var second := Chapters.foes(all[1])
	for index in mini(4, second.size()):
		main.meta.met[second[index].id] = true
	var carried: Array[StringName] = [&"slam", &"thunder_flash"]
	main.meta.loadout = carried
	main.meta.special = &"echo_burst"
	hub.chapter = all[1]
	hub.step = 0
	hub.refresh(main.meta)


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	main = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.saving_enabled = false
	main.meta.echo = 240
	root.add_child(main)
	hub = main.get_node("Hub")
	_midway()
	var vista: HubSortie = hub.sortie_page
	for size in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		await create_timer(0.3).timeout
		hub.show_page("sortie")
		await create_timer(UIMotion.WINDOW_TIME + 0.7).timeout
		await _grab("sortie_open_%d" % size.x)
	DisplayServer.window_set_size(SIZES[0])
	root.size = SIZES[0]
	hub.show_page("sortie")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	vista.choose(0)
	await create_timer(0.08).timeout
	await _grab("sortie_turning_1600")
	await create_timer(0.6).timeout
	await _grab("sortie_cleared_1600")
	vista.choose(2)
	await create_timer(0.6).timeout
	await _grab("sortie_sealed_1600")
	# The moment of setting out, without a run starting under it.
	vista.choose(1)
	await create_timer(0.6).timeout
	vista._departed = 1
	vista._kick(&"depart")
	await create_timer(0.25).timeout
	await _grab("sortie_depart_1600")
	# A new player's departure.
	main.meta.chapter_clears = {}
	main.meta.chapter_best = {}
	main.meta.met = {}
	main.meta.loadout = MetaProgress.DEFAULT_LOADOUT.duplicate()
	main.meta.special = &""
	hub.chapter = Chapters.ALL[0]
	hub.refresh(main.meta)
	hub.show_page("sortie")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	await _grab("sortie_new_1600")
	# Past the ending: every chapter open and four steps.
	_ended()
	hub.show_page("sortie")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	vista.choose_step(2)
	await create_timer(0.6).timeout
	await _grab("sortie_steps_1600")
	vista.choose_step(4)
	UIMotion.of(vista.action_button).stand(true)
	await create_timer(0.6).timeout
	await _grab("sortie_limit_1600")
	UIMotion.of(vista.action_button).stand(false)
	TranslationServer.set_locale("en")
	hub.show_page("home")
	hub.refresh(main.meta)
	hub.show_page("sortie")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	vista.choose(2)
	await create_timer(0.6).timeout
	await _grab("sortie_english_1600")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the departure: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _ended() -> void:
	var all := Chapters.ALL
	for chapter in all:
		main.meta.chapter_clears[chapter.id] = 2
		main.meta.chapter_best[chapter.id] = chapter.layers + 1
		for foe in Chapters.foes(chapter):
			main.meta.met[foe.id] = true
	main.meta.chapter_clears[all[0].id] = 6
	main.meta.chapter_steps = {all[0].id: 2, all.back().id: 3}
	var carried: Array[StringName] = [&"slam", &"thunder_flash"]
	main.meta.loadout = carried
	main.meta.special = &"echo_burst"
	hub.chapter = all.back()
	hub.refresh(main.meta)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
