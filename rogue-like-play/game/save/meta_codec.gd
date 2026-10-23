class_name MetaCodec
extends RefCounted

# MetaProgress to and from the save's JSON (version 5), and the way in from
# the turn-based game's saves (versions 1 to 4). An old save keeps its worth:
# its Gold, and the Gold spent on its lasting upgrades (worked out from the
# old prices, kept here so they outlive the old game's data), become echo at
# ECHO_PER_GOLD; its items and floors have nothing to become and are left
# behind (the old file itself is kept beside the new one by MetaStore). The
# old monsters met carry over where a new foe wears the same picture. A
# version 5 save from before the upgrade tree had its root is given the root,
# so the upgrades it holds keep growing; one from before the skill slots
# keeps the new player's; one from before the chapters' own records gives
# its record to the first chapter.

const VERSION := 5
const MAX_COUNT := 1000000
const MAX_MET := 512
const ECHO_PER_GOLD := 0.25
# The old lasting upgrades: base health ranks cost these in turn...
const OLD_HP_COSTS: Array[int] = [30, 60, 90]
# ...and each skill tier's rank r cost base + r * step (id: [base, step]).
# Before version 4 a branch was one id holding all its tiers' ranks; the
# tiers continue one price sequence, so the first tier's numbers price it.
const OLD_SKILLS := {
	"vitality": [100, 50], "vitality_2": [350, 50], "vitality_3": [600, 50], "vitality_4": [850, 50],
	"attack": [100, 60], "attack_2": [400, 60], "attack_3": [700, 60], "attack_4": [1000, 60],
	"mana": [80, 40], "mana_2": [240, 40], "mana_3": [360, 40],
	"defense": [150, 90], "defense_2": [510, 90], "defense_3": [780, 90],
}
const OLD_RANK_CAP := 20
# Old monster pictures (EnemySprites.visual_id) to the foes that wear them.
const OLD_MET := {"basic": "wandering_sentinel", "fast": "dashing_rat", "charge": "raging_charger", "boss_ruin_king": "ruin_king"}


static func encode(meta: MetaProgress) -> Dictionary:
	var met: Array = []
	for id: StringName in meta.met:
		met.append(String(id))
	met.sort()
	var loadout: Array = []
	for id in meta.loadout:
		loadout.append(String(id))
	return {"version": VERSION, "echo": meta.echo, "ranks": meta.ranks.duplicate(), "runs": meta.runs,
		"clears": meta.clears, "best_layer": meta.best_layer, "met": met, "loadout": loadout, "special": String(meta.special),
		"chapters": _chapters_of(meta)}


static func _chapters_of(meta: MetaProgress) -> Dictionary:
	var chapters := {}
	for id: StringName in meta.chapter_clears.keys() + meta.chapter_best.keys():
		chapters[String(id)] = {"clears": meta.clears_of(id), "best": meta.best_of(id)}
	return chapters


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


# The version a save says it is, or 0 when it is not a save at all.
static func version_of(data: Variant) -> int:
	if not data is Dictionary or not integer(data.get("version"), 1, 1000):
		return 0
	return int(data.version)


# A version 5 save, or null when it does not hold together.
static func decode(data: Variant) -> MetaProgress:
	if version_of(data) != VERSION:
		return null
	var meta := MetaProgress.new()
	if not integer(data.get("echo"), 0, MetaProgress.MAX_ECHO):
		return null
	meta.echo = int(data.echo)
	for field in ["runs", "clears", "best_layer"]:
		if not integer(data.get(field, 0), 0, MAX_COUNT):
			return null
	meta.runs = int(data.get("runs", 0))
	meta.clears = int(data.get("clears", 0))
	meta.best_layer = int(data.get("best_layer", 0))
	var ranks: Variant = data.get("ranks", {})
	if not ranks is Dictionary:
		return null
	for id: Variant in ranks:
		var upgrade := MetaProgress.find(StringName(str(id)))
		if not id is String or upgrade == null or not integer(ranks[id], 0, upgrade.max_rank()):
			return null
		meta.ranks[id] = int(ranks[id])
	# Saved before the tree had its root: what was bought grows from it.
	if meta.rank(MetaProgress.ROOT) == 0 and meta.ranks.values().any(func(held: int): return held > 0):
		meta.ranks[String(MetaProgress.ROOT)] = 1
	if not _read_met(data.get("met", []), meta, {}):
		return null
	if data.has("loadout") and not _read_loadout(data.loadout, meta):
		return null
	# The special slot: empty or a learned special move (a save from before
	# it has none).
	var special: Variant = data.get("special", "")
	if not special is String or (not special.is_empty() and not meta.owns_special(StringName(special))):
		return null
	meta.special = StringName(special)
	if not data.has("chapters"):
		var first := Chapters.ALL[0].id
		if meta.clears > 0:
			meta.chapter_clears[first] = meta.clears
		if meta.best_layer > 0:
			meta.chapter_best[first] = meta.best_layer
	elif not _read_chapters(data.chapters, meta):
		return null
	return meta


# The chapters' records: known chapter ids, each with counts in range.
static func _read_chapters(data: Variant, meta: MetaProgress) -> bool:
	if not data is Dictionary:
		return false
	for id: Variant in data:
		var entry: Variant = data[id]
		if not id is String or Chapters.find(StringName(id)) == null or not entry is Dictionary:
			return false
		if not integer(entry.get("clears", 0), 0, MAX_COUNT) or not integer(entry.get("best", 0), 0, MAX_COUNT):
			return false
		if int(entry.get("clears", 0)) > 0:
			meta.chapter_clears[StringName(id)] = int(entry.clears)
		if int(entry.get("best", 0)) > 0:
			meta.chapter_best[StringName(id)] = int(entry.best)
	return true


# The skill slots: as many ids as slots, each a held skill or empty, none
# twice. A save from before the slots keeps the new player's.
static func _read_loadout(data: Variant, meta: MetaProgress) -> bool:
	if not data is Array or data.size() != MetaProgress.SKILL_SLOTS:
		return false
	var loadout: Array[StringName] = []
	for id: Variant in data:
		if not id is String or (not id.is_empty() and (not meta.owns_skill(StringName(id)) or loadout.has(StringName(id)))):
			return false
		loadout.append(StringName(id))
	meta.loadout = loadout
	return true


# An old save (versions 1 to 4) made into lasting progress; null when it
# does not hold together enough to price.
static func migrate(data: Variant) -> MetaProgress:
	var version := version_of(data)
	if version < 1 or version >= VERSION:
		return null
	if not integer(data.get("gold"), 0, 1000000000) or not integer(data.get("hp_upgrade_level", 0), 0, OLD_HP_COSTS.size()):
		return null
	var spent := 0
	for index in int(data.get("hp_upgrade_level", 0)):
		spent += OLD_HP_COSTS[index]
	var skills: Variant = data.get("skills", {})
	if not skills is Dictionary:
		return null
	for id: Variant in skills:
		if not id is String or not OLD_SKILLS.has(id) or not integer(skills[id], 0, OLD_RANK_CAP):
			return null
		var price: Array = OLD_SKILLS[id]
		for rank in int(skills[id]):
			spent += int(price[0]) + rank * int(price[1])
	var meta := MetaProgress.new()
	meta.echo = mini(MetaProgress.MAX_ECHO, floori((int(data.gold) + spent) * ECHO_PER_GOLD))
	_read_met(data.get("met", []), meta, OLD_MET)
	return meta


# Foes met: ids as they are, or with `renames` (an old save's pictures),
# only those it names.
static func _read_met(data: Variant, meta: MetaProgress, renames: Dictionary) -> bool:
	if not data is Array or data.size() > MAX_MET:
		return false
	for id: Variant in data:
		if not id is String:
			return false
		if renames.is_empty():
			meta.met[StringName(id)] = true
		elif renames.has(id):
			meta.met[StringName(renames[id])] = true
	return true
