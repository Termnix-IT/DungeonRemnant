extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run_tests() -> void:
	await test_cut_in()
	await test_run_reveal()
	print("Boss cut-in: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func boss(display_name: String) -> EnemyStats:
	var stats := EnemyStats.new()
	stats.is_boss = true
	stats.display_name = display_name
	return stats


func ignores_input(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not ignores_input(child):
			return false
	return true


func test_cut_in() -> void:
	var cut_in := BossCutIn.new()
	root.add_child(cut_in)
	await process_frame
	check(not cut_in.visible, "The cut-in starts hidden")
	check(ignores_input(cut_in.root), "The cut-in never takes input")
	var stone := boss("石門の守護者")
	cut_in.present(stone, "10F  ·  守護者")
	check(cut_in.visible and cut_in.name_label.text == "石門の守護者" and cut_in.caption_label.text == "10F  ·  守護者", "The cut-in names the boss and its floor")
	check(cut_in.portrait.visible == (EnemySprites.sheet_for(stone) != null), "A boss with a strip is shown beside its name")
	var unnamed := boss("名もなき試験の主")
	cut_in.present(unnamed, "10F  ·  守護者")
	check(not cut_in.portrait.visible and cut_in.name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "A boss without a strip has its name centred alone")
	await create_timer(BossCutIn.HOLD_TIME * 0.6).timeout
	cut_in.present(stone, "20F  ·  守護者")
	await create_timer(BossCutIn.HOLD_TIME * 0.6).timeout
	check(cut_in.visible and cut_in.root.modulate.a > 0.9, "A new boss restarts the hold instead of fading with the old one")
	await create_timer(BossCutIn.HOLD_TIME * 0.4 + BossCutIn.FADE_TIME + 0.2).timeout
	check(not cut_in.visible and cut_in.root.modulate.a == 1.0, "The cut-in fades out and resets on its own")
	cut_in.present(stone, "10F  ·  守護者")
	cut_in.clear()
	check(not cut_in.visible and not cut_in.is_processing(), "Clearing hides it at once and stops the idle frames")
	cut_in.queue_free()
	await process_frame


func test_run_reveal() -> void:
	var main := load("res://game/main.gd").new() as Node
	var run = (load("res://game/run/run.tscn") as PackedScene).instantiate()
	main.add_child(run)
	run.generation_seed = 47
	run.stage_data = load("res://data/stages/ancient_ruins.tres")
	root.add_child(main)
	await process_frame
	run.floor_number = 10
	run._load_floor()
	run._refresh()
	var hero: Node2D = run.turns.player
	var grid: GridState = run.dungeon.grid
	var boss_actor: Node2D = run.turns.enemies[-1]
	check(boss_actor.stats.is_boss, "Floor 10 has its boss")
	check(not run.dungeon.fog.visible.has(boss_actor.cell) and not run.boss_revealed and not run.boss_cut_in.visible, "An unseen boss plays no cut-in")
	var placed := false
	for offset: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var cell: Vector2i = boss_actor.cell + offset
		if grid.is_floor(cell) and not grid.occupants.has(cell):
			grid.remove_actor(hero)
			grid.place(hero, cell)
			placed = true
			break
	check(placed, "The hero can stand near the boss")
	run._refresh()
	check(run.boss_revealed and run.boss_cut_in.visible and run.boss_cut_in.name_label.text == boss_actor.stats.display_name, "Seeing the boss plays its cut-in")
	check(not run.journey_banner.visible, "The cut-in replaces the floor banner")
	check(hero.input_enabled == (not run.presentation.playing and not run.turns.busy), "The turn does not wait for the cut-in")
	run.boss_cut_in.clear()
	run._refresh()
	check(not run.boss_cut_in.visible, "The cut-in plays once per floor")
	run._load_floor()
	check(not run.boss_revealed and not run.boss_cut_in.visible, "A new floor can reveal its boss again")
	main.queue_free()
	await process_frame
