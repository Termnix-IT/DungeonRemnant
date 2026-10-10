extends SceneTree

# The HUD's weapon row and its notice band: the row shows the weapon the attack
# really uses and follows a swap at once; announcement banners share the band
# at the screen's top edge with the boss gauge, which steps aside while one
# shows, stay off the floor round the hero, and wait for one another.
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
	var row: HudWeapon = hud.weapon
	var vitals: Control = hud.get_node("BottomLeft")
	check(row != null and row.get_parent() == vitals, "The weapon row sits on the vitals plate")
	check(vitals.get_global_rect().encloses(row.get_global_rect()), "The weapon row stays inside the plate")
	var exp_bar: Control = vitals.get_node("ExpBar")
	check(row.get_global_rect().position.y >= exp_bar.get_global_rect().end.y, "The weapon row sits below the EXP bar")
	for node_name in ["Meta", "Gold"]:
		var other: Control = vitals.get_node(node_name)
		check(row.get_global_rect().end.y <= other.get_global_rect().position.y, "The weapon row sits above %s" % node_name)
	# The keys the HUD shows nowhere else stand on the card at the bottom right;
	# Tab stays on the weapon row.
	var keys: Array[String] = hud.actions.keys()
	check("I" in keys and "Space" in keys and not "Tab" in keys, "The actions card names I and Space and leaves Tab to the weapon row")
	check(row.hint._hints.size() == 1 and row.hint.cap_text(row.hint._hints[0]) == "Tab", "The weapon row shows the Tab key that swaps")

	var main: ItemData = player.equipment.slots[Equipment.Slot.MAIN]
	var sub: ItemData = player.equipment.slots[Equipment.Slot.SUB]
	check(row.name_label.text == main.label() and row.main_glyph.item == main and row.sub_glyph.item == sub, "The row shows the main weapon and the other one beside it")
	check(row.range_label.text == "射程 %d" % player.effective_weapon().reach, "The range is the attack's own reach")
	run._on_action("switch", Vector2i.ZERO)
	check(player.equipment.slots[Equipment.Slot.MAIN] == sub, "Tab swaps the weapons")
	check(row.name_label.text == sub.label() and row.main_glyph.item == sub and row.sub_glyph.item == main, "The row follows the swap at once")
	check(row.range_label.text == "射程 %d" % player.effective_weapon().reach and player.effective_weapon().reach == sub.weapon.reach, "The range follows the swap")
	var spear_range: AbilityData
	for ability: AbilityData in player.abilities.definitions:
		if ability.effect == AbilityData.Effect.SPEAR_RANGE:
			spear_range = ability
	if sub.weapon.kind == WeaponData.Kind.SPEAR and spear_range != null:
		player.gain_ability(spear_range)
		run._refresh()
		check(row.range_label.text == "射程 %d" % (sub.weapon.reach + spear_range.amount), "An upgrade's extra reach shows in the range")
	else:
		check(false, "The second starting weapon is a spear with a range upgrade to test")
	player.equipment.slots[Equipment.Slot.SUB] = null
	run._refresh()
	check(row.sub_glyph.item == null and row.tooltip_text.ends_with("副武器：%s" % HudWeapon.EMPTY), "An empty other slot shows as empty")
	hud.show_weapons(null, null, null)
	check(row.name_label.text == HudWeapon.EMPTY and row.range_label.text == "射程 %s" % HudWeapon.EMPTY, "An empty main slot shows a dash")

	# Choosing an attack's direction turns the card into the aim's own and puts
	# a tag over the hero; the log carries no instructions for it.
	player.aiming = true
	run._refresh()
	var hero: Vector2 = player.get_global_transform_with_canvas().origin
	check(hud.actions.aiming and hud.actions.keys() == ["方向", "Space", "Esc"] and hud.actions.title.text == "攻撃の向きを選択中", "Aiming turns the card into the aim's keys")
	check(hud.aim_tag.visible and hud.aim_tag.get_global_rect().end.y <= hero.y and absf(hud.aim_tag.get_global_rect().get_center().x - hero.x) < 2.0, "A tag stands over the hero while aiming")
	check(not hud.log_entries.get_parsed_text().contains("攻撃方向を選択中"), "The log carries no aiming instructions")
	check(hud.actions.theme_type_variation == &"HudPanelActive" and hud.actions.get_theme_stylebox(&"panel") != hud.get_node("BottomLeft").get_theme_stylebox(&"panel"), "The aim's card stands on the gilt plate")
	player.aiming = false
	run._refresh()
	check(not hud.actions.aiming and not hud.aim_tag.visible and "I" in hud.actions.keys(), "Leaving the aim brings the usual keys back")
	check(hud.actions.theme_type_variation == &"HudPanel", "Leaving the aim puts the card back on the usual plate")
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
