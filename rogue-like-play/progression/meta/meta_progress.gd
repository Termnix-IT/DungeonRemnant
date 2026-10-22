class_name MetaProgress
extends RefCounted

# What lasts between real-time runs: the echo held (the base's currency,
# earned in runs), the ranks of the lasting upgrades (MetaUpgrade, a tree
# grown from ROOT: one can be bought once the upgrade it grows from holds a
# rank), the skills set in the two skill slots (loadout, chosen on the
# status page), the record of runs, and the foes ever met (for the
# encyclopedia). A run is shaped by it at its start (tuning, lasting,
# equipped_skills, starts_with_boon) and hands its result back at its end
# (record_run). Saved by MetaStore.

const ROOT := &"echo_lantern"
const UPGRADES: Array[MetaUpgrade] = [
	preload("res://data/meta/echo_lantern.tres"),
	preload("res://data/meta/sturdy_body.tres"),
	preload("res://data/meta/firm_guard.tres"),
	preload("res://data/meta/steady_recovery.tres"),
	preload("res://data/meta/last_stand.tres"),
	preload("res://data/meta/healing_lore.tres"),
	preload("res://data/meta/double_dash.tres"),
	preload("res://data/meta/dash_recovery.tres"),
	preload("res://data/meta/triple_dash.tres"),
	preload("res://data/meta/light_step.tres"),
	preload("res://data/meta/gem_magnet.tres"),
	preload("res://data/meta/parting_blessing.tres"),
	preload("res://data/meta/quick_study.tres"),
	preload("res://data/meta/reroll.tres"),
	preload("res://data/meta/fourth_card.tres"),
	preload("res://data/meta/rising_heal.tres"),
	preload("res://data/meta/rising_burst.tres"),
	preload("res://data/meta/rising_ward.tres"),
	preload("res://data/meta/rising_haste.tres"),
]
const MAX_ECHO := 1000000000
# Every active skill, in the status page's order.
const SKILLS: Array[SkillData] = [
	preload("res://data/skills/slam.tres"),
]
const SKILL_SLOTS := 2
# A new player's slots.
const DEFAULT_LOADOUT: Array[StringName] = [&"slam", &""]
# Effects a run reads as rules (RunState.lasting) rather than as her tuning.
const RUN_EFFECTS: Array[StringName] = [&"echo_rate", &"last_stand", &"heal_share", &"gem_pull", &"exp_rate",
	&"reroll", &"offer_count", &"level_heal", &"level_burst", &"level_ward", &"level_haste"]
# The dash never comes back quicker than this, whatever is held.
const MIN_DASH_COOLDOWN := 0.1

var echo := 0
# Upgrade id -> rank.
var ranks: Dictionary = {}
var runs := 0
var clears := 0
# The deepest layer reached, 1-based (the boss's layer once cleared).
var best_layer := 0
# Foe ids (FoeData.id) ever met -> true.
var met: Dictionary = {}
# The skill id in each skill slot (empty: nothing set).
var loadout: Array[StringName] = DEFAULT_LOADOUT.duplicate()


static func find(id: StringName) -> MetaUpgrade:
	for upgrade in UPGRADES:
		if upgrade.id == id:
			return upgrade
	return null


func rank(id: StringName) -> int:
	return int(ranks.get(String(id), 0))


# Whether the upgrade it grows from holds a rank (the root always may).
func unlocked(id: StringName) -> bool:
	var upgrade := find(id)
	return upgrade != null and (upgrade.parent.is_empty() or rank(upgrade.parent) > 0)


func can_buy(id: StringName) -> bool:
	var upgrade := find(id)
	if upgrade == null or not unlocked(id):
		return false
	var cost := upgrade.price(rank(id))
	return cost >= 0 and echo >= cost


func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	echo -= find(id).price(rank(id))
	ranks[String(id)] = rank(id) + 1
	return true


# What the upgrades held add to an effect.
func bonus(effect: StringName) -> float:
	var total := 0.0
	for upgrade in UPGRADES:
		if upgrade.effect == effect:
			total += upgrade.per_rank * rank(upgrade.id)
	return total


# The hero's tuning for a run: a copy of `base` with the upgrades applied.
func tuning(base: HeroTuning) -> HeroTuning:
	var shaped: HeroTuning = base.duplicate()
	shaped.max_hp += roundi(bonus(&"max_hp"))
	shaped.defense += roundi(bonus(&"defense"))
	shaped.hurt_mercy += bonus(&"hurt_mercy")
	shaped.dash_charges += roundi(bonus(&"dash_charges"))
	shaped.dash_cooldown = maxf(MIN_DASH_COOLDOWN, shaped.dash_cooldown + bonus(&"dash_cooldown"))
	shaped.max_speed *= 1.0 + bonus(&"move_speed")
	return shaped


# The rules a run reads from the upgrades held (RUN_EFFECTS -> bonus).
func lasting() -> Dictionary:
	var rules := {}
	for effect in RUN_EFFECTS:
		rules[effect] = bonus(effect)
	return rules


func starts_with_boon() -> bool:
	return bonus(&"start_boon") > 0.0


# A run's end, handed back: the echo it earned (kept whether it was won or
# not), the record, and the foes it met.
func record_run(result: Dictionary) -> void:
	echo = mini(MAX_ECHO, echo + int(result.get("echo", 0)))
	runs += 1
	if result.get("cleared", false):
		clears += 1
	best_layer = maxi(best_layer, int(result.get("layer", 0)) + 1)
	for id: Variant in result.get("met", []):
		met[StringName(id)] = true


func has_met(id: StringName) -> bool:
	return met.has(id)


static func find_skill(id: StringName) -> SkillData:
	for skill in SKILLS:
		if skill.id == id:
			return skill
	return null


# Whether the player holds the skill (later skills are learned on the tree).
func owns_skill(id: StringName) -> bool:
	var skill := find_skill(id)
	return skill != null and skill.owned_from_start


# The slot a skill is set in, or -1.
func slot_of(id: StringName) -> int:
	return loadout.find(id) if not id.is_empty() else -1


# Sets a held skill in a slot, or clears it with an empty id. A skill set in
# the other slot changes places with what this slot held.
func equip(slot: int, id: StringName) -> bool:
	if slot < 0 or slot >= SKILL_SLOTS or (not id.is_empty() and not owns_skill(id)):
		return false
	var other := slot_of(id)
	if other >= 0 and other != slot:
		loadout[other] = loadout[slot]
	loadout[slot] = id
	return true


# The skills a run fights with, slot by slot (null for an empty slot).
func equipped_skills() -> Array:
	var skills := []
	for id in loadout:
		skills.append(find_skill(id))
	return skills
