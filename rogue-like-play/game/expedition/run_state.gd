class_name RunState
extends RefCounted

# One run of the real-time game, from setting out to its end: the level and
# experience (RunProgression, on the real-time curve), the build of boons,
# the hero's health between areas, the route through the chapter and how
# far along it she is, the echo earned (the base's currency), the foes
# felled and the time fought, and the run's own random numbers. Nothing in
# it outlives the run but what its end hands back; the next run starts from
# a new RunState.

const LEVELS := preload("res://data/progression/action_levels.tres")
const HERO := preload("res://data/hero/mio.tres")
const BOONS: Array[BoonData] = [
	preload("res://data/boons/thunder_blade.tres"),
	preload("res://data/boons/chain_lightning.tres"),
	preload("res://data/boons/whirlwind.tres"),
	preload("res://data/boons/afterimage.tres"),
	preload("res://data/boons/shockwave.tres"),
	preload("res://data/boons/great_charge.tres"),
	preload("res://data/boons/hellfire.tres"),
	preload("res://data/boons/blade_speed.tres"),
]

var progression := RunProgression.new()
var build := BuildState.new(BOONS)
var rng := RandomNumberGenerator.new()
# Her tuning for the run (the lasting upgrades applied); never the data itself.
var tuning: HeroTuning = HERO.duplicate()
# Foes met in the run, by FoeData.id.
var met: Dictionary = {}
# Her health carried from area to area; 0 or less: full.
var hp := 0
var route: RouteMap
var layer := 0
# The waypoints entered so far, one per layer.
var taken: Array = []
var echo := 0
var kills := 0
var time := 0.0
var areas_cleared := 0


func _init(seed_value: int = 0) -> void:
	progression.settings = LEVELS
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# Experience gained; true when it brought a level-up whose choice waits.
func gain(amount: int) -> bool:
	var before := progression.pending_choices
	progression.gain_exp(amount)
	return progression.pending_choices > before


# The next level-up's offer; empty when every boon is at its last rank, and
# then the waiting choices are dropped.
func next_offer() -> Array[BoonData]:
	var offer := build.offer(rng)
	if offer.is_empty():
		progression.pending_choices = 0
	return offer


# Heals a share of `max_hp`, up to it.
func heal(share: float, max_hp: int) -> int:
	var before := hp if hp > 0 else max_hp
	hp = mini(max_hp, before + roundi(max_hp * share))
	return hp - before


func choose(id: StringName) -> bool:
	if progression.pending_choices <= 0 or not build.take(build.find(id)):
		return false
	progression.pending_choices -= 1
	return true
