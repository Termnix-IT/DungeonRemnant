extends SceneTree

# Run feedback: named combat log, HUD HP landing with hits, the themed stair
# prompt, the floor-change cover and the sortie confirmation page.
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const BASIC := preload("res://data/enemies/basic_enemy.tres")
const SUMMONER := preload("res://data/enemies/summoner_enemy.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func make_run() -> Node2D:
	var run := preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	run.final_floor = 20
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	run.dungeon_settings.reinforcement_total_cap = 0
	root.add_child(run)
	var grid: GridState = run.dungeon.grid
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	grid.place(run.turns.player, Vector2i(10, 10))
	run.dungeon.has_stairs = false
	run.dungeon.fog.reset()
	run._refresh()
	return run


func add_enemy(run: Node2D, stats: EnemyStats, cell: Vector2i, hp: int) -> Node2D:
	var enemy := ENEMY.instantiate()
	enemy.stats = stats.duplicate()
	enemy.stats.max_hp = hp
	enemy.hp = hp
	run.dungeon.get_node("Actors").add_child(enemy)
	run.dungeon.grid.place(enemy, cell)
	run.turns.enemies.append(enemy)
	return enemy


func run_tests() -> void:
	root.add_child(preload("res://game/main.gd").new())
	await check_combat_log()
	await check_defeat_log()
	check_summon_log()
	check_floor_messages()
	await check_stair_prompt()
	await check_confirmation_page()
	await check_combat_readability()
	print("Run feedback tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check_combat_log() -> void:
	var run := make_run()
	var player: Node2D = run.turns.player
	var hud = run.hud
	check(not run.turns.last_message.contains("水色"), "No prototype colour legend in the log")
	var entries: int = hud.log_history.size()
	run._on_action("move", Vector2i.LEFT)
	await wait_presentation(run)
	check(hud.log_history.size() == entries, "A plain step adds no log entry")
	var enemy := add_enemy(run, BASIC, player.cell + Vector2i.RIGHT, 100)
	run._refresh()
	var hp_before: int = player.hp
	run._on_action("attack", Vector2i.RIGHT)
	check(player.hp < hp_before and run.presentation.playing, "Retaliation is resolved before playback")
	check(hud.hp_value.text == "%d / %d" % [hp_before, player.stats.max_hp], "HUD keeps pre-hit HP until the hit lands")
	check(not "\n".join(hud.log_history).contains("の攻撃で"), "Log waits for the playback")
	await wait_presentation(run)
	check(hud.hp_value.text == "%d / %d" % [player.hp, player.stats.max_hp], "HUD HP settles after the hit")
	var line: String = hud.log_history[-1]
	check(line.contains("%sに" % enemy.stats.display_name) and line.contains("%sの攻撃で" % enemy.stats.display_name), "Log names the target and the attacker: " + line)
	check(not line.begins_with("移動しました"), "Log has no routine movement prefix")
	var count: int = hud.log_history.size()
	run._on_action("attack", Vector2i.RIGHT)
	await wait_presentation(run)
	check(hud.log_history.size() == count + 1, "An identical line from a new action is still logged")
	run.free()


func check_defeat_log() -> void:
	var run := make_run()
	var player: Node2D = run.turns.player
	add_enemy(run, BASIC, player.cell + Vector2i.RIGHT, 100)
	player.hp = 1
	run._refresh()
	run._on_action("attack", Vector2i.LEFT)
	check(run.turns.ended and run.turns.defeated_by == BASIC.display_name, "Defeat records the attacker")
	check(run.danger.target > 0.0, "Low HP raises the danger vignette")
	await wait_presentation(run)
	check(run.hud.log_history[-1].contains("%sに倒された" % BASIC.display_name), "Defeat line names the attacker")
	var result: Dictionary = run.result
	check(result.defeated and result.defeated_by == BASIC.display_name and result.level == 1 and result.turns == 1, "Result records cause, level and turns")
	var panel = run.result_panel
	check(panel.visible and not panel.ready_for_input(), "Defeat result holds input during the beat")
	check(panel.cause_label.text.contains("%sに倒された" % BASIC.display_name) and panel.turns_value.text == "1", "Result panel shows the cause and turn count")
	check(player.combat_visual.rotation != 0.0, "The hero collapses after the killing blow")
	await create_timer(panel.DEFEAT_BEAT + 0.05).timeout
	check(panel.ready_for_input(), "Result accepts input after the beat")
	run.free()


func check_combat_readability() -> void:
	var run := make_run()
	var player: Node2D = run.turns.player
	var enemy := add_enemy(run, BASIC, player.cell + Vector2i.RIGHT, 100)
	player.aiming = true
	player.facing = Vector2i.RIGHT
	run._refresh()
	check(run.preview.visible and enemy.cell in run.preview.target_cells, "Aim preview marks the cell holding a target")
	player.facing = Vector2i.LEFT
	run._refresh()
	check(run.preview.target_cells.is_empty() and not run.preview.cells.is_empty(), "Empty range shows brackets without a reticle")
	player.aiming = false
	var effects = run.hud.get_node("ActiveEffects")
	check(not effects.visible, "No active effects hides the effects panel")
	for item in ItemCatalog.talismans():
		player.active_effects.add(item)
	run._refresh()
	check(effects.visible and effects.entries.size() == player.active_effects.effects.size() and effects.entries.size() > 1, "Each active effect gets its own row")
	for panel_name in ["TopRight", "BottomLeft", "Log"]:
		check(not effects.get_global_rect().intersects(run.hud.get_node(panel_name).get_global_rect()), "Effects panel stays clear of %s" % panel_name)
	check(run.danger.target == 0.0, "Full HP keeps the vignette off")
	var kills: int = run.turns.kills_total
	enemy.hp = 1
	run._on_action("attack", Vector2i.RIGHT)
	check(run.turns.kills_total == kills + 1, "Kills are counted for the result")
	await wait_presentation(run)
	run.free()


func check_summon_log() -> void:
	var run := make_run()
	var source := add_enemy(run, SUMMONER, Vector2i(5, 5), 10)
	run.turns.begin_message("")
	run._summon_enemy(source)
	run._summon_enemy(source)
	var charger: String = preload("res://data/enemies/charge_enemy.tres").display_name
	check(run.turns.last_message.contains("%sが2体召喚された！" % charger) and not run.turns.last_message.contains("%sが召喚された！" % charger), "Summons in one action collapse into a count")
	run.turns.begin_message("")
	run._summon_enemy(source)
	check(run.turns.last_message.strip_edges() == "%sが召喚された！" % charger, "A later action starts its own summon line")
	run.free()


func check_floor_messages() -> void:
	var run := make_run()
	check(run.turns.last_message.contains("1Fに到着") and run.turns.last_message.contains("金色の階段"), "First floor explains the stairs")
	run.floor_number = 2
	run._load_floor()
	check(run.turns.last_message == "2Fに到着した。", "Later floors only announce arrival")
	run.free()


func check_stair_prompt() -> void:
	var run := make_run()
	var grid: GridState = run.dungeon.grid
	grid.remove_actor(run.turns.player)
	grid.place(run.turns.player, Vector2i(2, 2))
	run.dungeon.has_stairs = true
	run.dungeon.stairs_cell = Vector2i(3, 2)
	var prompt: ChoicePrompt = run.transition_dialog
	run._on_action("move", Vector2i.RIGHT)
	check(prompt.visible and run.turns.paused and prompt.accept_button.text == "降りる", "Stairs open the themed prompt")
	check(prompt.body_label.text.contains("2F"), "Prompt names the next floor")
	var cancel := InputEventAction.new()
	cancel.action = "cancel_attack"
	cancel.pressed = true
	prompt._input(cancel)
	check(not prompt.visible and run.floor_number == 1 and not run.turns.paused, "Escape declines the descent")
	await wait_presentation(run)
	run.turns.submit("move", Vector2i.LEFT)
	run.turns.submit("move", Vector2i.RIGHT)
	check(prompt.visible, "Returning to the stairs asks again")
	prompt.accept_button.pressed.emit()
	check(run.floor_number == 2 and not prompt.visible, "Accepting descends immediately")
	check(run.floor_cover.covering and not run._world_input_available(), "Floor cover blocks input while the new floor is hidden")
	check(run.journey_banner.panel.modulate.a == 0.0, "Arrival banner waits for the reveal")
	await create_timer(SceneTransition.DESCENT_HOLD_TIME + SceneTransition.REVEAL_TIME + 0.1).timeout
	check(not run.floor_cover.covering and not run.floor_cover.visible, "Cover lifts on its own")
	run.free()


func check_confirmation_page() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.show_page("stages")
	hub.show_page("confirm")
	var page: HubDeparture = hub.departure_page
	check(page.carried.cells.is_empty() and page.carried.empty_label.visible and page.carried.empty_label.text == "持ち込みの品はない" and page.carried_rule.tooltip_text.contains("半分を失う"), "An empty loadout reads as a note, not a disabled row")
	check(page.slot_cells[0].item == main.state.equipment.slots[0] and page.slot_cells.size() == 5, "Confirmation shows the five slots as icons")
	check(page.hero_stats.specs.rows.size() == 4 and page.hero_stats.specs.rows[0][1] == main.state.preparation_stats().hp, "Confirmation shows departure stats")
	var stats_stack := page.hero_stats.specs.get_parent()
	check(stats_stack.get_parent() == page.confirm_button.get_parent() and stats_stack.get_index() < page.confirm_button.get_index() and stats_stack.visible and not page.hero_stats.specs.changed_only, "All four stats stand in the middle column above the action, not over her")
	check(page.stage_banner.texture == page.selected_stage.diorama, "Confirmation shows the destination's diorama")
	main.state.inventory.add(ItemCatalog.POTION, 3)
	hub.show_page("confirm")
	check(page.carried.cells.size() == 1 and page.carried_count.text == "1 / 40 枠", "Carried items show as icons with capacity")
	check(page.start_only.visible and not page.start_choice.visible and page.start_only.text == "1F", "A single start floor reads as text, not a tab of one")
	main.state.unlocked_entries[String(page.selected_stage.id)] = [11]
	hub.show_page("confirm")
	check(page.start_choice.visible and not page.start_only.visible and page.start_choice.item_count == 2, "Two start floors become tabs")
	main.free()
	await process_frame


func wait_presentation(run: Node2D) -> void:
	if run.presentation.playing:
		await run.presentation.finished
	await process_frame
