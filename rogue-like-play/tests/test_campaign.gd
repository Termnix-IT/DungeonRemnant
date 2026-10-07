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
	check(not state.purchase_skill(&"attack") and not state.purchase_skill(&"vitality"), "Branches wait for base HP's cap")
	state.purchase_upgrade()
	state.purchase_upgrade()
	check(state.purchase_skill(&"attack") and state.purchase_skill(&"defense") and state.purchase_skill(&"mana") and state.purchase_skill(&"vitality"), "Capped base HP opens all four branches")
	check(not state.purchase_skill(&"attack_2"), "A tier waits for the one before it to cap")
	for rank in 4:
		state.purchase_skill(&"attack")
	var price := SkillCatalog.find(&"attack_2").price(0)
	check(price == 100 + 60 * 5 and state.purchase_skill(&"attack_2") and state.skill_bonus(&"attack") == 6, "The next tier continues the branch's prices and bonus")
	check(not state.purchase_skill(&"attack"), "A capped tier buys no more")
	var reach := 0
	for branch: Array in SkillCatalog.BRANCHES:
		for node: SkillNode in branch:
			reach += node.max_rank * node.amount
	check(reach == 60 + 20 + 30 + 10, "The tiers keep the old branches' whole bonus")
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
	# Version 3 held each branch as one node; its ranks spread over the tiers.
	var single := SaveCodec.encode(RunCarryover.new())
	single.version = 3
	single.hp_upgrade_level = 3
	single.skills = {"vitality": 12, "attack": 7, "defense": 1, "mana": 10}
	var spread := SaveCodec.decode(single)
	check(spread != null and spread.skill_levels == {"vitality": 5, "vitality_2": 5, "vitality_3": 2, "attack": 5, "attack_2": 2, "defense": 1, "mana": 4, "mana_2": 3, "mana_3": 3}, "Version 3 branch ranks spread over the tiers")
	check(spread != null and spread.skill_bonus(&"hp") == 36 and spread.skill_bonus(&"attack") == 7 and spread.skill_bonus(&"mp") == 30, "Spreading keeps every bonus")
	check(spread != null and SaveCodec.decode(SaveCodec.encode(spread)) != null, "A spread save saves and loads as version 4")
	single.hp_upgrade_level = 1
	single.skills = {"attack": 2}
	var early := SaveCodec.decode(single)
	check(early != null and early.hp_upgrade_level == 3 and early.skill_rank(&"attack") == 2, "A branch grown under the old rules keeps its ranks and opens base HP")
	single.skills = {"vitality": 2}
	check(SaveCodec.decode(single) == null, "Version 3 skills still obey the rules they were made under")
	single.hp_upgrade_level = 3
	single.skills = {"vitality": 21}
	check(SaveCodec.decode(single) == null, "A version 3 rank beyond its branch is rejected")
	single.skills = {"vitality_2": 1}
	check(SaveCodec.decode(single) == null, "Version 3 saves name no tiers")
	var main := preload("res://game/main.tscn").instantiate()
	main.run_seed = 47
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
	run.boss_hall = true
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
			campaign.boss_hall = false
			campaign._load_floor()
			if floor_number % 10 == 0:
				# The antechamber's door leads on to the boss's hall.
				var door := LayoutUtils.distances(campaign.dungeon.grid, campaign.dungeon.start_cell)
				check(door.has(campaign.dungeon.stairs_cell) and campaign.dungeon.has_stairs and campaign.turns.enemies.is_empty(), "%s %dF antechamber leads on" % [stage.id, floor_number])
				campaign.boss_hall = true
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


