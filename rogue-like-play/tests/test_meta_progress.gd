extends SceneTree

# Lasting progress between runs: the upgrades (prices, ranks, what a run
# gets from them), a run's result recorded, the version 5 save written and
# read back, an old turn-based save brought in (its echo, its monsters, the
# old file kept), damaged data refused, an unreadable save protected and
# saving stopped, and a run director starting with the upgrades.

var failures := 0
var checks := 0
var folder := ""


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func store_at(name: String) -> MetaStore:
	var store := MetaStore.new()
	store.path = folder + "/" + name + ".json"
	return store


func run_tests() -> void:
	folder = "res://.godot/meta-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))

	# The upgrade tree: one root, every other node grows from one in the tree,
	# no two share a cell, and the seals keep their cells free.
	check(MetaProgress.UPGRADES.size() == 29, "The root, ten body nodes, eight growth nodes, four skill nodes, four special nodes and two weapon nodes")
	var cells := {}
	var roots := 0
	var grown := true
	for upgrade in MetaProgress.UPGRADES:
		cells[upgrade.cell] = true
		if upgrade.parent.is_empty():
			roots += 1
		else:
			grown = grown and MetaProgress.find(upgrade.parent) != null and upgrade.branch in [&"body", &"growth", &"skill", &"special", &"weapon"]
	for seal: Array in MetaUpgradePage.SEALS:
		cells[seal[1]] = true
	check(roots == 1 and MetaProgress.find(MetaProgress.ROOT).parent.is_empty() and grown, "One root, and every node grows from another in a branch")
	check(cells.size() == MetaProgress.UPGRADES.size() + MetaUpgradePage.SEALS.size(), "No two nodes share a cell")
	var meta := MetaProgress.new()
	var body := MetaProgress.find(&"sturdy_body")
	check(not meta.can_buy(&"sturdy_body") and not meta.buy(&"sturdy_body"), "Nothing is bought without echo")
	meta.echo = 1000
	check(not meta.unlocked(&"sturdy_body") and not meta.buy(&"sturdy_body") and meta.echo == 1000, "A node waits for the one it grows from")
	check(meta.buy(MetaProgress.ROOT) and meta.unlocked(&"sturdy_body") and not meta.unlocked(&"firm_guard"), "The root opens the first nodes of its branches only")
	meta.echo = 1000
	check(meta.buy(&"sturdy_body") and meta.rank(&"sturdy_body") == 1 and meta.echo == 1000 - body.costs[0], "Buying a rank spends its price")
	check(meta.unlocked(&"firm_guard") and meta.unlocked(&"double_dash"), "A first rank is enough to open what grows from it")
	meta.buy(&"sturdy_body")
	meta.buy(&"sturdy_body")
	check(meta.rank(&"sturdy_body") == body.max_rank() and not meta.buy(&"sturdy_body"), "An upgrade stops at its last rank")
	check(not meta.buy(&"no_such_upgrade"), "An unknown upgrade cannot be bought")
	var base: HeroTuning = load("res://data/hero/mio.tres")
	var tuned := meta.tuning(base)
	check(tuned.max_hp == base.max_hp + 45 and tuned != base and base.max_hp == 100, "The run's tuning gains the health; the data is untouched")
	check(not meta.starts_with_boon(), "Without the blessing a run starts bare")
	meta.echo = 1000
	meta.buy(&"double_dash")
	meta.buy(&"parting_blessing")
	check(meta.tuning(base).dash_charges == base.dash_charges + 1 and meta.starts_with_boon(), "The double dash and the blessing take effect")
	check(body.figure_line(0) == "習得すると　最大HP 115" and body.figure_line(1) == "最大HP 115 → 130" and body.figure_line(3) == "最大HP 145", "The figure tells the first rank, now and next, and the last")
	check(MetaProgress.find(&"dash_recovery").figure_line(1) == "ダッシュの再使用 0.4 → 0.35秒", "A falling figure reads plainly")

	# Every node held: the tuning and the run's rules.
	var full := MetaProgress.new()
	for upgrade in MetaProgress.UPGRADES:
		full.ranks[String(upgrade.id)] = upgrade.max_rank()
	var strong := full.tuning(base)
	check(strong.defense == base.defense + 2 and is_equal_approx(strong.hurt_mercy, base.hurt_mercy + 0.2), "Guard and recovery reach her tuning")
	check(strong.dash_charges == base.dash_charges + 2 and is_equal_approx(strong.dash_cooldown, base.dash_cooldown - 0.1), "Three dashes, coming back sooner")
	check(is_equal_approx(strong.max_speed, base.max_speed * 1.1), "Light steps quicken her")
	var rules := full.lasting()
	check(is_equal_approx(rules[&"echo_rate"], 0.1) and rules[&"last_stand"] == 1.0 and is_equal_approx(rules[&"heal_share"], 0.1) and rules[&"gem_pull"] == 40.0, "The body's rules are the run's")
	check(is_equal_approx(rules[&"exp_rate"], 0.2) and rules[&"reroll"] == 2.0 and rules[&"offer_count"] == 1.0, "So are growth's choices")
	check(is_equal_approx(rules[&"level_heal"], 0.1) and rules[&"level_burst"] == 80.0 and rules[&"level_ward"] == 1.5 and is_equal_approx(rules[&"level_haste"], 0.15), "And its level-up moments")

	# A run with the rules: experience, echo, cards and rerolls.
	var lasting_run := RunState.new(9)
	lasting_run.use_lasting(rules)
	check(lasting_run.offer_count() == 4 and lasting_run.rerolls_left == 2 and lasting_run.last_stands == 1, "The run holds four cards, two rerolls and a last stand")
	check(lasting_run.echo_reward(60) == 66, "An echo reward grows with the lantern")
	for gem in 5:
		lasting_run.gain(1)
	check(lasting_run.progression.exp == 6, "Experience owed below a whole point is kept for the next gem")
	check(lasting_run.reroll().size() == 4 and lasting_run.reroll().size() == 4 and lasting_run.reroll().is_empty() and lasting_run.rerolls_left == 0, "Rerolls draw four again until they run out")

	# The last stand and a shield, as the hero's health settles them.
	var health := Combatant.new(20, 0, 0.8)
	health.last_stands = 1
	var stood := [0]
	health.stood.connect(func(): stood[0] += 1)
	var blow := DamageInfo.make(50.0, Vector2.RIGHT, 0.0, null)
	check(health.take(blow) == 19 and health.hp == 1 and health.alive() and stood[0] == 1 and health.protected(), "A felling blow leaves her at 1, untouchable")
	health.step(1.1)
	check(health.take(blow) == 1 and not health.alive(), "Only once")
	var guarded := Combatant.new(20, 0, 0.8)
	guarded.shield(1.5)
	guarded.step(1.4)
	check(guarded.take(blow) == 0, "A shield keeps her untouchable for its time")

	# A stat raised for a while.
	var timed := BuildState.new([])
	timed.boost(&"attack_speed", 0.15, 10.0)
	check(is_equal_approx(timed.stat(&"attack_speed"), 0.15), "A boost raises the stat")
	timed.step(10.01)
	check(timed.stat(&"attack_speed") == 0.0, "And ends on time")

	# The skill slots: a held skill set, moved to the other slot (changing
	# places), cleared; one not held or out of range refused.
	var kit := MetaProgress.new()
	check(kit.loadout == MetaProgress.DEFAULT_LOADOUT and kit.equipped_skills()[0] == MetaProgress.find_skill(&"slam") and kit.equipped_skills()[1] == null, "A new player has the slam in the first slot")
	check(kit.equip(1, &"slam") and kit.loadout == [&"", &"slam"], "Setting it in the other slot moves it there")
	check(kit.equip(0, &"slam") and kit.loadout == [&"slam", &""], "And back")
	check(not kit.equip(0, &"no_such_skill") and not kit.equip(2, &"slam") and kit.loadout == [&"slam", &""], "An unknown skill or slot is refused")
	check(kit.equip(0, &"") and kit.loadout == [&"", &""] and kit.equipped_skills() == [null, null], "A slot can be cleared")
	check(not kit.owns_skill(&"thunder_flash") and not kit.equip(1, &"thunder_flash"), "A skill not learned cannot be set")
	kit.ranks[String(MetaProgress.ROOT)] = 1
	kit.ranks["learn_thunder_flash"] = 1
	check(kit.owns_skill(&"thunder_flash") and kit.equip(1, &"thunder_flash") and kit.loadout == [&"", &"thunder_flash"], "Learned on the skill branch, it can")
	check(MetaCodec.decode(MetaCodec.encode(kit)).loadout == [&"", &"thunder_flash"], "A learned skill in a slot reads back")
	# The special moves: learned on the special branch, the first goes
	# straight into its empty slot; set, swapped, cleared, refused when not
	# learned; read back from a save, and a save from before it has none.
	var arts := MetaProgress.new()
	check(not arts.owns_any_special() and arts.equipped_special() == null and not arts.equip(MetaProgress.SPECIAL_SLOT, &"echo_burst"), "A new player has no special move and cannot set one")
	arts.echo = 3000
	check(arts.buy(MetaProgress.ROOT) and arts.buy(&"learn_echo_burst") and arts.special == &"echo_burst" and arts.equipped_special() == MetaProgress.find_special(&"echo_burst"), "Learning the first special move sets it in its slot")
	check(arts.buy(&"learn_sky_rend") and arts.special == &"echo_burst", "A second one learned does not take its place")
	check(arts.equip(MetaProgress.SPECIAL_SLOT, &"sky_rend") and arts.special == &"sky_rend" and arts.loadout == MetaProgress.DEFAULT_LOADOUT, "It can be swapped, the skill slots left alone")
	check(MetaCodec.decode(JSON.parse_string(JSON.stringify(MetaCodec.encode(arts)))).special == &"sky_rend", "The special slot reads back")
	var unlearned := MetaCodec.encode(MetaProgress.new())
	unlearned.special = "sky_rend"
	check(MetaCodec.decode(unlearned) == null, "A special move not learned is refused in a save")
	var before_specials := MetaCodec.encode(MetaProgress.new())
	before_specials.erase("special")
	check(MetaCodec.decode(before_specials) != null and MetaCodec.decode(before_specials).special == &"", "A save from before the special slot has it empty")
	check(arts.equip(MetaProgress.SPECIAL_SLOT, &"") and arts.equipped_special() == null, "The special slot can be cleared")
	check(arts.buy(&"special_surge") and arts.buy(&"special_mastery") and is_equal_approx(arts.lasting()[&"special_charge"], 0.2) and is_equal_approx(arts.lasting()[&"special_power"], 0.25), "The branch's upgrades fill the gauge faster and strike harder")
	# The weapons: the sword from the start, the others learned on the
	# weapon branch; the attack slot holds one, read back from a save, and a
	# save from before it holds the sword.
	var armory := MetaProgress.new()
	check(armory.weapon == &"sword" and armory.equipped_weapon() == MetaProgress.WEAPONS[0] and not armory.owns_weapon(&"spear"), "A new player holds the sword only")
	check(not armory.equip(MetaProgress.WEAPON_SLOT, &"spear") and not armory.equip(MetaProgress.WEAPON_SLOT, &"no_such_weapon"), "A weapon not learned, or unknown, cannot be held")
	armory.ranks[String(MetaProgress.ROOT)] = 1
	armory.ranks["learn_spear"] = 1
	check(armory.owns_weapon(&"spear") and not armory.owns_weapon(&"hammer") and armory.equip(MetaProgress.WEAPON_SLOT, &"spear") and armory.equipped_weapon().id == &"spear", "Learned on the weapon branch, the spear can be held")
	check(MetaCodec.decode(JSON.parse_string(JSON.stringify(MetaCodec.encode(armory)))).weapon == &"spear", "The attack slot reads back")
	var unarmed := MetaCodec.encode(MetaProgress.new())
	unarmed.weapon = "hammer"
	check(MetaCodec.decode(unarmed) == null, "A weapon not learned is refused in a save")
	var before_weapons := MetaCodec.encode(MetaProgress.new())
	before_weapons.erase("weapon")
	check(MetaCodec.decode(before_weapons).weapon == &"sword", "A save from before the attack slot holds the sword")
	armory.ranks.erase("learn_spear")
	check(armory.equipped_weapon() == MetaProgress.WEAPONS[0], "A weapon no longer held falls back to the sword")
	for weapon in MetaProgress.WEAPONS:
		check(not weapon.id.is_empty() and not weapon.description.is_empty() and weapon.combo.size() >= 2 and weapon.charged != null and EmblemIcons.texture(weapon.emblem) != null, "%s is a whole weapon" % weapon.id)
		check(weapon.owned_from_start == (weapon.id == &"sword") and (weapon.art != null) == (weapon.id != &"sword"), "%s: only the sword is held from the start, and keeps the rig's own picture" % weapon.id)
	var drilled := RunState.new(1)
	kit.ranks["skill_drill"] = 2
	drilled.use_lasting(kit.lasting())
	check(is_equal_approx(drilled.build.stat(&"skill_cooldown"), -0.2), "The drill shortens the run's skills as a boon would")

	# A run's result recorded.
	var record := MetaProgress.new()
	record.record_run({"cleared": false, "layer": 1, "echo": 70, "met": [&"wandering_sentinel"]})
	record.record_run({"cleared": true, "layer": 3, "echo": 210, "met": [&"ruin_king"]})
	check(record.echo == 280 and record.runs == 2 and record.clears == 1 and record.best_layer == 4, "Results add echo, runs, clears and the deepest layer")
	check(record.has_met(&"wandering_sentinel") and record.has_met(&"ruin_king"), "The foes met are remembered")
	# The chapters: each keeps its own record, and the first clear of one
	# opens the next; a save keeps them, and one from before gives its record
	# to the first chapter.
	var woods: ChapterData = Chapters.find(&"gale_woods")
	var journey := MetaProgress.new()
	check(journey.chapter_open(Chapters.ALL[0]) and not journey.chapter_open(woods), "The second chapter is sealed at first")
	journey.record_run({"cleared": false, "layer": 2, "chapter_id": "ash_corridor"})
	check(not journey.chapter_open(woods) and journey.best_of(&"ash_corridor") == 3 and journey.best_of(&"gale_woods") == 0, "A run that falls opens nothing, and is the first chapter's record")
	journey.record_run({"cleared": true, "layer": 3, "chapter_id": "ash_corridor"})
	check(journey.chapter_open(woods) and journey.clears_of(&"ash_corridor") == 1, "Clearing the first chapter opens the second")
	journey.record_run({"cleared": false, "layer": 1, "chapter_id": "gale_woods"})
	check(journey.best_of(&"gale_woods") == 2 and journey.best_of(&"ash_corridor") == 4 and journey.clears == 1 and journey.runs == 3, "Each chapter keeps its own deepest layer; the totals count every run")
	var journey_back := MetaCodec.decode(JSON.parse_string(JSON.stringify(MetaCodec.encode(journey))))
	check(journey_back.clears_of(&"ash_corridor") == 1 and journey_back.best_of(&"gale_woods") == 2 and journey_back.chapter_open(woods), "The chapters' records read back")
	var before_chapters := MetaCodec.encode(record)
	before_chapters.erase("chapters")
	var carried := MetaCodec.decode(before_chapters)
	check(carried.clears_of(&"ash_corridor") == 1 and carried.best_of(&"ash_corridor") == 4 and carried.chapter_open(woods), "A save from before the chapters gives its record to the first")
	var strange := MetaCodec.encode(journey)
	strange.chapters = {"no_such_chapter": {"clears": 1, "best": 1}}
	check(MetaCodec.decode(strange) == null, "An unknown chapter in a save is refused")

	# Version 5 written and read back.
	var data := MetaCodec.encode(meta)
	var back := MetaCodec.decode(JSON.parse_string(JSON.stringify(data)))
	check(back != null and back.echo == meta.echo and back.ranks == meta.ranks and back.runs == meta.runs, "A save reads back as it was written")
	var broken: Dictionary = data.duplicate(true)
	broken.ranks = {"sturdy_body": 9}
	check(MetaCodec.decode(broken) == null, "A rank past the last is refused")
	broken = data.duplicate(true)
	broken.echo = -5
	check(MetaCodec.decode(broken) == null, "Negative echo is refused")
	broken = data.duplicate(true)
	broken.ranks = {"vitality": 1}
	check(MetaCodec.decode(broken) == null, "An unknown upgrade is refused")
	meta.equip(1, &"slam")
	var kept_loadout := MetaCodec.decode(JSON.parse_string(JSON.stringify(MetaCodec.encode(meta))))
	check(kept_loadout != null and kept_loadout.loadout == [&"", &"slam"], "The skill slots read back as they were saved")
	meta.equip(0, &"slam")
	data = MetaCodec.encode(meta)
	var slotless: Dictionary = data.duplicate(true)
	slotless.erase("loadout")
	check(MetaCodec.decode(slotless).loadout == MetaProgress.DEFAULT_LOADOUT, "A save from before the slots keeps the new player's")
	for wrong: Variant in [["slam", "slam"], ["slam"], ["bogus", ""], "slam"]:
		var damaged: Dictionary = data.duplicate(true)
		damaged.loadout = wrong
		check(MetaCodec.decode(damaged) == null, "A loadout that does not hold together is refused: %s" % str(wrong))
	var rootless: Dictionary = data.duplicate(true)
	rootless.ranks = {"double_dash": 1}
	var grown_back := MetaCodec.decode(rootless)
	check(grown_back != null and grown_back.rank(MetaProgress.ROOT) == 1 and grown_back.rank(&"double_dash") == 1 and grown_back.rank(&"sturdy_body") == 0, "A save from before the root is given it, its upgrades kept")
	rootless.ranks = {}
	check(MetaCodec.decode(rootless).ranks.is_empty(), "A save with nothing bought is not given the root")
	check(MetaCodec.decode({"version": 4, "gold": 10}) == null, "An old save is not read as a new one")

	# An old save brought in.
	var old := {"version": 4, "gold": 400, "hp_upgrade_level": 3, "skills": {"vitality": 2, "attack": 1}, "inventory": [], "equipment": ["weapon_0", null, null, null, null], "met": ["basic", "fast", "summoner"]}
	var spent := 30 + 60 + 90 + (100 + 150) + 100
	var brought := MetaCodec.migrate(old)
	check(brought != null and brought.echo == floori((400 + spent) * MetaCodec.ECHO_PER_GOLD), "An old save's Gold and Gold spent on upgrades become echo")
	check(brought.has_met(&"wandering_sentinel") and brought.has_met(&"dashing_rat") and brought.met.size() == 2, "Old monsters carry over where a new foe wears their picture")
	check(brought.ranks.is_empty() and brought.runs == 0, "Nothing else carries over")
	var legacy := MetaCodec.migrate({"version": 2, "gold": 0, "hp_upgrade_level": 3, "skills": {"vitality": 7}})
	var legacy_spent := 180
	for rank in 7:
		legacy_spent += 100 + rank * 50
	check(legacy != null and legacy.echo == floori(legacy_spent * MetaCodec.ECHO_PER_GOLD), "A branch saved before the tiers is priced along its whole sequence")
	check(MetaCodec.migrate({"version": 3, "gold": 10, "skills": {"bogus": 1}}) == null, "An old save that does not hold together is refused")

	# The store: a new player, a save, and its backup.
	var store := store_at("fresh")
	var fresh := store.load_progress()
	check(fresh.echo == 0 and not store.blocked and not store.alert, "No save starts fresh")
	fresh.echo = 120
	check(store.save_progress(fresh) and FileAccess.file_exists(store.path), "Progress is saved")
	fresh.echo = 50
	store.save_progress(fresh)
	check(FileAccess.file_exists(store.path + ".bak") and store_at("fresh").load_progress().echo == 50, "The newest save is read, the one before kept as backup")

	# An old save in place: brought in, and kept aside at the first save.
	store = store_at("old")
	write(store.path, JSON.stringify(old))
	var loaded := store.load_progress()
	check(store.migrated and store.alert and loaded.echo == brought.echo, "Loading an old save brings it in and says so")
	check(store.save_progress(loaded) and FileAccess.file_exists(store.path + ".v4"), "The first save keeps the old file aside")
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.path + ".v4"))
	check(kept is Dictionary and int(kept.version) == 4 and int(kept.gold) == 400, "The kept file is the old save, untouched")
	check(MetaCodec.version_of(JSON.parse_string(FileAccess.get_file_as_string(store.path))) == MetaCodec.VERSION and not store.migrated, "The save is now version 5")
	loaded.echo += 1
	store.save_progress(loaded)
	kept = JSON.parse_string(FileAccess.get_file_as_string(store.path + ".v4"))
	check(int(kept.version) == 4, "Later saves leave the kept file alone")

	# An unreadable save: protected, and saving stops.
	store = store_at("damaged")
	write(store.path, "{ not json")
	var damaged := store.load_progress()
	check(store.blocked and store.alert and damaged.echo == 0, "An unreadable save stops saving")
	check(not store.save_progress(damaged) and FileAccess.get_file_as_string(store.path) == "{ not json", "The unreadable file is left as it was")
	store = store_at("future")
	write(store.path, JSON.stringify({"version": 99, "echo": 5}))
	store.load_progress()
	check(store.blocked, "A save from a later version is not overwritten")

	# A run director given the base's progress.
	var director := RunDirector.new()
	director.seed_value = 5
	director.meta = meta
	root.add_child(director)
	await process_frame
	check(director.max_hp() == base.max_hp + 45 and director.run.tuning.dash_charges == base.dash_charges + 1, "A run starts with the lasting upgrades")
	check(director.map_view.visible and not director.choice.visible, "The run opens on its map, the blessing still to come")
	var first: RouteMap.Waypoint = director.run.route.nodes(0)[0]
	director.map_view._choose(first)
	await process_frame
	check(director.choice.visible and director.area == null, "Picking the first area offers the blessing before entering it")
	director.choice._select(0)
	await process_frame
	check(director.run.build.owned().size() == 1 and director.area != null and director.waypoint == first, "The blessing's boon is taken and the area picked is entered")
	check(director.area.hero.health.max_hp == base.max_hp + 45 and director.area.hero.motor.dash_charges == base.dash_charges + 1, "She fights with them")
	var slam: SkillData = MetaProgress.find_skill(&"slam")
	check(director.area.hero.motor.skill_attacks == [slam.attack, null] and director.area.hero.motor.skill_cooldowns[0] == slam.cooldown, "And with the skills in her slots")
	director.free()
	await process_frame

	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + name)
	DirAccess.remove_absolute(folder)
	print("Meta progress tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
