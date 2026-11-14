extends SceneTree

# Drives the three bestiary prototypes through their main operations,
# headless: choosing a foe, changing the kind, reaching a foe not met, and
# that such a foe gives away no more than the shipped page does.
#   godot --headless --path . --script res://prototypes/codex_redesign/check_proto.gd

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


func tap(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func run() -> void:
	var main: Control = load("res://prototypes/codex_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var codex: ProtoCodex = main.codex
	var files_before := DirAccess.get_files_at("user://")
	# What a foe not met gives away: its kind and shape, nothing else.
	var hidden: FoeData = null
	for foe in FoeCatalog.FOES:
		if not codex.known(foe):
			hidden = foe
			break
	check(codex.name_of(hidden) == ProtoCodex.UNKNOWN_NAME and codex.stats(hidden).is_empty() and codex.epithet(hidden).is_empty(), "A foe not met has no name, figures or epithet")
	check(codex.account(hidden) == [ProtoCodex.UNKNOWN_NOTE, ""], "Its account is the note for a foe not met")
	check(codex.tally(0) == [ProtoCodex.MET.size(), FoeCatalog.FOES.size()], "The tally counts the foes met")
	# A, the ledger.
	main.show_screen(0)
	var ledger: ProtoLedger = main.screens[0]
	ledger.pose(&"initial")
	await press(&"ui_down")
	await press(&"ui_down")
	check(ledger.listed[ledger.row].id == &"mud_swell", "A: down moves the cursor through the table")
	await tap(KEY_E)
	check(ledger.kind == 1 and ledger.listed.all(func(foe: FoeData) -> bool: return FoeCatalog.kind_of(foe) == 1), "A: E turns to the next kind's tab, listing only that kind")
	await tap(KEY_R)
	check(ledger.sort == 1, "A: R sorts by the next figure")
	var seen_hidden := false
	var ordered := true
	var last := INF
	for foe in ledger.listed:
		if not codex.known(foe):
			seen_hidden = true
		else:
			ordered = ordered and not seen_hidden and float(foe.max_hp) <= last
			last = foe.max_hp
	check(ordered, "A: sorted, the foes met run from the strongest down and those not met come after them all")
	ledger._click([&"tab", 3])
	ledger._click([&"row", 1])
	check(ledger.kind == 3 and ledger.sort == 1 and ledger.listed[ledger.row].id == &"ruin_king", "A: the pointer opens a tab and chooses a line, the order kept (the second strongest boss met)")
	# B, the plates.
	main.show_screen(1)
	var plates: ProtoPlates = main.screens[1]
	plates.pose(&"initial")
	await press(&"ui_right")
	await press(&"ui_right")
	check(plates.listed[plates.place].id == &"mud_swell", "B: right turns to the next plate")
	await press(&"ui_left")
	check(plates.listed[plates.place].id == &"dashing_rat", "B: left turns back")
	await tap(KEY_E)
	await tap(KEY_E)
	check(plates.kind == 2 and plates.place == 0, "B: E changes the kind, opening its first plate")
	plates._click([&"ribbon", 0])
	plates._click([&"specimen", 7])
	check(plates.kind == 0 and not codex.known(plates.listed[plates.place]), "B: a ribbon and a specimen in the tray reach a plate not yet drawn")
	# C, the altar.
	main.show_screen(2)
	var altar: ProtoMemory = main.screens[2]
	altar.pose(&"initial")
	await press(&"ui_right")
	check(altar.listed[altar.place].id == &"dashing_rat", "C: right turns the ring to the next memory")
	await tap(KEY_E)
	await tap(KEY_E)
	await tap(KEY_E)
	check(altar.kind == 3, "C: E goes through the kinds to the bosses")
	await tap(KEY_E)
	check(altar.kind == 3, "C: and stops at the last")
	altar._click([&"shard", 2])
	check(not codex.known(altar.listed[altar.place]), "C: the pointer calls up a sealed memory")
	altar._click([&"stone", 1])
	check(altar.kind == 1 and altar.place == 0, "C: a seal stone changes the kind")
	check(DirAccess.get_files_at("user://") == files_before, "No prototype writes to the save folder")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
