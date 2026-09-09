extends SceneTree


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2 and args[1].begins_with("res://.godot/restart-test-"))
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
