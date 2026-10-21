class_name MetaProgress
extends RefCounted

# What lasts between real-time runs: the echo held (the base's currency,
# earned in runs), the ranks of the lasting upgrades (MetaUpgrade), the
# record of runs, and the foes ever met (for the encyclopedia). A run is
# shaped by it at its start (tuning, starts_with_boon) and hands its result
# back at its end (record_run). Saved by MetaStore.

const UPGRADES: Array[MetaUpgrade] = [
	preload("res://data/meta/sturdy_body.tres"),
	preload("res://data/meta/double_dash.tres"),
	preload("res://data/meta/parting_blessing.tres"),
]
const MAX_ECHO := 1000000000

var echo := 0
# Upgrade id -> rank.
var ranks: Dictionary = {}
var runs := 0
var clears := 0
# The deepest layer reached, 1-based (the boss's layer once cleared).
var best_layer := 0
# Foe ids (FoeData.id) ever met -> true.
var met: Dictionary = {}


static func find(id: StringName) -> MetaUpgrade:
	for upgrade in UPGRADES:
		if upgrade.id == id:
			return upgrade
	return null


func rank(id: StringName) -> int:
	return int(ranks.get(String(id), 0))


func can_buy(id: StringName) -> bool:
	var upgrade := find(id)
	if upgrade == null:
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
	shaped.dash_charges += roundi(bonus(&"dash_charges"))
	return shaped


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
