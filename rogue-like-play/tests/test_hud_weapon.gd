extends SceneTree

# The HUD's vitals plate, its actions card and its notice band: the plate keeps
# the face, the inventory count, the level with the two weapons and its bar,
# HP and MP, the card names the weapon swap with the other keys, and the
# turn, Gold and EXP figures stay in the inventory; banners
# share the band at the screen's top edge with the boss gauge, which steps
# aside while one shows, stay off the floor round the hero, and wait for one
# another.
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
	var run = preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	root.add_child(run)
	await process_frame
	var hud = run.hud
	var player: Node2D = run.turns.player
	var vitals: Control = hud.get_node("BottomLeft")
	# The vitals plate: no turn or Gold line and no EXP figures; those are read
	# in the inventory, not glanced at.
	for node_name in ["Meta", "Gold", "ExpValue"]:
		check(vitals.get_node_or_null(node_name) == null, "The vitals plate has no %s" % node_name)
	# Only the map keeps a frame; the rest stand on the floor, uncaptioned.
	check(not (vitals is Panel) and not (hud.get_node("Log") is Panel) and not (hud.actions is Panel) and hud.get_node("TopRight") is Panel, "Only the map keeps a frame")
	check(hud.get_node("Log").find_children("*", "Label", false, false).is_empty(), "The log has no caption")
	var mp_bar: Control = vitals.get_node("MpBar")
	check(vitals.get_global_rect().encloses(mp_bar.get_global_rect()) and vitals.get_global_rect().end.y - mp_bar.get_global_rect().end.y < 24.0, "The plate ends just under the MP bar")
	run._refresh()
	check(hud.items_value.text == "%d / %d" % [player.inventory.entries.size(), player.inventory.max_entries], "The plate counts the pack's slots: " + hud.items_value.text)
	# The keys the HUD shows nowhere else stand on the card at the top left,
	# the weapon swap among them.
	var keys: Array[String] = hud.actions.keys()
	check("I" in keys and "Space" in keys and "Tab" in keys, "The actions card names I, Space and Tab")
	var screen: Rect2 = hud.get_viewport().get_visible_rect()
	check(hud.actions.get_global_rect().position.is_equal_approx(Vector2.ONE * HudActions.MARGIN) and hud.actions.get_global_rect().end.y < screen.size.y * 0.5, "The actions card stands at the top left")
	var main: ItemData = player.equipment.slots[Equipment.Slot.MAIN]
	var sub: ItemData = player.equipment.slots[Equipment.Slot.SUB]
	check(hud.weapons.held == main and hud.weapons.spare == sub, "Beside the level, the weapon in hand comes first and the other second")
	run._on_action("switch", Vector2i.ZERO)
	check(player.equipment.slots[Equipment.Slot.MAIN] == sub and player.equipment.slots[Equipment.Slot.SUB] == main, "Tab swaps the weapons")
	run._refresh()
	check(hud.weapons.held == sub and hud.weapons.spare == main, "The swap puts the other weapon in the gold box")
	# The run's figures stand in the inventory's header instead.
	run._refresh()
	var record: String = run.inventory_panel.record_label.text
	check(record.contains("Lv 1") and record.contains("EXP 0 / ") and record.contains("TURN %d" % run.turns.turn_count) and record.contains("%s G" % UIFormat.amount(run.turns.gold)), "The inventory's header carries Lv, EXP, the turn and Gold")

	# Choosing an attack's direction turns the card into the aim's own and puts
	# a tag over the hero; the log carries no instructions for it.
	player.aiming = true
	run._refresh()
	var hero: Vector2 = player.get_global_transform_with_canvas().origin
	check(hud.actions.aiming and hud.actions.keys() == ["方向", "Space", "Esc"] and hud.actions.title.text == "攻撃の向きを選択中", "Aiming turns the card into the aim's keys")
	check(hud.aim_tag.visible and hud.aim_tag.get_global_rect().end.y <= hero.y and absf(hud.aim_tag.get_global_rect().get_center().x - hero.x) < 2.0, "A tag stands over the hero while aiming")
	check(not hud.log_entries.get_parsed_text().contains("攻撃方向を選択中"), "The log carries no aiming instructions")
	check(hud.actions.title.visible and hud.actions.title.theme_type_variation == &"HudGoldCaption", "The aim's card is titled in gold")
	player.aiming = false
	run._refresh()
	check(not hud.actions.aiming and not hud.aim_tag.visible and "I" in hud.actions.keys(), "Leaving the aim brings the usual keys back")
	check(not hud.actions.title.visible, "Out of the aim the card has no title")
	# Each log entry leads with the mark of its kind of news; harm outranks the
	# rest of a turn that also dealt a blow.
	var marks := {
		"5Fに到着した。": &"floor",
		"ネズミに3ダメージ、ネズミを倒した。 EXP +2 / Gold +1。": &"victory",
		"ネズミに3ダメージ。 疾走ネズミの攻撃で1ダメージ。": &"harm",
		"回復薬を使った。HPが8回復。": &"supply",
		"攻撃は空を切った。": &"news",
	}
	for text: String in marks:
		check(hud.log_mark(text) == marks[text], "The log marks %s as %s" % [text, marks[text]])
	for kind: StringName in [&"victory", &"harm", &"floor", &"supply", &"news"]:
		check(hud.log_entries.has_theme_icon(kind, &"HudLog"), "The theme paints the %s mark" % kind)
	check(not hud.log_entries.get_parsed_text().contains("◇"), "Log entries lead with marks, not drawn diamonds")
	check(hud.get_viewport().get_visible_rect().encloses(hud.actions.get_global_rect()), "The card stays on the screen")
	# News brings the log to full strength and then lets it rest.
	hud._freshen_log()
	check(is_equal_approx(hud.get_node("Log").modulate.a, 1.0) and not hud._log_rest.is_stopped(), "News brings the log up and starts its rest")

	var gauge: BossGauge = hud.get_node("Boss")
	var banner = run.journey_banner
	hud.show_boss("遺跡王", 136, 136)
	banner.clear()
	banner.present("モンスターハウス", "敵が密集している。退路を確認しよう。")
	await create_timer(UIMotion.ENTER_TIME + 0.1).timeout
	check(banner.visible and is_zero_approx(gauge.modulate.a), "While a banner shows in the top band, the boss gauge steps aside")
	var hero_top: float = player.get_global_transform_with_canvas().origin.y - 36.0 - 72.0 * 4.0
	check(banner.panel.get_global_rect().end.y <= hero_top, "Banners stay above the four rows of floor north of the hero")
	banner.present("1F  ·  探索開始", "古代遺跡")
	check(banner.title_label.text == "モンスターハウス" and banner.announces("1F  ·  探索開始"), "A second cue waits instead of covering the first")
	banner.present("1F  ·  探索開始", "古代遺跡")
	check(banner.queue.size() == 1, "The same cue waits only once")
	banner.lifetime.timeout.emit()
	check(banner.visible and banner.title_label.text == "1F  ·  探索開始" and banner.queue.is_empty(), "The waiting cue follows when the first ends")
	await create_timer(UIMotion.ENTER_TIME + 0.1).timeout
	check(banner.panel.get_global_rect().end.y <= hero_top, "The next cue keeps to the same band once it has settled")
	banner.present("モンスターハウス")
	banner.clear()
	check(not banner.visible and banner.queue.is_empty(), "Clear drops waiting cues too")
	check(is_equal_approx(gauge.modulate.a, 1.0), "With no banner the boss gauge stands again")
	run.free()
	await process_frame
	print("HUD weapon: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
