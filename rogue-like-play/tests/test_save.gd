extends SceneTree

var checks := 0
var failures := 0
var test_dir: String


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func write_fixture(path: String, content: String) -> void:
	assert(path.begins_with(test_dir + "/"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()


func sample() -> RunCarryover:
	var state := RunCarryover.new()
	state.gold = 123
	state.hp_upgrade_level = 2
	state.inventory.add(ItemCatalog.POTION, 50)
	for index in 8:
		state.inventory.add(ItemCatalog.floor_item(index))
	state.equipment.slots[2] = preload("res://data/items/leather_armor.tres")
	state.equipment.slots[3] = preload("res://data/items/vital_charm.tres")
	state.equipment.slots[4] = preload("res://data/items/vision_charm.tres")
	return state


func test_codec() -> void:
	var original := SaveCodec.encode(sample())
	var roundtrip := SaveCodec.decode(JSON.parse_string(JSON.stringify(original)))
	check(roundtrip != null and SaveCodec.encode(roundtrip) == original, "JSON round trip preserves all item IDs, counts, five slots and upgrade")
	for invalid in [null, [], "data", 42, true, {}, {"version": 2}]:
		check(SaveCodec.decode(invalid) == null, "Invalid top-level or version rejected")
	for key in ["gold", "hp_upgrade_level", "version"]:
		for invalid in [null, -1, 1.5, "1", true, 1000000001, [], {}]:
			var data := original.duplicate(true)
			data[key] = invalid
			check(SaveCodec.decode(data) == null, "Invalid numeric field rejected: " + key)
	for invalid in [null, {}, "items", [null], [{"id": "unknown", "count": 1}], [{"id": "weapon_0", "count": 2}]]:
		var data := original.duplicate(true)
		data.inventory = invalid
		check(SaveCodec.decode(data) == null, "Invalid inventory rejected")
	for invalid in [0, 51, -1, 1.5, "2", true]:
		var data := original.duplicate(true)
		data.inventory[0].count = invalid
		check(SaveCodec.decode(data) == null, "Invalid stack count rejected")
	var duplicate_stack := original.duplicate(true)
	duplicate_stack.inventory.append(duplicate_stack.inventory[0].duplicate())
	check(SaveCodec.decode(duplicate_stack) == null, "Duplicate stack rejected")
	var full := sample()
	full.inventory = Inventory.new()
	full.inventory.add(ItemCatalog.floor_item(0), 40)
	check(SaveCodec.decode(SaveCodec.encode(full)) != null, "Forty separate gear entries accepted")
	var overflow := SaveCodec.encode(full)
	overflow.inventory.append(overflow.inventory[0])
	check(SaveCodec.decode(overflow) == null, "Forty-one entries rejected")
	for invalid in [null, [], {}, [null, null, null, null, null], ["weapon_0", null, "weapon_1", null, null], ["res://script.gd", null, null, null, null]]:
		var data := original.duplicate(true)
		data.equipment = invalid
		check(SaveCodec.decode(data) == null, "Invalid equipment rejected without loading arbitrary paths")
	check(not original.has("abilities") and not original.has("level") and not original.has("hp"), "Run growth and HP not serialized")


func test_files() -> void:
	var store := SaveStore.new()
	store.path = test_dir + "/progress.json"
	check(store.load_state().gold == 0 and not store.blocked, "Missing save starts fresh")
	var state := sample()
	check(store.save_state(state), "First save succeeds")
	state.gold = 234
	check(store.save_state(state), "Second save succeeds with backup")
	check(store.load_state().gold == 234, "Latest valid primary wins")
	var backup := SaveStore.new()
	backup.path = store.path + ".bak"
	check(backup.load_state().gold == 123, "Backup retains previous generation")
	write_fixture(store.path, "{broken")
	check(store.load_state().gold == 123 and store.message.contains("バックアップ"), "Broken primary falls back to backup")
	check(FileAccess.get_file_as_string(store.path) == "{broken", "Read does not overwrite broken primary")
	check(store.save_state(state) and store.load_state().gold == 234, "Recovery can commit new state")
	var preserved := false
	for name in DirAccess.get_files_at(test_dir):
		if name.begins_with("progress.json.unreadable-"):
			preserved = FileAccess.get_file_as_string(test_dir + "/" + name) == "{broken"
	check(preserved, "Unreadable original archived before replacement")
	write_fixture(store.path, "broken again")
	write_fixture(store.path + ".bak", "bad backup")
	store.load_state()
	check(store.blocked and not store.save_state(state), "Both invalid block saves")
	check(FileAccess.get_file_as_string(store.path) == "broken again" and FileAccess.get_file_as_string(store.path + ".bak") == "bad backup", "Both original files preserved")
	var future := SaveStore.new()
	future.path = test_dir + "/future.json"
	var data := SaveCodec.encode(state)
	data.version = 2
	write_fixture(future.path, JSON.stringify(data))
	future.load_state()
	check(future.blocked and not future.save_state(state), "Unsupported version is protected")
	var interrupted := SaveStore.new()
	interrupted.path = test_dir + "/interrupted.json"
	write_fixture(interrupted.path + ".bak", JSON.stringify(SaveCodec.encode(state)))
	write_fixture(interrupted.path + ".tmp", "partial")
	check(interrupted.load_state().gold == 234, "Missing primary with leftover temporary recovers backup")
	var failed := SaveStore.new()
	failed.path = test_dir + "/missing/sub/progress.json"
	check(not failed.save_state(state) and failed.message.contains("保存失敗"), "Unwritable target reports failure")
	var large := SaveStore.new()
	large.path = test_dir + "/large.json"
	write_fixture(large.path, "x".repeat(SaveStore.MAX_BYTES + 1))
	large.load_state()
	check(large.blocked, "Oversized save rejected")


func test_game_integration() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.save_store.path = test_dir + "/game.json"
	root.add_child(main)
	main.state.gold = 100
	check(main.purchase_upgrade() and main.state.gold == 70, "Purchase saved")
	main.free()
	main = preload("res://game/main.tscn").instantiate()
	main.save_store.path = test_dir + "/game.json"
	root.add_child(main)
	check(main.state.gold == 70 and main.state.hp_upgrade_level == 1, "New Main restores purchase")
	main.start_run()
	main.active_run.turns.gold = 101
	main.active_run.turns.player.inventory.add(ItemCatalog.POTION, 10)
	main.active_run.finish_run(false)
	check(main.active_run.result_panel.save_label.text.contains("保存済み"), "Result saves before Hub return")
	main.free()
	main = preload("res://game/main.tscn").instantiate()
	main.save_store.path = test_dir + "/game.json"
	root.add_child(main)
	check(main.state.gold == 51 and main.state.inventory.entries[0].count == 5 and main.state.hp_upgrade_level == 1, "Restart after result restores once-reduced possessions")
	main.start_run()
	check(main.active_run.turns.player.hp == 25 and main.active_run.progression.level == 1, "Restart applies permanent bonus, not run growth")
	main.active_run.turns.gold = 999
	main.free()
	main = preload("res://game/main.tscn").instantiate()
	main.save_store.path = test_dir + "/game.json"
	root.add_child(main)
	check(main.state.gold == 51, "Interrupted adventure rolls back to departure state")
	main.state.gold = 100
	main.save_store.path = test_dir + "/missing/purchase.json"
	check(not main.purchase_upgrade() and main.state.gold == 100 and main.state.hp_upgrade_level == 1, "Failed save rolls purchase back")
	main.start_run()
	check(main.active_run == null and main.get_node("Hub").save_label.text.contains("保存失敗"), "Failed departure save stays in Hub with error")
	main.free()


func run_tests() -> void:
	test_dir = "res://.godot/save-test-" + str(Time.get_ticks_usec())
	assert(DirAccess.make_dir_recursive_absolute(test_dir) == OK)
	test_codec()
	test_files()
	test_game_integration()
	print("Save tests: %d checks, %d failures; isolated fixtures: %s" % [checks, failures, test_dir])
	quit(0 if failures == 0 else 1)
