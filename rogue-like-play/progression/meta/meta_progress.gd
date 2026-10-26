class_name MetaProgress
extends RefCounted

# What lasts between real-time runs: the echo held (the base's currency,
# earned in runs), the ranks of the lasting upgrades (MetaUpgrade, a tree
# grown from ROOT: one can be bought once the upgrade it grows from holds a
# rank), the skills set in the two skill slots (loadout, chosen on the
# status page), the special move in its slot (special) and the weapon in the
# attack slot (weapon), the record
# (in all and chapter by chapter, which opens the later chapters, and with
# each chapter's highest difficulty step cleared, which opens the steps) of
# runs, and the foes ever met (for the
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
	preload("res://data/meta/learn_thunder_flash.tres"),
	preload("res://data/meta/learn_swallow_cut.tres"),
	preload("res://data/meta/learn_blaze_ring.tres"),
	preload("res://data/meta/learn_wisp_shot.tres"),
	preload("res://data/meta/learn_thunder_circle.tres"),
	preload("res://data/meta/skill_drill.tres"),
	preload("res://data/meta/learn_echo_burst.tres"),
	preload("res://data/meta/learn_sky_rend.tres"),
	preload("res://data/meta/learn_crimson_lotus.tres"),
	preload("res://data/meta/special_surge.tres"),
	preload("res://data/meta/special_mastery.tres"),
	preload("res://data/meta/learn_spear.tres"),
	preload("res://data/meta/learn_hammer.tres"),
]
const MAX_ECHO := 1000000000
# Every active skill, in the status page's order.
const SKILLS: Array[SkillData] = [
	preload("res://data/skills/slam.tres"),
	preload("res://data/skills/thunder_flash.tres"),
	preload("res://data/skills/swallow_cut.tres"),
	preload("res://data/skills/blaze_ring.tres"),
	preload("res://data/skills/wisp_shot.tres"),
	preload("res://data/skills/thunder_circle.tres"),
]
const SKILL_SLOTS := 2
# Every special move, in the status page's order; equip() takes the special
# slot as the slot after the skills'.
const SPECIALS: Array[SpecialData] = [
	preload("res://data/specials/echo_burst.tres"),
	preload("res://data/specials/sky_rend.tres"),
	preload("res://data/specials/crimson_lotus.tres"),
]
const SPECIAL_SLOT := SKILL_SLOTS
# Every weapon, in the status page's order; the attack slot is the slot
# after the special move's for equip().
const WEAPONS: Array[Moveset] = [
	preload("res://data/movesets/sword.tres"),
	preload("res://data/movesets/spear.tres"),
	preload("res://data/movesets/hammer.tres"),
]
const WEAPON_SLOT := SPECIAL_SLOT + 1
# A new player's slots.
const DEFAULT_LOADOUT: Array[StringName] = [&"slam", &""]
# Effects a run reads as rules (RunState.lasting) rather than as her tuning.
const RUN_EFFECTS: Array[StringName] = [&"echo_rate", &"last_stand", &"heal_share", &"gem_pull", &"exp_rate",
	&"reroll", &"offer_count", &"level_heal", &"level_burst", &"level_ward", &"level_haste", &"skill_cooldown",
	&"special_charge", &"special_power"]
# The dash never comes back quicker than this, whatever is held.
const MIN_DASH_COOLDOWN := 0.1

var echo := 0
# Upgrade id -> rank.
var ranks: Dictionary = {}
var runs := 0
var clears := 0
# The deepest layer reached, 1-based (the boss's layer once cleared), in
# any chapter.
var best_layer := 0
# Chapter id -> its clears, and the deepest layer reached in it (1-based).
var chapter_clears: Dictionary = {}
var chapter_best: Dictionary = {}
# Chapter id -> the highest difficulty step it has been cleared at (none: 0).
var chapter_steps: Dictionary = {}
# Foe ids (FoeData.id) ever met -> true.
var met: Dictionary = {}
# The skill id in each skill slot (empty: nothing set).
var loadout: Array[StringName] = DEFAULT_LOADOUT.duplicate()
# The special move in its slot (empty: none).
var special: StringName = &""
# The weapon in the attack slot.
var weapon: StringName = &"sword"


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
	var upgrade := find(id)
	echo -= upgrade.price(rank(id))
	ranks[String(id)] = rank(id) + 1
	# The first special move learned goes straight into its empty slot.
	if upgrade.effect == &"special_unlock" and special.is_empty():
		special = upgrade.grants
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
	var chapter := StringName(str(result.get("chapter_id", Chapters.ALL[0].id)))
	if result.get("cleared", false):
		chapter_clears[chapter] = clears_of(chapter) + 1
		var step := clampi(int(result.get("step", 0)), 0, DifficultySteps.MAX)
		if step > step_of(chapter):
			chapter_steps[chapter] = step
	chapter_best[chapter] = maxi(best_of(chapter), int(result.get("layer", 0)) + 1)
	for id: Variant in result.get("met", []):
		met[StringName(id)] = true


func clears_of(chapter: StringName) -> int:
	return int(chapter_clears.get(chapter, 0))


func best_of(chapter: StringName) -> int:
	return int(chapter_best.get(chapter, 0))


# The highest difficulty step the chapter has been cleared at (0: none, or
# only at the game as it is).
func step_of(chapter: StringName) -> int:
	return int(chapter_steps.get(chapter, 0))


# Whether the last chapter has been cleared: the ending has been seen. Kept
# by the chapter's own record, so a later chapter added moves it along.
func ending_seen() -> bool:
	return clears_of(Chapters.ALL.back().id) > 0


# The highest difficulty step open: none before the ending; then one past
# the highest step the last chapter has been cleared at, up to the last.
func steps_open() -> int:
	if not ending_seen():
		return 0
	return mini(DifficultySteps.MAX, step_of(Chapters.ALL.back().id) + 1)


# Whether the chapter can be set out for: open from the start, or the one it
# is unlocked_by has been cleared.
func chapter_open(chapter: ChapterData) -> bool:
	return chapter.unlocked_by.is_empty() or clears_of(chapter.unlocked_by) > 0


func has_met(id: StringName) -> bool:
	return met.has(id)


static func find_skill(id: StringName) -> SkillData:
	for skill in SKILLS:
		if skill.id == id:
			return skill
	return null


# Whether the player holds the skill: from the start, or learned on the
# upgrade tree's skill branch (a skill_unlock holding a rank).
func owns_skill(id: StringName) -> bool:
	var skill := find_skill(id)
	if skill == null:
		return false
	if skill.owned_from_start:
		return true
	for upgrade in UPGRADES:
		if upgrade.effect == &"skill_unlock" and upgrade.grants == id and rank(upgrade.id) > 0:
			return true
	return false


static func find_special(id: StringName) -> SpecialData:
	for move in SPECIALS:
		if move.id == id:
			return move
	return null


# Whether the player has learned the special move (a special_unlock holding
# a rank).
func owns_special(id: StringName) -> bool:
	if find_special(id) == null:
		return false
	for upgrade in UPGRADES:
		if upgrade.effect == &"special_unlock" and upgrade.grants == id and rank(upgrade.id) > 0:
			return true
	return false


func owns_any_special() -> bool:
	return SPECIALS.any(func(move: SpecialData): return owns_special(move.id))


# The special move a run fights with, or null.
func equipped_special() -> SpecialData:
	return find_special(special) if owns_special(special) else null


static func find_weapon(id: StringName) -> Moveset:
	for held in WEAPONS:
		if held.id == id:
			return held
	return null


# Whether the player holds the weapon: from the start, or learned on the
# upgrade tree's weapon branch (a weapon_unlock holding a rank).
func owns_weapon(id: StringName) -> bool:
	var held := find_weapon(id)
	if held == null:
		return false
	if held.owned_from_start:
		return true
	for upgrade in UPGRADES:
		if upgrade.effect == &"weapon_unlock" and upgrade.grants == id and rank(upgrade.id) > 0:
			return true
	return false


# The weapon a run fights with (the sword when the one set is not held).
func equipped_weapon() -> Moveset:
	return find_weapon(weapon) if owns_weapon(weapon) else WEAPONS[0]


# The slot a skill is set in, or -1.
func slot_of(id: StringName) -> int:
	return loadout.find(id) if not id.is_empty() else -1


# Sets a held skill in a slot, or clears it with an empty id. A skill set in
# the other slot changes places with what this slot held.
func equip(slot: int, id: StringName) -> bool:
	if slot == WEAPON_SLOT:
		if not owns_weapon(id):
			return false
		weapon = id
		return true
	if slot == SPECIAL_SLOT:
		if not id.is_empty() and not owns_special(id):
			return false
		special = id
		return true
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
