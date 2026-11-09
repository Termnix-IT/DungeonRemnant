extends SceneTree

# Where things stand on the 1600x900 screen: the base's content centred, its
# pages and their actions on the screen; then in a run, the route map and
# the result centred, the fight's HUD in its corners without overlaps and
# off the ground round the hero, and the level-up cards and the menu
# centred over the fight.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func centered(control: Control, label: String) -> void:
	var viewport := root.get_visible_rect()
	var rect := control.get_global_rect()
	check(rect.get_center().distance_to(viewport.get_center()) < 2.0, "%s stays centred" % label)
	check(viewport.grow(1).encloses(rect), "%s fits the screen" % label)


func settle(seconds: float = 0.0) -> void:
	if seconds > 0.0:
		await create_timer(seconds).timeout
	for frame in 3:
		await process_frame


func run_tests() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.run_seed = 6
	main.meta.echo = 500
	root.add_child(main)
	await settle()
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	centered(hub.get_node("Content"), "The base's content")
	var screen := root.get_visible_rect()
	for page in ["sortie", "upgrade", "status", "codex", "settings"]:
		hub.show_page(page)
		# Measure the resting layout, after the page has slid into place.
		await settle(UIMotion.WINDOW_TIME + 0.05)
		var shown: Control = {"sortie": hub.sortie_page, "upgrade": hub.upgrade_page, "status": hub.status_page, "codex": hub.codex_page, "settings": hub.settings_page}[page]
		check(screen.grow(1).encloses(shown.get_global_rect()), "The %s page stays on the screen" % page)
	hub.show_page("upgrade")
	await settle(UIMotion.WINDOW_TIME + 0.05)
	var tree: MetaUpgradePage = hub.upgrade_page
	check(screen.encloses(tree.buy_button.get_global_rect()), "The upgrade's action stays on the screen")
	var board := tree.board.get_global_rect()
	check(board.end.x <= tree.buy_button.get_global_rect().position.x and tree.board.clip_contents, "The tree's window is left of the column, clipping its board")
	var well := tree.board.get_parent() as PanelContainer
	var well_style := well.get_theme_stylebox(&"panel") as StyleBoxFlat if well != null else null
	check(well != null and well.theme_type_variation == &"TreeWell" and well_style != null and well_style.bg_color.a == 1.0, "The board lies in an opaque well of its own")
	check(tree.nodes[MetaProgress.ROOT].size.x > tree.nodes[&"sturdy_body"].size.x, "The root is the largest node")
	var root_node: Button = tree.nodes[MetaProgress.ROOT]
	check(board.encloses(root_node.get_global_rect()) and absf(root_node.get_global_rect().get_center().x - board.get_center().x) < 2.0, "The root opens in the window's middle")
	var far: Button = tree.nodes[&"fourth_card"]
	far.grab_focus()
	await settle(MetaUpgradePage.FOLLOW_TIME + 0.1)
	check(board.grow(-MetaUpgradePage.FOLLOW_MARGIN + 2.0).has_point(far.get_global_rect().get_center()), "The board follows the focus to a node out at a branch's end")
	hub.show_page("home")
	await settle(UIMotion.WINDOW_TIME + 0.05)
	check(screen.encloses(hub.decide_button.get_global_rect()), "The lobby's action stays on the screen")

	# A run: the route map.
	main.start_run()
	await settle(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.1)
	var run: RunDirector = main.active_run
	centered(run.map_view._panel, "The route map")
	# An area: the HUD in its corners, off the fight round the hero.
	run.map_view._choose(run.run.route.nodes(0)[0])
	await settle(BattleArea.BANNER_TIME + 0.2)
	var area: BattleArea = run.area
	area.hero.controlled = false
	var hud: ActionHud = area.hud
	var ring := Rect2(Vector2(screen.size) * 0.5 - Vector2(260, 200), Vector2(520, 400))
	var panels: Array[Control] = [hud.hp_gauge, hud.info, hud.guide, hud.exp_bar, hud.level_label, hud.skill_label]
	for panel in panels:
		check(screen.grow(-4).encloses(panel.get_global_rect()), "%s keeps off the screen's edge" % panel.name)
		check(not panel.get_global_rect().intersects(ring), "%s stays off the ground round the hero" % panel.name)
	check(not hud.hp_gauge.get_global_rect().intersects(hud.guide.get_global_rect()) and not hud.info.get_global_rect().intersects(hud.exp_bar.get_global_rect()), "HUD parts do not overlap")
	# The common arrangement: the goal at the top centre, the tally at the
	# top right, health at the bottom left, the actions at the bottom right.
	var middle := screen.get_center().x
	check(absf(hud.goal.get_global_rect().get_center().x - middle) < 2.0 and hud.goal.get_global_rect().end.y < ring.position.y, "The goal stands at the top centre")
	check(hud.kills_label.get_global_rect().position.x > middle and hud.kills_label.get_global_rect().end.y < ring.position.y, "The tally keeps to the top right")
	# One count is not shown twice: while the goal counts the foes, the tally
	# leaves them out; the echo is always there.
	check(hud.echo_row.visible and hud.kills_row.visible == not (hud.goal.visible and area.data.kill_target > 0), "The tally shows the echo, and the foes only when the goal does not count them")
	# The controls are the key guide the other screens use.
	check(hud.guide is KeyGuide and hud.guide.get_child_count() == ActionHud.CONTROLS.size(), "The controls under the fight are a key guide")
	check(hud.hp_bar.get_global_rect().end.x < middle and hud.hp_bar.get_global_rect().position.y > ring.end.y, "Health keeps to the bottom left")
	# The health runs inside its painted frame's channel, past the crest.
	var frame_rect := hud.hp_gauge.frame.get_global_rect()
	var fill_rect := hud.hp_bar.get_global_rect()
	check(hud.hp_gauge.frame.texture == ActionHud.HP_FRAME and frame_rect.encloses(fill_rect) and is_equal_approx(fill_rect.position.x - frame_rect.position.x, ActionHud.HP_CAP_LEFT) and is_equal_approx(fill_rect.size.x, ActionHud.BAR_WIDTH), "Health fills the channel of its painted frame")
	for key: StringName in hud.slots:
		var slot_rect := hud.slots[key].get_global_rect()
		check(screen.grow(-4).encloses(slot_rect) and slot_rect.position.x > middle and slot_rect.position.y > ring.end.y and not slot_rect.intersects(hud.guide.get_global_rect()), "The %s slot keeps to the bottom right" % key)
	# The level-up cards and the menu over the fight.
	area._on_gems(area.run.progression.required_exp())
	await settle(0.4)
	centered(area.choice.get_node("Panel"), "The level-up cards")
	area.choice._select(0)
	await settle()
	var taken := area.run.build.owned()
	check(hud.boons.get_child_count() == 1 and (hud.boons.get_child(0) as TextureRect).texture == EmblemIcons.texture(taken[0].emblem), "The boon taken shows as its emblem under the goal")
	check(screen.grow(-4).encloses(hud.boons.get_global_rect()) and not hud.boons.get_global_rect().intersects(ring), "The boons keep to the corner")
	area.open_menu()
	await settle(0.3)
	var menu_panel: Control = area.menu.menu.get_child(0)
	centered(menu_panel, "The fight's menu")
	check(area.menu.build_panel.visible and area.menu.build_grid.get_child_count() == area.run.build.owned().size(), "Beside the menu, every boon of the build is in the grid")
	check(area.menu.build_panel.get_parent() == area.menu.resume_button.get_parent().get_parent(), "The build and the menu share one window")
	var first_boon: BoonData = area.run.build.owned()[0]
	var cells := area.menu.build_grid.get_children()
	check(cells[0] is EquipSocket and (cells[0] as EquipSocket).emblem == EmblemIcons.texture(first_boon.emblem), "Each boon is its emblem in a socket")
	check(area.menu.build_name.text == first_boon.display_name and area.menu.build_note.text == first_boon.effect_description(area.run.build.rank(first_boon.id)), "What a boon is and does is told once, under the grid")
	check(area.menu.resume_button.get_node_or_null(area.menu.resume_button.focus_neighbor_left) == cells[0] and (cells[0] as Button).focus_mode == Control.FOCUS_ALL and (cells[0] as Button).get_node_or_null((cells[0] as Button).focus_neighbor_right) == area.menu.resume_button, "Left from the menu reaches the build and right comes back")
	# The menu's column stands on one axis: the heading, the buttons and the
	# keys share its centre.
	var menu_column := area.menu.resume_button.get_parent() as Control
	var axis := area.menu.resume_button.get_global_rect().get_center().x
	var heading := menu_column.get_child(0) as Label
	var keys := menu_column.get_child(menu_column.get_child_count() - 1) as Control
	var first_key := keys.get_child(0) as Control
	var last_key := keys.get_child(keys.get_child_count() - 1) as Control
	var keys_middle := (first_key.get_global_rect().position.x + last_key.get_global_rect().end.x) * 0.5
	check(heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and absf(heading.get_global_rect().get_center().x - axis) < 2.0 and keys is KeyGuide and absf(keys_middle - axis) < 2.0, "The menu's heading, buttons and keys share one centre")
	# The menu's words spread to one width, the longest's; the build's
	# heading and grid stand on their column's centre too.
	var spread: Array = [area.menu.resume_button, area.menu.settings_button, area.menu.abort_button]
	var widest := 0.0
	for button: JustifiedButton in spread:
		widest = maxf(widest, button.natural_width())
	check(spread.all(func(button: JustifiedButton) -> bool: return button.text.is_empty() and is_equal_approx(button.span, widest)), "The menu's words are spread to the longest one's width")
	var build_heading := area.menu.build_panel.get_child(0) as Label
	var build_axis := area.menu.build_panel.get_global_rect().get_center().x
	check(build_heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and absf(area.menu.build_grid.get_global_rect().get_center().x - build_axis) < 2.0, "The build's heading and grid share their column's centre")
	# Every boon there is, at its top rank, still fits on the screen; the
	# build goes back as it was after.
	var ranks_before: Dictionary = area.run.build.ranks.duplicate()
	for boon in RunState.BOONS:
		area.run.build.restore(boon.id, boon.max_level)
	area.menu.open()
	await settle(0.3)
	check(area.menu.build_grid.get_child_count() == RunState.BOONS.size(), "A full build is all in the grid")
	centered(menu_panel, "The fight's menu with every boon")
	area.run.build.ranks = ranks_before
	area.run.build.changed.emit()
	area.menu.resume()
	await settle()
	check(not paused, "Leaving the menu resumes the fight")
	# Low on health, the edges pulse; well again, they clear.
	area.hero.health.hp = 20
	await settle()
	check(hud.danger.visible and hud.danger.mouse_filter == Control.MOUSE_FILTER_IGNORE, "At a fifth of her health the edges pulse red, taking no input")
	area.hero.health.hp = area.hero.health.max_hp
	await settle()
	check(not hud.danger.visible, "With her health back the edges clear")
	# The result.
	area.hero.health.hp = 1
	area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await settle(RunDirector.FALL_PAUSE + 0.3)
	centered(run.end_view._panel, "The result")
	print("UI layout: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
