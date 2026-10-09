extends SceneTree

# The HUD's weapon row and its notice lane: the row shows the weapon the attack
# really uses and follows a swap at once; announcement banners stay below the
# boss gauge and wait for one another.
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
	for node_name in ["Meta", "Gold", "Hint"]:
		var other: Control = vitals.get_node(node_name)
		check(row.get_global_rect().end.y <= other.get_global_rect().position.y, "The weapon row sits above %s" % node_name)
	var guide: KeyGuide = vitals.get_node("Hint")
	var guide_keys: Array[String] = []
	for hint: Button in guide._hints:
		guide_keys.append(guide.cap_text(hint))
	check(guide_keys == ["I"], "The key guide keeps I and leaves Tab to the weapon row")
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

	var gauge: BossGauge = hud.get_node("Boss")
	var banner = run.journey_banner
	hud.show_boss("遺跡王", 136, 136)
	banner.clear()
	banner.present("モンスターハウス", "敵が密集している。退路を確認しよう。")
	await create_timer(UIMotion.ENTER_TIME + 0.1).timeout
	check(gauge.visible and banner.visible, "The gauge and a banner are both up")
	check(not banner.panel.get_global_rect().intersects(gauge.get_global_rect()), "A banner never covers the boss gauge")
	check(banner.panel.get_global_rect().position.y >= gauge.get_global_rect().end.y, "Banners run in the lane below the gauge")
	banner.present("1F  ·  探索開始", "古代遺跡")
	check(banner.title_label.text == "モンスターハウス" and banner.announces("1F  ·  探索開始"), "A second cue waits instead of covering the first")
	banner.present("1F  ·  探索開始", "古代遺跡")
	check(banner.queue.size() == 1, "The same cue waits only once")
	banner.lifetime.timeout.emit()
	check(banner.visible and banner.title_label.text == "1F  ·  探索開始" and banner.queue.is_empty(), "The waiting cue follows when the first ends")
	check(not banner.panel.get_global_rect().intersects(gauge.get_global_rect()), "The next cue keeps to the same lane")
	banner.present("モンスターハウス")
	banner.clear()
	check(not banner.visible and banner.queue.is_empty(), "Clear drops waiting cues too")
	run.free()
	await process_frame
	print("HUD weapon: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
