extends SceneTree

# The status page drawn for real, state by state: the build as it opens (at
# 1600x900, 1280x720 and 1920x1080), then at 1600x900 the focus in a slot's
# list on a skill set in the other slot (both slots telling the swap), on a
# skill not learned, on the row that clears the slot, the attack slot's
# weapons, the sealed special slot, the moment after an equip mid-way, and
# her figures in full. Images go to .godot/status_<state>_<width>.png. Look
# at them: what leads the eye, which slot is being changed, what each row's
# state is, and any cut text. Needs a rendering display driver:
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
		status.slot_buttons[1].grab_focus()
		await create_timer(UIMotion.WINDOW_TIME + 0.5).timeout
		await _grab("status_build_%d" % size.x)
	DisplayServer.window_set_size(SIZES[0])
	root.size = SIZES[0]
	hub.show_page("status")
	await create_timer(UIMotion.WINDOW_TIME + 0.4).timeout
	# In the first skill slot's list, on the skill the other slot holds. (The
	# pointer may be resting on the window: choose the slot outright.)
	status.slot_buttons[1].grab_focus()
	status.choices[status.choice_ids.find(&"thunder_flash")].grab_focus()
	await create_timer(0.5).timeout
	await _grab("status_swap_1600")
	status.choices[status.choice_ids.find(&"swallow_cut")].grab_focus()
	await create_timer(0.5).timeout
	await _grab("status_replace_1600")
	status.choices[status.choice_ids.find(&"blaze_ring")].grab_focus()
	await create_timer(0.5).timeout
	await _grab("status_unknown_1600")
	status.choices[0].grab_focus()
	await create_timer(0.5).timeout
	await _grab("status_clear_1600")
	# The moment after an equip, the ring part of the way round both slots.
	status.slot_buttons[1].grab_focus()
	status.choices[status.choice_ids.find(&"thunder_flash")].grab_focus()
	await create_timer(0.3).timeout
	status._equip(&"thunder_flash")
	await create_timer(0.22).timeout
	await _grab("status_moment_1600")
	await create_timer(0.8).timeout
	status.slot_buttons[0].grab_focus()
	await create_timer(0.5).timeout
	await _grab("status_weapon_1600")
	status.slot_buttons[3].grab_focus()
	await create_timer(0.5).timeout
	await _grab("status_sealed_1600")
	main.meta.loadout = [&"slam", &""] as Array[StringName]
	hub.refresh(main.meta)
	status.slot_buttons[2].grab_focus()
	await create_timer(0.5).timeout
	await _grab("status_empty_1600")
	status.toggle_details()
	await create_timer(0.5).timeout
	await _grab("status_figures_1600")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the status: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
