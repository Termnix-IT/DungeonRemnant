class_name RunState
extends RefCounted

# One run of the real-time game, from setting out to its end: the level and
# experience (RunProgression, on the real-time curve), the build of boons,
# the hero's health between areas, the route through the chapter and how
# far along it she is, the echo earned (the base's currency), the foes
# felled and the time fought, the run's own random numbers, and the rules the
# lasting upgrades give it (lasting: MetaProgress.RUN_EFFECTS, with the
# rerolls and the last stand they grant still unspent). Nothing in it
# outlives the run but what its end hands back; the next run starts from a
# new RunState.

const LEVELS := preload("res://data/progression/action_levels.tres")
# The curses a cursed stone lays on her: [name, what it does]. Each one taken
# also raises the run's echo rewards by CURSE_ECHO of themselves.
const CURSES := {
	&"frailty": ["脆さ", "受けるダメージが2増える"],
	&"sluggish": ["鈍足", "移動速度が12%落ちる"],
	&"thirst": ["渇き", "回復の報酬が半分になる"],
}
const CURSE_ECHO := 0.5
const FRAILTY := 2
const SLUGGISH := 0.88
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
	preload("res://data/boons/brute_force.tres"),
	preload("res://data/boons/follow_up.tres"),
	preload("res://data/boons/long_reach.tres"),
	preload("res://data/boons/rending_charge.tres"),
	preload("res://data/boons/life_feast.tres"),
	preload("res://data/boons/riposte.tres"),
	preload("res://data/boons/keen_art.tres"),
	preload("res://data/boons/gale_step.tres"),
	preload("res://data/boons/discharge.tres"),
	preload("res://data/boons/thunder_step.tres"),
	preload("res://data/boons/aftershock.tres"),
	preload("res://data/boons/flame_art.tres"),
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
# The lasting upgrades' rules (effect -> MetaProgress.bonus); none: a new player.
var lasting: Dictionary = {}
# The skills in her slots (SkillData or null each); empty: the moveset's skill.
var skills: Array = []
var rerolls_left := 0
var last_stands := 0
# The special move set for the run (null: none), and its gauge, carried from
# area to area.
var special: SpecialData
var special_charge := 0.0
# Curses taken at a cursed stone (CURSES' ids), kept to the run's end.
var curses: Array[StringName] = []
# Experience owed from exp_rate below a whole point, kept for the next gem.
var _exp_carry := 0.0


func _init(seed_value: int = 0) -> void:
	progression.settings = LEVELS
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# Takes the base's lasting rules (MetaProgress.lasting) at the run's start.
func use_lasting(rules: Dictionary) -> void:
	lasting = rules.duplicate()
	rerolls_left = roundi(rule(&"reroll"))
	last_stands = roundi(rule(&"last_stand"))
	# The drill's shorter rest adds to the build's, as a boon's would.
	build.base_stats[&"skill_cooldown"] = rule(&"skill_cooldown")


func rule(effect: StringName) -> float:
	return float(lasting.get(effect, 0.0))


# Experience gained; true when it brought a level-up whose choice waits.
func gain(amount: int) -> bool:
	var before := progression.pending_choices
	var owed := amount * (1.0 + rule(&"exp_rate")) + _exp_carry
	# A hair over, so 1.2 + 0.8 adds up to 2 and not to 1.9999.
	var whole := floori(owed + 0.000001)
	_exp_carry = maxf(0.0, owed - whole)
	progression.gain_exp(whole)
	return progression.pending_choices > before


# How many cards a level-up offers.
func offer_count() -> int:
	return BuildState.OFFER_COUNT + roundi(rule(&"offer_count"))


# The next level-up's offer; empty when every boon is at its last rank, and
# then the waiting choices are dropped.
func next_offer() -> Array[BoonData]:
	var offer := build.offer(rng, offer_count())
	if offer.is_empty():
		progression.pending_choices = 0
	return offer


# A fresh draw for the level-up on offer, spending a reroll; empty when none
# is left.
func reroll() -> Array[BoonData]:
	if rerolls_left <= 0:
		return []
	rerolls_left -= 1
	return build.offer(rng, offer_count())


# An area's echo reward, with the echo_rate held and each curse's share.
func echo_reward(amount: int) -> int:
	return roundi(amount * (1.0 + rule(&"echo_rate") + CURSE_ECHO * curses.size()))


# Lays a curse on her, if she does not carry it yet: its harm reaches her
# tuning at once (the areas ahead spawn her with it).
func take_curse(id: StringName) -> bool:
	if not CURSES.has(id) or curses.has(id):
		return false
	curses.append(id)
	match id:
		&"frailty":
			tuning.defense -= FRAILTY
		&"sluggish":
			tuning.max_speed *= SLUGGISH
	return true


# The curses she does not carry yet.
func curses_left() -> Array[StringName]:
	var left: Array[StringName] = []
	for id: StringName in CURSES:
		if not curses.has(id):
			left.append(id)
	return left


func curse_names() -> String:
	return "・".join(curses.map(func(id: StringName) -> String: return CURSES[id][0]))


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
