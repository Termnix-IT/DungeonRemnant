extends SceneTree

# The status page's book drawn for real, state by state: the first skill's
# chapter as it opens (at 1600x900, 1280x720 and 1920x1080), then at
# 1600x900 the cursor on a skill set in the other slot (the ledger comparing
# the two, the foot saying they change places), on a free skill, on one not
# learned, on the entry that empties the slot, the seal coming down just
# after an equip, the attack's chapter, the sealed special's chapter, an
# empty slot's chapter, her figures in full, and the first chapter in
# English. Images go to .godot/status_<state>_<width>.png. Look at them:
# what leads the eye, what each entry's state is, whether the ledger reads,
# and any cut text. Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/status-capture.log --script res://tests/capture_status.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]
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
	main.meta.echo = 240
	for id: String in ["echo_lantern", "sturdy_body", "double_dash", "learn_thunder_flash", "learn_swallow_cut", "learn_spear"]:
		main.meta.ranks[id] = 1
	main.meta.loadout = [&"slam", &"thunder_flash"] as Array[StringName]
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	var status: HubStatus = hub.status_page
	for size in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		await create_timer(0.3).timeout
		hub.show_page("status")
		await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
		await _grab("status_build_%d" % size.x)
	DisplayServer.window_set_size(SIZES[0])
	root.size = SIZES[0]
	hub.show_page("status")
	await create_timer(UIMotion.WINDOW_TIME + 0.5).timeout
	for pair: Array in [[&"thunder_flash", "swap"], [&"swallow_cut", "replace"], [&"blaze_ring", "unknown"], [HubStatus.CLEAR_ID, "clear"]]:
		status.move_cursor(status.entry_ids().find(pair[0]))
		await create_timer(0.4).timeout
		await _grab("status_%s_1600" % pair[1])
	# The seal coming down: just after an equip was saved.
	status.move_cursor(status.entry_ids().find(&"swallow_cut"))
	await create_timer(0.3).timeout
	status.seal()
	await create_timer(0.12).timeout
	await _grab("status_moment_1600")
	await create_timer(0.9).timeout
	await _grab("status_sealed_skill_1600")
	status.turn_to(HubStatus.ATTACK_SLOT)
	await create_timer(0.6).timeout
	status.move_cursor(1)
	await create_timer(0.4).timeout
	await _grab("status_weapon_1600")
	status.turn_to(HubStatus.SPECIAL_SLOT)
	await create_timer(0.6).timeout
	await _grab("status_sealed_1600")
	main.meta.loadout = [&"slam", &""] as Array[StringName]
	hub.refresh(main.meta)
	status.turn_to(2)
	await create_timer(0.6).timeout
	await _grab("status_empty_1600")
	status.toggle_details()
	await create_timer(0.6).timeout
	await _grab("status_figures_1600")
	# In English: the tabs' words run down, turned, and nothing is cut.
	TranslationServer.set_locale("en")
	hub.show_page("home")
	hub.refresh(main.meta)
	hub.show_page("status")
	await create_timer(UIMotion.WINDOW_TIME + 0.6).timeout
	status.move_cursor(status.entry_ids().find(&"thunder_flash"))
	await create_timer(0.4).timeout
	await _grab("status_english_1600")
	status.toggle_details()
	await create_timer(0.6).timeout
	await _grab("status_english_figures_1600")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the status: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
