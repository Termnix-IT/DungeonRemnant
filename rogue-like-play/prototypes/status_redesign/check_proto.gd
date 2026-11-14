extends SceneTree

# Drives the three prototypes through their main operations, headless, to
# check that each one really equips, swaps, clears and refuses by the game's
# own rules, through the same key and pointer paths a player uses:
#   godot --headless --path . --script res://prototypes/status_redesign/check_proto.gd

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func run() -> void:
	var main: Control = load("res://prototypes/status_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var build: ProtoBuild = main.build
	var saves_before := DirAccess.get_files_at("user://")
	# A, the armoury: take a free skill from the rack and mount it on E.
	main.show_screen(0)
	var armoury: ProtoArmoury = main.screens[0]
	armoury.pose(&"initial")
	await press(&"ui_right")
	await press(&"ui_right")
	check(armoury._focused().id == &"swallow_cut", "A: the arrows reach the third skill on the rack")
	await press(&"ui_accept")
	check(armoury.carried == &"swallow_cut" and armoury.target == ProtoBuild.SKILL_1, "A: Enter takes it in hand, aimed at the first skill mount")
	await press(&"ui_right")
	check(armoury.target == ProtoBuild.SKILL_2, "A: right aims at the other mount")
	await press(&"ui_accept")
	check(build.content(ProtoBuild.SKILL_2) == &"swallow_cut" and build.content(ProtoBuild.SKILL_1) == &"slam", "A: Enter mounts it there and leaves the other mount alone")
	check(armoury.carried.is_empty() and armoury.area == ProtoArmoury.Area.BENCH, "A: the hand is empty and the cursor rests on the mount")
	# Pick the mounted skill up and swap it with the other mount's.
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(build.content(ProtoBuild.SKILL_1) == &"swallow_cut" and build.content(ProtoBuild.SKILL_2) == &"slam", "A: a mounted skill taken to the other mount swaps the two")
	# A weapon goes straight to its one mount; one not learned is refused.
	armoury.pose(&"initial")
	await press(&"ui_up")
	await press(&"ui_right")
	await press(&"ui_accept")
	check(build.content(ProtoBuild.ATTACK) == &"spear", "A: a weapon goes straight to the attack mount")
	await press(&"ui_right")
	await press(&"ui_accept")
	check(build.content(ProtoBuild.ATTACK) == &"spear" and armoury.since(&"refuse") < 1.0, "A: a weapon not learned is refused")
	armoury._click([&"mount", ProtoBuild.SKILL_2])
	armoury._click([&"clear", ProtoBuild.SKILL_2])
	check(build.content(ProtoBuild.SKILL_2) == &"", "A: the pointer clears a mount")
	armoury._key(&"details")
	check(armoury.sheet_open, "A: R opens the inspection sheet")
	armoury._key(&"cancel")
	check(not armoury.sheet_open, "A: Esc closes it")
	# B, the grimoire: turn to the second skill's chapter and seal an entry.
	main.show_screen(1)
	var book: ProtoGrimoire = main.screens[1]
	book.pose(&"initial")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	check(book.chapter == ProtoBuild.SKILL_2, "B: E turns to the next chapter")
	book.row = 3
	await press(&"ui_accept")
	check(build.content(ProtoBuild.SKILL_2) == &"swallow_cut" and build.content(ProtoBuild.SKILL_1) == &"", "B: sealing a skill held in the other chapter moves it here")
	book.row = 1
	await press(&"ui_down")
	await press(&"ui_accept")
	check(build.content(ProtoBuild.SKILL_2) == &"thunder_flash", "B: down and Enter seal the next entry")
	book.row = 5
	await press(&"ui_accept")
	check(build.content(ProtoBuild.SKILL_2) == &"thunder_flash", "B: an entry not learned cannot be sealed")
	book._click([&"row", 0])
	book._click([&"row", 0])
	check(build.content(ProtoBuild.SKILL_2) == &"", "B: the pointer on 外す empties the chapter")
	book._click([&"tab", ProtoGrimoire.STATS])
	check(book.chapter == ProtoGrimoire.STATS, "B: a tab opens her figures")
	book._key(&"details")
	check(book.chapter == ProtoBuild.SKILL_2, "B: R returns to the chapter left")
	# C, the altar: point at a socket, wake it, turn the ring, set a stone.
	main.show_screen(2)
	var altar: ProtoAltar = main.screens[2]
	altar.pose(&"initial")
	await press(&"ui_right")
	check(altar.socket == ProtoBuild.SKILL_2, "C: right points at the right-hand socket")
	await press(&"ui_accept")
	check(altar.awake, "C: Enter wakes the socket")
	altar.index = 0
	await press(&"ui_right")
	await press(&"ui_accept")
	check(build.content(ProtoBuild.SKILL_2) == &"thunder_flash" and not altar.awake, "C: turning the ring and Enter set the stone and rest the socket")
	await press(&"ui_down")
	check(altar.socket == ProtoBuild.SPECIAL, "C: down points at the special's socket")
	await press(&"ui_accept")
	await press(&"ui_accept")
	check(build.content(ProtoBuild.SPECIAL) == &"echo_burst", "C: the learned special is set")
	altar._key(&"clear")
	check(build.content(ProtoBuild.SPECIAL) == &"", "C: X empties the socket")
	altar._click([&"socket", ProtoBuild.ATTACK])
	altar._click([&"socket", ProtoBuild.ATTACK])
	altar._click([&"stone", 0])
	altar._click([&"stone", 0])
	check(build.content(ProtoBuild.ATTACK) == &"sword", "C: the pointer wakes a socket and sets a stone")
	altar._key(&"details")
	check(altar.tablet_open, "C: R raises the tablet")
	check(DirAccess.get_files_at("user://") == saves_before, "No prototype writes to the save folder")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
