extends SceneTree

# The bestiary's folio drawn for real, state by state: the first plate as it
# opens (at 1600x900, 1280x720 and 1920x1080), then at 1600x900 a foe met
# with its notes, a plate mid-turn, a foe not met (a flat shade, nothing
# told), the elites, a boss with its epithet, the tray ordered by HP, a
# plate far along a long tray, and a plate in English. Images go to
# .godot/codex_<state>_<width>.png. Look at them: whether the foe leads the
# eye, whether the notes read, that a foe not met shows no painted detail,
# and any cut text. Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/codex-capture.log --script res://tests/capture_codex.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]
const MET: Array[StringName] = [
	&"wandering_sentinel", &"dashing_rat", &"mud_swell", &"crystal_turret", &"brood_nest", &"moss_sentinel", &"gale_rat",
	&"skeleton", &"wisp", &"blood_rat", &"raging_charger", &"gale_warden", &"ruin_king", &"gale_wolf_king",
]
var shots := {}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.saving_enabled = false
	for id in MET:
		main.meta.met[id] = true
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	var codex: HubCodex = hub.codex_page
	for size in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		await create_timer(0.3).timeout
		hub.show_page("codex")
		await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
		await _grab("codex_open_%d" % size.x)
	DisplayServer.window_set_size(SIZES[0])
	root.size = SIZES[0]
	hub.show_page("codex")
	await create_timer(UIMotion.WINDOW_TIME + 0.5).timeout
	codex.go_to(5)
	await create_timer(0.6).timeout
	await _grab("codex_met_1600")
	codex.go_to(6)
	await create_timer(0.08).timeout
	await _grab("codex_turning_1600")
	await create_timer(0.5).timeout
	codex.go_to(7)
	await create_timer(0.6).timeout
	await _grab("codex_unmet_1600")
	codex.turn_kind(2)
	await create_timer(0.6).timeout
	await _grab("codex_elites_1600")
	codex.turn_kind(3)
	codex.go_to(1)
	await create_timer(0.6).timeout
	await _grab("codex_boss_1600")
	codex.turn_kind(0)
	codex.cycle_sort()
	codex.go_to(0)
	await create_timer(0.6).timeout
	await _grab("codex_sorted_1600")
	codex.cycle_sort()
	codex.cycle_sort()
	codex.cycle_sort()
	codex.go_to(28)
	await create_timer(0.6).timeout
	await _grab("codex_far_1600")
	TranslationServer.set_locale("en")
	hub.show_page("home")
	hub.refresh(main.meta)
	hub.show_page("codex")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	codex.go_to(30)
	await create_timer(0.6).timeout
	await _grab("codex_english_1600")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the bestiary: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
