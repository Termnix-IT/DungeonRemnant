extends SceneTree

const RUINS := preload("res://data/stages/ancient_ruins.tres")
const FOREST := preload("res://data/stages/forest.tres")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run_tests() -> void:
	var state := RunCarryover.new()
	state.gold = 10000
	check(state.stage_available(RUINS) and not state.stage_available(FOREST), "Sequential dungeon unlock")
	check(not state.stage_available(preload("res://data/stages/unknown.tres")), "Future dungeon unavailable")
	check(not state.purchase_skill(&"attack") and not state.unlock_entry(RUINS, 11), "Prerequisites required")
	state.purchase_upgrade()
	check(state.purchase_skill(&"attack") and state.purchase_skill(&"defense") and state.purchase_skill(&"mana"), "Stat tree branches")
	check(not state.purchase_skill(&"vitality"), "Vitality requires base HP rank 3")
	state.purchase_upgrade()
	state.purchase_upgrade()
	check(state.purchase_skill(&"vitality"), "Vitality unlocked")
	state.record_boss(RUINS.id, 10, false)
	var gold := state.gold
	check(state.unlock_entry(RUINS, 11) and state.gold == gold - RUINS.entry_costs[0], "Entry costs coins after boss")
	check(not state.unlock_entry(RUINS, 11) and not state.can_start(FOREST, 11) and not state.can_start(RUINS, 21), "No duplicate or cross-dungeon unlock")
	check(state.can_start(RUINS, 1) and state.can_start(RUINS, 11), "Both fresh and intermediate start remain available")
	var loaded := SaveCodec.decode(SaveCodec.encode(state))
	check(loaded != null and loaded.skill_levels == state.skill_levels and loaded.can_start(RUINS, 11), "Campaign save round trip")
	var invalid := SaveCodec.encode(state)
	invalid.entries.ancient_ruins.append(21)
	check(SaveCodec.decode(invalid) == null, "Entry without boss rejected")
	invalid = SaveCodec.encode(state)
	invalid.skills.attack = 999
	check(SaveCodec.decode(invalid) == null, "Invalid skill rank rejected")
	var legacy := SaveCodec.encode(RunCarryover.new())
	legacy.version = 2
	for key in ["skills", "bosses", "entries", "cleared_stages"]:
		legacy.erase(key)
	check(SaveCodec.decode(legacy) != null, "Version 2 migrates with empty campaign")
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	main.state = state
	var hub: CanvasLayer = main.get_node("Hub")
	hub.refresh(state)
	hub.show_page("stages")
	hub.departure_page._select_stage(0)
	hub.show_page("confirm")
	hub.departure_page.starting_floor = 11
	main.start_run()
	var run: Node2D = main.active_run
	check(run != null and run.floor_number == 11 and run.final_floor == 50, "Main starts selected floor")
	check(run.turns.progression.level == 1 and run.turns.player.stats.max_mp == 23, "Fresh level with permanent MP")
	check(run.turns.player.stats.max_hp == state.preparation_stats().hp and run.turns.player.stats.defense == state.preparation_stats().defense, "Preparation and runtime stats agree")
	var attack: int = run.turns.player.stats.attack
	run.floor_number = 12
	run._load_floor()
	check(run.turns.player.stats.attack == attack, "Floor change does not stack permanent stats")
	run.floor_number = 10
	run._load_floor()
	check(not run.dungeon.has_stairs, "Midboss locks descent")
	run.turns.floor_turn_count = 5000
	run._on_boss_defeated()
	check(run.floor_limit == 5150 and run.dungeon.has_stairs and run.exit_cell == run.dungeon.start_cell, "Midboss grace, descent, and safe exit")
	run.finish_run(false, true)
	run.retry_run()
	main.saving_enabled = true
	main.save_store.path = "res://.godot/nonexistent-campaign-directory/save.json"
	var before := SaveCodec.encode(state)
	check(not main.purchase_skill(&"attack") and SaveCodec.encode(state) == before, "Skill purchase rolls back on save failure")
	state.record_boss(RUINS.id, 20, false)
	before = SaveCodec.encode(state)
	check(not main.unlock_entry(RUINS, 21) and SaveCodec.encode(state) == before, "Entry purchase rolls back on save failure")
	main.free()
	# Exercise every authored floor with isolated test state, without the charger-chasing bot.
	for stage in [RUINS, FOREST]:
		var campaign := preload("res://game/run/run.tscn").instantiate()
		campaign.stage_data = stage
		campaign.final_floor = stage.floor_count
		campaign.dungeon_settings = stage.settings
		campaign.generation_seed = 713
		root.add_child(campaign)
		for floor_number in range(1, 51):
			campaign.floor_number = floor_number
			campaign._load_floor()
			var reached := LayoutUtils.distances(campaign.dungeon.grid, campaign.dungeon.start_cell)
			check(reached.has(campaign.dungeon.stairs_cell), "%s %dF connected" % [stage.id, floor_number])
			var bosses := 0
			for enemy in campaign.turns.enemies:
				if enemy.stats.is_boss:
					bosses += 1
			check(bosses == (1 if floor_number % 10 == 0 else 0), "%s %dF boss schedule" % [stage.id, floor_number])
		check(campaign.dungeon.forest == (stage == FOREST), "Stage terrain applied")
		campaign._on_boss_defeated()
		check(campaign.result.get("cleared", false) and String(stage.id) in campaign.carryover.cleared_stages, "Final boss completes campaign")
		if stage == RUINS:
			check(campaign.carryover.stage_available(FOREST), "Ruin boss unlocks forest")
		campaign.free()
	await process_frame
	print("Campaign tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


