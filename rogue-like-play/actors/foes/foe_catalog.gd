class_name FoeCatalog
extends RefCounted

# Every foe the encyclopedia lists, in its order: the crowd, the elites, the
# bosses. A foe counts as met once it has come into an area during a run
# (MetaProgress.met, keyed by FoeData.id).

const FOES: Array[FoeData] = [
	preload("res://data/foes/wandering_sentinel.tres"),
	preload("res://data/foes/dashing_rat.tres"),
	preload("res://data/foes/raging_charger.tres"),
	preload("res://data/foes/ruin_king.tres"),
]
const KINDS: Array[String] = ["すべて", "群れ", "精鋭", "ボス"]


# 1 the crowd, 2 an elite, 3 a boss (KINDS' indices).
static func kind_of(foe: FoeData) -> int:
	if foe.boss:
		return 3
	return 2 if foe.elite else 1


static func kind_name(foe: FoeData) -> String:
	return KINDS[kind_of(foe)]
