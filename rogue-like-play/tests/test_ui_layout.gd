extends SceneTree

# What the layout must keep on the 1600x900 screen, whatever the look: the
# base's content centred in its frame, its pages and their actions on the
# screen and answering the pointer; then in a run, the route's gates and
# keys on the screen, the fight's HUD on it without overlaps and off the
# ground round the hero, the level-up cards, the menu and the result on the
# screen, the build reachable from the menu by keys and pad. Which corner a
# part keeps to is the genre's arrangement and is judged on the captures; a
# look held on purpose says why where it is checked.

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


func on_screen(control: Control, label: String) -> void:
	check(root.get_visible_rect().grow(1).encloses(control.get_global_rect()), "%s fits the screen" % label)


# Parts that share the fight's screen: each keeps off its edge and off the
# ground round the hero, and no two overlap.
func check_apart(all_parts: Array[Control], screen: Rect2, ring: Rect2, label: String) -> void:
	var parts := all_parts.filter(func(part: Control) -> bool: return part.is_visible_in_tree())
	for index in parts.size():
		var rect: Rect2 = (parts[index] as Control).get_global_rect()
		check(screen.grow(-4).encloses(rect) and not rect.intersects(ring), "%s, %s keeps on the screen and off the hero's ground" % [label, parts[index].name])
		for other in range(index + 1, parts.size()):
			check(not rect.intersects((parts[other] as Control).get_global_rect()), "%s, %s and %s do not overlap" % [label, parts[index].name, parts[other].name])


func settle(seconds: float = 0.0) -> void:
	if seconds > 0.0:
		await create_timer(seconds).timeout
	for frame in 3:
		await process_frame


func run_tests() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.show_opening = false
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
	for drawn: Control in [hub.sortie_page, hub.upgrade_page, hub.status_page, hub.codex_page, hub.settings_page]:
		check(drawn.mouse_filter == Control.MOUSE_FILTER_STOP, "%s, which draws itself, answers the pointer" % drawn.name)
	hub.show_page("sortie")
	await settle(UIMotion.WINDOW_TIME + 0.05)
	var vista: HubSortie = hub.sortie_page
	check(screen.encloses(vista.action_button.get_global_rect()), "The departure's action stays on the screen")
	check((vista.get_node(^"Vista") as Control).get_global_rect().encloses(screen), "The departure's painting covers the whole screen")
	var set_out := Rect2(vista.global_position + vista._origin + HubSortie.BUTTON.position * vista._zoom, HubSortie.BUTTON.size * vista._zoom)
	check(set_out.grow(1).encloses(vista.action_button.get_global_rect()) and not HubSortie.BUTTON.intersects(HubSortie.STEP_PLATE), "Its action keeps its room, clear of the step")
	hub.show_page("status")
	await settle(UIMotion.WINDOW_TIME + 0.05)
	var pillars: HubStatus = hub.status_page
	check(pillars._sky.get_global_rect().encloses(screen), "The status page's night sky covers the whole screen")
	var longest := 0
	for index in HubStatus.SLOTS.size():
		longest = maxi(longest, pillars.entries_of(index).size())
	check(HubStatus.FIRST + HubStatus.STEP * (longest - 0.5) <= HubStatus.DESIGN.y and HubStatus.LEFT + HubStatus.SLOTS.size() * (HubStatus.WIDE + HubStatus.GAP) - HubStatus.GAP <= HubStatus.CARD.position.x, "Every pillar and everything hung on it fits the page, clear of the card")
	check(not HubStatus.CARD.intersects(HubStatus.FIGURES_PLATE) and Rect2(Vector2.ZERO, HubStatus.DESIGN).encloses(HubStatus.FIGURES_PLATE), "The plate that opens her figures keeps its room under the card")
	hub.show_page("settings")
	await settle(UIMotion.WINDOW_TIME + 0.05)
	var stage: HubSettings = hub.settings_page
	check((stage.get_node(^"Veil") as Control).get_global_rect().encloses(screen), "The settings' veil covers the whole screen")
	check(Rect2(Vector2.ZERO, HubSettings.DESIGN).encloses(HubSettings.LIST) and Rect2(Vector2.ZERO, HubSettings.DESIGN).encloses(HubSettings.STAGE) and not HubSettings.LIST.intersects(HubSettings.STAGE), "The settings' list and stage keep to the page, clear of each other")
	check(HubSettings.LIST.position.y + HubSettings.TABS.size() * (HubSettings.HEAD + HubSettings.GROUP_GAP) + stage.shown_rows().size() * HubSettings.ROW <= HubSettings.DESIGN.y, "Every settings row fits the list")
	# The help: every topic's two columns fit its page, in both languages.
	stage.open_help(HubSettings.TOPIC_RUN)
	await settle(UIMotion.WINDOW_TIME + 0.05)
	var help: HelpView = stage.help_view
	check(help.get_global_rect().encloses(screen) and (help.get_node(^"KeyGuide") if help.has_node(^"KeyGuide") else help.close_hint.get_parent()).get_global_rect().end.y <= screen.end.y, "The help fills the screen, its keys on it")
	for language: String in ["ja", "en"]:
		TranslationServer.set_locale(language)
		for topic in HelpView.count():
			var tall := help.heights_of(topic)
			check(maxf(tall.x, tall.y) <= HelpView.points_room(), "The help's %s fits its page in %s (%d of %d)" % [HubSettings.HELP[topic][0], language, int(maxf(tall.x, tall.y)), int(HelpView.points_room())])
	TranslationServer.set_locale("ja")
	stage.close_help()
	hub.show_page("upgrade")
	await settle(UIMotion.WINDOW_TIME + 0.05)
	var chart: MetaUpgradePage = hub.upgrade_page
	check(screen.encloses(chart.buy_button.get_global_rect()), "The upgrade's action stays on the screen")
	check(chart._sky.get_global_rect().encloses(screen), "The upgrade's night sky covers the whole screen")
	var chart_card := Rect2(chart.global_position + chart._origin + MetaUpgradePage.CARD.position * chart._zoom, MetaUpgradePage.CARD.size * chart._zoom)
	check(screen.encloses(chart_card) and chart_card.grow(1.0).encloses(chart.buy_button.get_global_rect()), "The chart_card stays on the screen, the action inside it")
	var in_sight := true
	for upgrade in MetaProgress.UPGRADES:
		var star := chart.global_position + chart.place_of(upgrade.id)
		in_sight = in_sight and screen.grow(-MetaUpgradePage.STAR).has_point(star) and not chart_card.grow(MetaUpgradePage.STAR).has_point(star)
	check(in_sight, "Every star of the chart is on the screen and clear of the chart_card")
	check(chart.place_of(MetaProgress.ROOT).distance_to(chart._origin + MetaUpgradePage.POLE * chart._zoom) < 0.5, "The lantern stands at the chart's pole")
	hub.show_page("home")
	await settle(UIMotion.WINDOW_TIME + 0.05)
	check(screen.encloses(hub.decide_button.get_global_rect()), "The lobby's action stays on the screen")

	# A run: the route map.
	main.start_run()
	await settle(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.1)
	var run: RunDirector = main.active_run
	# The route's gates: the page fills the screen, and its design space, every
	# gate and the keys at the foot stay on it.
	var gates := run.map_view.page
	check(gates.get_global_rect().is_equal_approx(screen), "The route's gates fill the screen")
	await settle(RouteGates.RISE_TIME + RouteGates.RISE_STAGGER * 3.0 + 0.2)
	check(screen.grow(1.0).encloses(Rect2(gates.global_position + gates._origin, RouteGates.DESIGN * gates._zoom)), "The gates' design space stays on the screen")
	for index in gates.open.size():
		var gate := gates.gate_rect(index)
		check(gate.has_area() and screen.encloses(Rect2(gates.global_position + gate.position, gate.size)), "Gate %d stands on the screen" % (index + 1))
	check(screen.encloses(gates.guide.get_global_rect()), "The gates' keys stay on the screen")
	var slab := gates.tablet.rect()
	check(gates.gates.all(func(gate: RouteGateView) -> bool: return gate.position.y - gate.crown() >= slab.end.y - 1.0), "No gate reaches up into the tablet, whatever crowns it")
	var under := RouteGates.FLOOR + gates.block_height(gates.selected()) + RouteGates.QUESTION.y + 8.0
	check(RouteGates.BLOCK_WIDTH < RouteGates.GATE_GAP and under < RouteGates.HERO.y - RouteGates.HERO_HEIGHT, "What stands under the gate turned to keeps within its own gate's room and clear of her (%.0f)" % under)
	check(slab.position.y >= 0.0 and slab.position.x > RouteGates.EDGE + 320.0 and slab.end.x < RouteGates.DESIGN.x - RouteGates.EDGE - RouteGates.STATUS_WIDTH and RouteGates.CARD_GAP > 0.0, "The tablet hangs clear of the chapter's name and her state, its card under it")
	check(RouteGateView.HEIGHT * (1.0 + RouteGateView.GROWTH) * (1.0 + RouteGateView.CREST - RouteGateView.CREST_REST) <= RouteGates.FLOOR - slab.end.y, "A gate turned to, with a crest on its gable, still stands under the tablet")
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
	# Every part of the HUD is on the screen, off the ground round the hero
	# and clear of the others. Which corner each part keeps to follows the
	# genre's arrangement (docs/画面とUI.md 2.3) and is judged on the
	# captures, not here.
	var parts: Array[Control] = [hud.hp_gauge, hud.goal, hud.kills_label, hud.guide, hud.exp_bar, hud.level_label]
	for key: StringName in hud.slots:
		if hud.slots[key].visible:
			parts.append(hud.slots[key])
	check_apart(parts, screen, ring, "With few action slots")
	# One count is not shown twice: while the goal counts the foes, the tally
	# leaves them out; the echo is always there.
	check(hud.echo_row.visible and hud.kills_row.visible == not (hud.goal.visible and area.data.kill_target > 0), "The tally shows the echo, and the foes only when the goal does not count them")
	# The controls are the key guide the other screens use.
	check(hud.guide is KeyGuide and hud.guide.get_child_count() == ActionHud.CONTROLS.size(), "The controls under the fight are a key guide")
	# The health runs inside its painted frame's channel, past the crest.
	var frame_rect := hud.hp_gauge.frame.get_global_rect()
	var fill_rect := hud.hp_bar.get_global_rect()
	check(hud.hp_gauge.frame.texture == ActionHud.HP_FRAME and frame_rect.encloses(fill_rect) and is_equal_approx(fill_rect.position.x - frame_rect.position.x, ActionHud.HP_CAP_LEFT) and is_equal_approx(fill_rect.size.x, ActionHud.BAR_WIDTH), "Health fills the channel of its painted frame")
	# Two skills and the special make five slots, which reach under the
	# centre: the controls give way, whichever device's caps they show, and
	# every part still keeps clear of the others.
	var slam: SkillData = load("res://data/skills/slam.tres")
	var flash: SkillData = load("res://data/skills/thunder_flash.tres")
	var burst: SpecialData = load("res://data/specials/echo_burst.tres")
	area.hero.motor.equip_skills([slam, flash])
	area.hero.equip_special(burst)
	for pad: bool in [false, true]:
		hud.guide.pad = pad
		hud.guide.refresh()
		await settle()
		var all_parts: Array[Control] = [hud.hp_gauge, hud.goal, hud.kills_label, hud.guide, hud.exp_bar, hud.level_label]
		var shown := 0
		for key: StringName in hud.slots:
			if hud.slots[key].visible:
				shown += 1
				all_parts.append(hud.slots[key])
		var device := "a gamepad" if pad else "the keyboard"
		check(shown == ActionHud.SLOTS.size(), "All five action slots show on %s" % device)
		check_apart(all_parts, screen, ring, "With all five action slots on %s" % device)
	hud.guide.pad = false
	hud.guide.refresh()
	# An elite out of view is pointed at from the frame kept clear of the
	# HUD; one in view, and the crowd of a field, are not.
	var brute_data: FoeData = load("res://data/foes/raging_charger.tres")
	var far_elite := area.spawn_foe(brute_data, area.hero.global_position + Vector2(2000, 900))
	var near_elite := area.spawn_foe(brute_data, area.hero.global_position + Vector2(200, 0))
	await settle()
	var arrow_at := hud.pointer_spot(far_elite.global_position)
	var middle := screen.get_center().x
	var clear_frame := Rect2(ActionHud.POINTER_INSET.x - 1.0, ActionHud.POINTER_TOP - 1.0, screen.size.x - ActionHud.POINTER_INSET.x * 2.0 + 2.0, screen.size.y - ActionHud.POINTER_TOP - ActionHud.POINTER_BOTTOM + 2.0)
	check(hud.pointer_targets().has(far_elite) and arrow_at != Vector2.INF and clear_frame.has_point(arrow_at) and arrow_at.x > middle, "An elite out of view is pointed at from the edge of the ground kept clear")
	check(hud.pointer_spot(near_elite.global_position) == Vector2.INF, "One in view needs no arrow")
	check(hud.pointer_targets().all(func(foe: Foe) -> bool: return foe.data.elite or foe.data.boss), "A field's crowd is not pointed at")
	far_elite.vanish()
	near_elite.vanish()
	# The level-up cards and the menu over the fight.
	area._on_gems(area.run.progression.required_exp())
	await settle(0.4)
	on_screen(area.choice.get_node("Panel"), "The level-up cards")
	area.choice._select(0)
	await settle()
	var taken := area.run.build.owned()
	check(hud.boons.get_child_count() == 1 and (hud.boons.get_child(0) as TextureRect).texture == EmblemIcons.texture(taken[0].emblem), "The boon taken shows as its emblem")
	check(screen.grow(-4).encloses(hud.boons.get_global_rect()) and not hud.boons.get_global_rect().intersects(ring) and not hud.boons.get_global_rect().intersects(hud.goal.get_global_rect()), "The boons keep on the screen, off the hero's ground and clear of the goal")
	area.open_menu()
	await settle(0.3)
	var menu_panel: Control = area.menu.menu.get_child(0)
	on_screen(menu_panel, "The fight's menu")
	check(area.menu.build_panel.visible and area.menu.build_grid.get_child_count() == area.run.build.owned().size(), "Beside the menu, every boon of the build is in the grid")
	var first_boon: BoonData = area.run.build.owned()[0]
	var cells := area.menu.build_grid.get_children()
	check(area.menu.build_name.text == first_boon.display_name and area.menu.build_note.text == first_boon.effect_description(area.run.build.rank(first_boon.id)), "What a boon is and does is told once, under the grid")
	check(area.menu.resume_button.get_node_or_null(area.menu.resume_button.focus_neighbor_left) == cells[0] and (cells[0] as Button).focus_mode == Control.FOCUS_ALL and (cells[0] as Button).get_node_or_null((cells[0] as Button).focus_neighbor_right) == area.menu.resume_button, "Left from the menu reaches the build and right comes back")
	# Kept on purpose: on 2026-11-10 the user agreed that the things in one
	# group align on one line, and that the menu's stacked buttons spread
	# their letters to one width (no more than a letter between letters). So
	# the menu's column stands on one axis: the heading, the buttons and the
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
	# A short word spreads no further than a letter between letters.
	var short_word: JustifiedButton = area.menu.settings_button
	var letter := float(short_word.get_theme_font_size(&"font_size"))
	check(short_word.gap() <= letter * JustifiedButton.MAX_GAP_EMS + 0.01 and short_word.drawn_width() < widest and is_equal_approx(area.menu.resume_button.drawn_width(), widest), "A short word keeps its letters within a letter of each other")
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
	on_screen(menu_panel, "The fight's menu with every boon")
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
	on_screen(run.end_view._panel, "The result")
	print("UI layout: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
