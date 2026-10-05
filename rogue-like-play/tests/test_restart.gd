extends SceneTree

# A save must survive the game closing: one process writes it and a second,
# separate process reads it back. Run plainly, this suite starts both steps
# as child processes of the same Godot; each child is this script again with
# "write" or "read" and the save's path after "--".


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		run_both_steps()
		return
	# A bad call ends the process as failed instead of stopping on an assert
	# and never quitting.
	if args.size() != 2 or args[0] not in ["write", "read"] or not args[1].begins_with("res://.godot/restart-test-"):
		push_error("Usage: -- write|read res://.godot/restart-test-<name>.json")
		quit(1)
		return
	var store := SaveStore.new()
	store.path = args[1]
	var ok := true
	if args[0] == "write":
		var state := RunCarryover.new()
		state.gold = 87
		state.hp_upgrade_level = 2
		state.inventory.add(ItemCatalog.POTION, 17)
		state.equipment.slots[4] = preload("res://data/items/vital_charm.tres")
		ok = store.save_state(state)
	else:
		var state := store.load_state()
		ok = state.gold == 87 and state.hp_upgrade_level == 2 and state.inventory.entries.size() == 1
		ok = ok and state.inventory.entries[0].count == 17 and state.equipment.slots[4] == preload("res://data/items/vital_charm.tres")
	print("Separate process %s: %s" % [args[0], "passed" if ok else "FAILED"])
	quit(0 if ok else 1)


func run_both_steps() -> void:
	var path := "res://.godot/restart-test-%d.json" % Time.get_ticks_usec()
	var ok := true
	for step in ["write", "read"]:
		var output := []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/test_restart.gd", "--", step, path], output, true)
		for line: String in "".join(output).split("\n"):
			if line.begins_with("Separate process"):
				print(line.strip_edges())
		ok = ok and code == 0
	for leftover in [path, path + ".bak", path + ".tmp", path + ".bak.tmp"]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
	print("Restart tests: save read back by a separate process %s" % ("passed" if ok else "FAILED"))
	quit(0 if ok else 1)
