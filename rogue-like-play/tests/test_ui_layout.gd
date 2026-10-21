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
	for page in ["upgrade", "codex", "settings"]:
		hub.show_page(page)
		# Measure the resting layout, after the page has slid into place.
		await settle(UIMotion.WINDOW_TIME + 0.05)
		var shown: Control = {"upgrade": hub.upgrade_page, "codex": hub.codex_page, "settings": hub.settings_page}[page]
		check(screen.grow(1).encloses(shown.get_global_rect()), "The %s page stays on the screen" % page)
	hub.show_page("upgrade")
	await settle(UIMotion.WINDOW_TIME + 0.05)
	for button: Button in hub.upgrade_page.buttons:
		check(screen.encloses(button.get_global_rect()), "Every upgrade's action stays on the screen")
	var tops := {}
	for button: Button in hub.upgrade_page.buttons:
		tops[roundi(button.get_global_rect().position.y)] = true
	check(tops.size() == 1, "The upgrades' actions stand in one row")
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
	var panels: Array[Control] = [hud.hp_bar, hud.info, hud.guide, hud.exp_bar, hud.level_label, hud.skill_label]
	for panel in panels:
		check(screen.grow(-4).encloses(panel.get_global_rect()), "%s keeps off the screen's edge" % panel.name)
		check(not panel.get_global_rect().intersects(ring), "%s stays off the ground round the hero" % panel.name)
	check(not hud.hp_bar.get_global_rect().intersects(hud.guide.get_global_rect()) and not hud.info.get_global_rect().intersects(hud.exp_bar.get_global_rect()), "HUD parts do not overlap")
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
