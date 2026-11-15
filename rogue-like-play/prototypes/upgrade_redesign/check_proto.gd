extends SceneTree

# Drives the three upgrade prototypes through their main operations,
# headless: reaching an upgrade, buying a rank, and being refused one that
# is full, one the echo falls short of and one that waits on another.
#   godot --headless --path . --script res://prototypes/upgrade_redesign/check_proto.gd

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
	var main: Control = load("res://prototypes/upgrade_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tree: ProtoTree = main.tree
	var saves_before := DirAccess.get_files_at("user://")
	var body := MetaProgress.find(&"sturdy_body")
	var blaze := MetaProgress.find(&"learn_blaze_ring")
	var stand := MetaProgress.find(&"last_stand")
	# The tree keeps the game's own rules.
	check(tree.state(body) == ProtoTree.State.BUY and tree.state(blaze) == ProtoTree.State.SHORT, "The tree tells what the echo can and cannot buy")
	check(tree.state(stand) == ProtoTree.State.LOCKED and tree.state(ProtoTree.root()) == ProtoTree.State.FULL, "The tree tells what waits and what is full")
	var listed := 1
	for branch in ProtoTree.BRANCHES:
		listed += tree.members(branch).size()
	check(listed == MetaProgress.UPGRADES.size(), "Every upgrade is in a branch")
	# A, the forge's ledger.
	var forge: ProtoForge = main.screens[0]
	forge.pose(&"initial")
	check(forge.rows.size() == MetaProgress.UPGRADES.size() and forge.chosen == ProtoTree.root(), "A: opens on every upgrade, the lantern first")
	await press(&"ui_down")
	check(forge.chosen == body, "A: down goes to the next row")
	await press(&"ui_accept")
	check(tree.rank(body) == 3 and tree.meta.echo == ProtoTree.START_ECHO - 280, "A: Enter buys a rank and spends the echo")
	await press(&"ui_accept")
	check(tree.rank(body) == 3 and tree.meta.echo == ProtoTree.START_ECHO - 280 and forge.since(&"refuse") < 1.0, "A: a full upgrade is refused")
	forge.pose(&"initial")
	await press(&"ui_right")
	check(forge.tab == 1 and forge.rows == tree.members(&"body"), "A: right turns to the first branch")
	await tap(KEY_R)
	var all_open := not forge.rows.is_empty()
	for upgrade in forge.rows:
		all_open = all_open and tree.state(upgrade) == ProtoTree.State.BUY
	check(forge.only_open and all_open, "A: R keeps only what the echo can buy")
	forge.choose(stand)
	check(forge.chosen == stand and not forge.only_open, "A: an upgrade out of the list is reached by showing all")
	forge._click([&"buy"])
	check(tree.rank(stand) == 0 and tree.meta.echo == ProtoTree.START_ECHO, "A: one that waits on another is refused")
	forge._click([&"tab", 2])
	forge._click([&"row", 1])
	check(forge.chosen == MetaProgress.find(&"learn_swallow_cut"), "A: the pointer chooses a branch and a row")
	# B, the tome.
	main.show_screen(1)
	var tome: ProtoTome = main.screens[1]
	tome.pose(&"initial")
	await press(&"ui_down")
	check(tome.chosen == body, "B: down from the lantern enters the lineage")
	await press(&"ui_down")
	check(tome.chosen == MetaProgress.find(&"firm_guard"), "B: down goes to what grows from it")
	await press(&"ui_right")
	check(tome.chosen == MetaProgress.find(&"double_dash"), "B: right goes along the generation")
	await press(&"ui_up")
	check(tome.chosen == body, "B: up goes to what it grows from")
	await tap(KEY_E)
	check(tome.chapter == 1 and tome.chosen == MetaProgress.find(&"learn_thunder_flash"), "B: E turns to the next chapter")
	await press(&"ui_down")
	await press(&"ui_accept")
	check(tree.meta.owns_skill(&"swallow_cut") and tree.meta.echo == ProtoTree.START_ECHO - 350, "B: Enter presses the seal and the skill is learned")
	await press(&"ui_right")
	await press(&"ui_accept")
	check(tome.chosen == blaze and tree.rank(blaze) == 0 and tome.since(&"refuse") < 1.0, "B: one the echo falls short of is refused")
	tome._click([&"tab", 4])
	check(tome.chapter == 4, "B: a tab opens its chapter")
	tome._click([&"node", &"special_surge"])
	tome._click([&"seal"])
	check(tome.chosen == MetaProgress.find(&"special_surge") and tree.rank(tome.chosen) == 0, "B: the pointer on the seal is refused the same way")
	# C, the star chart.
	main.show_screen(2)
	var stars: ProtoStars = main.screens[2]
	stars.pose(&"initial")
	check(stars._places.size() == MetaProgress.UPGRADES.size(), "C: every upgrade has a star")
	await press(&"ui_left")
	check(stars.chosen == body, "C: left goes to the star joined that way")
	await press(&"ui_accept")
	check(tree.rank(body) == 3, "C: Enter lights the star")
	await tap(KEY_E)
	check(stars.chosen == MetaProgress.find(&"learn_thunder_flash"), "C: E goes to the next constellation")
	await tap(KEY_R)
	check(stars.chosen == ProtoTree.root(), "C: R returns to the lantern")
	stars._click([&"star", &"last_stand"])
	stars._click([&"light"])
	check(stars.chosen == stand and tree.rank(stand) == 0, "C: the pointer chooses a star; one that waits is refused")
	var apart := true
	for a in MetaProgress.UPGRADES:
		for b in MetaProgress.UPGRADES:
			if a != b and (stars._places[a.id] as Vector2).distance_to(stars._places[b.id]) < ProtoStars.STAR * 2.0 + 8.0:
				apart = false
	check(apart, "C: no two stars stand on each other")
	check(DirAccess.get_files_at("user://") == saves_before, "No prototype writes to the save folder")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
