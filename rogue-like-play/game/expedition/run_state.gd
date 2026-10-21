class_name RunState
extends RefCounted

# One run of the real-time game, from setting out to its end: the level and
# experience (RunProgression, on the real-time curve), the build of boons,
# and the run's own random numbers. Nothing in it outlives the run; the next
# run starts from a new RunState.

const LEVELS := preload("res://data/progression/action_levels.tres")
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


func choose(id: StringName) -> bool:
	if progression.pending_choices <= 0 or not build.take(build.find(id)):
		return false
	progression.pending_choices -= 1
	return true
