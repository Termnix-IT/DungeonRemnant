extends SceneTree

# The upgrades page's star chart drawn for real, state by state: the chart
# as it opens on the lantern (at 1600x900, 1280x720 and 1920x1080), then at
# 1600x900 a star the echo can light, the moment it is lit, one the echo
# falls short of, one that waits on another, another constellation, a star
# with all its ranks held, a new player's chart, and a star in English.
# Images go to .godot/upgrade_<state>_<width>.png. Look at them: whether
# what can be bought stands out, whether the names read without running
# into the stars, whether the card's words fit, and any cut text. Needs a
# rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/upgrade-capture.log --script res://tests/capture_upgrade.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]
const RANKS := {
	"echo_lantern": 1, "sturdy_body": 2, "firm_guard": 1, "double_dash": 1, "learn_thunder_flash": 1,
	"parting_blessing": 1, "quick_study": 1, "learn_echo_burst": 1,
}
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
	main.show_opening = false
	main.saving_enabled = false
	main.meta.echo = 400
	main.meta.ranks = RANKS.duplicate()
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	var chart: MetaUpgradePage = hub.upgrade_page
	for size in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		await create_timer(0.3).timeout
		hub.show_page("upgrade")
		await create_timer(UIMotion.WINDOW_TIME + 0.7).timeout
		await _grab("upgrade_open_%d" % size.x)
	DisplayServer.window_set_size(SIZES[0])
	root.size = SIZES[0]
	hub.show_page("upgrade")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	chart.choose(&"sturdy_body")
	UIMotion.of(chart.buy_button).stand(true)
	await create_timer(0.6).timeout
	await _grab("upgrade_buyable_1600")
	UIMotion.of(chart.buy_button).stand(false)
	main.buy_upgrade(&"sturdy_body")
	await create_timer(0.22).timeout
	await _grab("upgrade_moment_1600")
	await create_timer(1.2).timeout
	await _grab("upgrade_full_1600")
	main.meta.echo = 400
	hub.refresh(main.meta)
	chart.choose(&"learn_blaze_ring")
	await create_timer(0.6).timeout
	await _grab("upgrade_short_1600")
	chart.choose(&"last_stand")
	await create_timer(0.6).timeout
	await _grab("upgrade_locked_1600")
	chart.choose(&"rising_heal")
	await create_timer(0.6).timeout
	await _grab("upgrade_growth_1600")
	chart.choose(&"special_mastery")
	await create_timer(0.6).timeout
	await _grab("upgrade_special_1600")
	main.meta.ranks = {"echo_lantern": 1}
	main.meta.echo = 0
	hub.refresh(main.meta)
	chart.return_to_root()
	await create_timer(0.6).timeout
	await _grab("upgrade_new_1600")
	main.meta.echo = 400
	main.meta.ranks = RANKS.duplicate()
	TranslationServer.set_locale("en")
	hub.show_page("home")
	hub.refresh(main.meta)
	hub.show_page("upgrade")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	chart.choose(&"rising_burst")
	await create_timer(0.6).timeout
	await _grab("upgrade_english_1600")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the upgrades: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
