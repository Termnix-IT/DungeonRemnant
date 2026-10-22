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
	check(MetaProgress.UPGRADES.size() == 19, "The root, ten body nodes and eight growth nodes")
	var cells := {}
	var roots := 0
	var grown := true
	for upgrade in MetaProgress.UPGRADES:
		cells[upgrade.cell] = true
		if upgrade.parent.is_empty():
			roots += 1
		else:
			grown = grown and MetaProgress.find(upgrade.parent) != null and upgrade.branch in [&"body", &"growth"]
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

	# A run's result recorded.
	var record := MetaProgress.new()
	record.record_run({"cleared": false, "layer": 1, "echo": 70, "met": [&"wandering_sentinel"]})
	record.record_run({"cleared": true, "layer": 3, "echo": 210, "met": [&"ruin_king"]})
	check(record.echo == 280 and record.runs == 2 and record.clears == 1 and record.best_layer == 4, "Results add echo, runs, clears and the deepest layer")
	check(record.has_met(&"wandering_sentinel") and record.has_met(&"ruin_king"), "The foes met are remembered")

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
	check(director.choice.visible and not director.map_view.visible, "With the blessing a boon is chosen before the map")
	director.choice._select(0)
	await process_frame
	check(director.run.build.owned().size() == 1 and director.map_view.visible, "The blessing's boon is taken and the map opens")
	director.map_view._choose(director.run.route.nodes(0)[0])
	await process_frame
	check(director.area.hero.health.max_hp == base.max_hp + 45 and director.area.hero.motor.dash_charges == base.dash_charges + 1, "She fights with them")
	director.free()
	await process_frame

	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + name)
	DirAccess.remove_absolute(folder)
	print("Meta progress tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
